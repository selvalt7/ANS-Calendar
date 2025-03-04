//
//  Messages.swift
//  ANS Calendar
//
//  Created by Stanisław on 28/02/2025.
//

import Foundation
import SwiftSoup

let MessagesUrl = "stud.wiadomosci.WiadomosciView"

struct UnreadMessagesResposne: Codable {
    let returnedValue: Int?
}

struct MessageData: Codable {
    let typWiersza: String
    let idWatku: Int
    let idSkrzynkiUczestnika: Int
    let idWszystkichWiadomosci: [Int]
}

struct Message: Codable, Identifiable {
    var id = UUID()
    
    let Sender: String
    let Title: String
    let PreviewContent: String
    var Unread: Bool
    let MessageData: MessageData
}

struct MessageContent: Codable, Identifiable {
    var id = UUID()
    
    var Content: [String] = []
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
    
    var Placeholder: [Message] = [
        Message(Sender: "Joe Doe", Title: "Important notice", PreviewContent: "Lorem ipsum https://lorem.pl", Unread: false, MessageData: MessageData(typWiersza: "", idWatku: 0, idSkrzynkiUczestnika: 0, idWszystkichWiadomosci: [0])),
        Message(Sender: "Jan Kowalski", Title: "Another important notice", PreviewContent: "Lorem ipsum", Unread: false, MessageData: MessageData(typWiersza: "", idWatku: 0, idSkrzynkiUczestnika: 0, idWszystkichWiadomosci: [0]))
    ]
    
    func getUnreadMessages(VerbisANSApi: VerbisAPI) -> Int {
        let request = VerbisANSApi.InitAJAXRequest(Service: "Wiadomosc", Method: "getLiczbaNowychWiadomosci")
        
        let session = URLSession.shared
        Task {
            let (data, _) = try await session.data(for: request)
            
            let parsedJSON: UnreadMessagesResposne = try! JSONDecoder().decode(UnreadMessagesResposne.self, from: data)
            UnreadMessages = parsedJSON.returnedValue ?? 0
        }
        return UnreadMessages
    }
    
    func FetchMessages(VerbisAnsAPI: VerbisAPI) async {
        do {
            Messages.removeAll()
            
            let request = VerbisAnsAPI.InitRequest(EndUrl: MessagesUrl)
            
            let session = URLSession.shared
            
            let (data, _) = try await session.data(for: request)
            
            let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            let doc: Document = try SwiftSoup.parse(html)
            
            let messageHeaders: Elements = try doc.select(".wiadomosc-tr-header")
            
            for messageHeader: Element in messageHeaders.array() {
                let Sender = try messageHeader.select(".wiadomosc-nadawca").array()[0].text()
                let Title = try messageHeader.select(".wiadomosc-zawartosc-glowna").array()[0].text()
                let Content = try messageHeader.select(".wiadomosc-zawartosc-szczegoly").array()[0].text()
                let Unread = messageHeader.hasClass("wiadomosci-nowe")
                
                let RowData = (try messageHeader.attr("data-vdo-dane-wiersza").data(using: .utf8))!
                let MessageData = try! JSONDecoder().decode(MessageData.self, from: RowData)
                
                let Message = Message(Sender: Sender, Title: Title, PreviewContent: Content, Unread: Unread, MessageData: MessageData)
                
                Messages.append(Message)
            }
        } catch {
            
        }
    }
    
    func FetchMessage(VerbisAnsAPI: VerbisAPI, MessageData: MessageData) async -> [MessageContent] {
        do {
            let MessagePayload = "idwatku=\(MessageData.idWatku)&idskrzynkiuczestnika=\(MessageData.idSkrzynkiUczestnika)"
            let request = VerbisAnsAPI.InitRequest(EndUrl: MessagesUrl, UrlData: MessagePayload)
            
            let session = URLSession.shared
            
            let (data, _) = try await session.data(for: request)
            
            let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            let doc: Document = try SwiftSoup.parse(html)
            
            let MessagesRowContent: Elements = try doc.select(".wiadomosc-tr-content")
            
            var MessageThread: [MessageContent] = []
            
            for MessageData: Element in MessagesRowContent.array() {
                var MessageContentData = MessageContent()
                
                let MessageTextContent = try MessageData.select(".wiadomosc-content")[0]
                
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
                
                let AttachmentsElements: Elements = try MessageData.select(".pliki-content")
                if AttachmentsElements.array().count > 0 {
                    if let MessageFiles = AttachmentsElements[0] as? Element {
                        for MessageFile: Element in try MessageFiles.select("div").array() {
                            if !MessageFile.hasClass("pliki-content") {
                                var MessageAttachment = Attachment()
                                let link = try MessageFile.select("a")[0]
                                
                                MessageAttachment.Size = MessageFile.ownText()
                                MessageAttachment.AttachmentName = try link.text()
                                MessageAttachment.Link = try link.attr("href")
                                
                                MessageContentData.Attachments.append(MessageAttachment)
                            }
                        }
                    }
                }
                
                MessageThread.append(MessageContentData)
            }
            
            return MessageThread
        } catch {
            return []
        }
    }
}
