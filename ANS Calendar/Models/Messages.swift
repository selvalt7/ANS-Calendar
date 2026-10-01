//
//  Messages.swift
//  ANS Calendar
//
//  Created by Stanisław on 28/02/2025.
//

import Foundation
import SwiftSoup

let MessagesUrl = "stud.wiadomosci.WiadomosciZakladkaView"
let MailboxIDURL = "stud.wiadomosci.WiadomosciTabContainerView"

struct UnreadMessagesResposne: Codable {
    let returnedValue: Int?
}

struct MessageData: Codable {
    let typWiersza: String
    let idWatku: Int
    let idSkrzynkiUczestnika: Int
    let idWszystkichWiadomosci: [Int]
}

struct Message: Codable, Identifiable, Equatable {
    var id = UUID()
    
    let Sender: String
    let Title: String
    let PreviewContent: String
    var Unread: Bool
    let MessageData: MessageData
    var Date: Date
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MessageContent: Codable, Identifiable {
    var id = UUID()
    
    var Content: [String] = []
    var Sender: String = ""
    var Attachments: [Attachment] = []
}

struct Attachment: Codable, Identifiable {
    var id = UUID()
    
    var Link: String = ""
    var AttachmentName: String = ""
    var Size: String = ""
}

@MainActor
class MessagesModel: ObservableObject {
    @Published var UnreadMessages: Int = 0
    @Published var Messages: [Message] = []
    @Published var IsBusy: Bool = false
    private var MailboxID: Int = 0
    
    var Placeholder: [Message] = [
        Message(Sender: "Joe Doe", Title: "Important notice", PreviewContent: "Lorem ipsum", Unread: false, MessageData: MessageData(typWiersza: "", idWatku: 0, idSkrzynkiUczestnika: 0, idWszystkichWiadomosci: [0]), Date: Date()),
        Message(Sender: "Jan Kowalski", Title: "Another important notice", PreviewContent: "Lorem ipsum", Unread: false, MessageData: MessageData(typWiersza: "", idWatku: 0, idSkrzynkiUczestnika: 0, idWszystkichWiadomosci: [0]), Date: Date())
    ]
    
    func getUnreadMessages(VerbisANSApi: VerbisAPI) async {
        do {
            let request = VerbisANSApi.InitAJAXRequest(Service: "Wiadomosc", Method: "getLiczbaNowychWiadomosci")
            let session = URLSession.shared
            
            // Wait for the network call to finish
            let (data, _) = try await session.data(for: request)
            
            // Safely decode
            let parsedJSON = try JSONDecoder().decode(UnreadMessagesResposne.self, from: data)
            
            // Update the @Published property directly
            self.UnreadMessages = parsedJSON.returnedValue ?? 0
        } catch {
            print("Failed to fetch unread messages: \(error.localizedDescription)")
        }
    }
    
    func FetchMessages(VerbisAnsAPI: VerbisAPI, Offset: Int = 0) async {
        do {
            IsBusy = true
            
            if (VerbisAnsAPI.MailboxID == 0) {
                await GetMailboxID(VerbisANSAPI: VerbisAnsAPI)
            } else {
                MailboxID = VerbisAnsAPI.MailboxID;
            }
            
            let request = VerbisAnsAPI.InitRequest(EndUrl: MessagesUrl, UrlData: "offset=\(Offset)&idskrzynki=\(MailboxID)")
            
            let session = URLSession.shared
            
            let (data, _) = try await session.data(for: request)
            
            let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            let doc: Document = try SwiftSoup.parse(html)
            
            let messageHeaders: Elements = try doc.select(".wiadomosc-tr-header")
            let MessagesContentHeader: Elements = try doc.select(".wiadomosc-tr-content-header")
            
            let DateFormatter = DateFormatter()
            DateFormatter.locale = Locale(identifier: "en_US_POSIX")
            DateFormatter.dateFormat = "dd.MM.yyyy HH:mm"
            let DateRegex = /\d+.\d.+.\d+ \d+:\d+/
            
            let contentHeaders = MessagesContentHeader.array()
            for (index, messageHeader) in messageHeaders.enumerated() {
                guard let Sender = try messageHeader.select(".wiadomosc-nadawca").array().first?.text(),
                      let Title = try messageHeader.select(".wiadomosc-zawartosc-glowna").array().first?.text(),
                      let Content = try messageHeader.select(".wiadomosc-zawartosc-szczegoly").array().first?.text()
                else { continue }
                let Unread = messageHeader.hasClass("wiadomosci-nowe")
                
                var MessageDate = Date()
                if index < contentHeaders.count {
                    let headerDivs = try contentHeaders[index].select("div").array()
                    if headerDivs.count > 1,
                       let Match = try headerDivs[1].text().firstMatch(of: DateRegex),
                       let parsedDate = DateFormatter.date(from: String(Match.0)) {
                        MessageDate = parsedDate
                    }
                }
                
                let rawRow = try messageHeader.attr("data-vdo-dane-wiersza")
                guard let RowData = rawRow.data(using: .utf8),
                      let MessageData = try? JSONDecoder().decode(MessageData.self, from: RowData)
                else { continue }
                
                let Message = Message(Sender: Sender, Title: Title, PreviewContent: Content, Unread: Unread, MessageData: MessageData, Date: MessageDate)
                
                if !Messages.contains(where: {$0.MessageData.idWatku == Message.MessageData.idWatku}) {
                    Messages.append(Message)
                }
            }
            IsBusy = false
        } catch {
            
        }
    }
    
    func GetMailboxID(VerbisANSAPI: VerbisAPI) async {
        do {
            let request = VerbisANSAPI.InitRequest(EndUrl: MailboxIDURL, UrlData: "")
            
            let session = URLSession.shared
            
            let (data, _) = try await session.data(for: request)
            
            let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            let doc: Document = try SwiftSoup.parse(html)
            
            let MailboxIDRegex = /(idskrzynki=)(\d+)/
            
            let scripts: Elements = try doc.select(".wiadomosci-view-tab")
            
            for script in scripts {
                if let match = try script.attr("href").firstMatch(of: MailboxIDRegex),
                   let mailbox = Int(match.2) {
                    MailboxID = mailbox
                    break
                }
            }
            print(MailboxID)
            VerbisANSAPI.MailboxID = MailboxID
            UserDefaults.standard.set(MailboxID, forKey: "MailboxID")
        } catch {
            
        }
    }
    
    func FetchMessage(VerbisAnsAPI: VerbisAPI, MessageData: MessageData) async -> [MessageContent] {
        do {
            IsBusy = true
            
            let MessagePayload = "idwatku=\(MessageData.idWatku)&idskrzynkiuczestnika=\(MessageData.idSkrzynkiUczestnika)&idskrzynki=\(MailboxID)"
            let request = VerbisAnsAPI.InitRequest(EndUrl: MessagesUrl, UrlData: MessagePayload)
            
            let session = URLSession.shared
            
            let (data, _) = try await session.data(for: request)
            
            let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            let doc: Document = try SwiftSoup.parse(html)
            
            let MessagesRowContent: Elements = try doc.select(".wiadomosc-tr-content")
            let MessagesHeader: Elements = try doc.select(".wiadomosc-tr-content-header")
            
            var MessageThread: [MessageContent] = []
            
            let messageHeaders = MessagesHeader.array()
            for (index, MessageData) in MessagesRowContent.enumerated() {
                var MessageContentData = MessageContent()
                
                guard index < messageHeaders.count else { continue }
                let headerDivs = try messageHeaders[index].select("div").array()
                guard let sender = try headerDivs.first?.text() else { continue }
                MessageContentData.Sender = sender
                
                guard let MessageTextContent = try MessageData.select(".wiadomosc-content").array().first else { continue }
                
                let nodes = MessageTextContent.getChildNodes()
                
                var paragraphs: [String] = []
                var currentParagraph = ""

                for node in nodes {
                    if let textNode = node as? TextNode {
                        // Append text content to the current paragraph
                        currentParagraph += textNode.text().trimmingCharacters(in: .whitespacesAndNewlines) + " "
                    } else if node.nodeName() == "p" {
                        // A <p/> tag acts as a paragraph break, so save the current paragraph
                        if !currentParagraph.isEmpty {
                            paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines))
                            currentParagraph = "" // Reset for the next paragraph
                        }
                    } else if let elementNode = node as? Element {
                        // Extract text from inline elements (like <a>)
                        if !elementNode.hasClass("fltrt") {
                            currentParagraph += try elementNode.text().trimmingCharacters(in: .whitespacesAndNewlines) + " "
                        }
                    }
                }

                // Add the last paragraph if there's any remaining text
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                
                MessageContentData.Content = paragraphs
                
                if let filesContainer = try MessageData.select(".pliki-content").array().first {
                    for MessageFile in try filesContainer.select("div").array() where !MessageFile.hasClass("pliki-content") {
                        guard let link = try MessageFile.select("a").array().first else { continue }
                        var MessageAttachment = Attachment()
                        MessageAttachment.Size = MessageFile.ownText()
                        MessageAttachment.AttachmentName = try link.text()
                        MessageAttachment.Link = try link.attr("href")
                        MessageContentData.Attachments.append(MessageAttachment)
                    }
                }
                
                MessageThread.append(MessageContentData)
            }
            IsBusy = false
            
            return MessageThread
        } catch {
            return []
        }
    }
    
    func NotifyRead(VerbisAPI: VerbisAPI, MessageData: MessageData) async {
        do {
            let Params = "\"idSkrzynki\":\"\(MailboxID)\",\"rodzajDzialania\":\"WYSWIETLENIE\",\"wykonane\":true,\"idWiadomosci\":\(MessageData.idWszystkichWiadomosci)"
            let request = VerbisAPI.InitAJAXRequest(Service: "Wiadomosc", Method: "modyfikujDzialanieNaWiadomosciach", Params: Params)
            let session = URLSession.shared
            
            let (_, _) = try await session.data(for: request)
            
            await getUnreadMessages(VerbisANSApi: VerbisAPI)
        } catch {
            
        }
    }
}
