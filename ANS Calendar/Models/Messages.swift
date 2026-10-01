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
    /// Portal send time. Nil when the list HTML has no parseable date (never invent "now").
    var Date: Date?
    /// False when only a calendar day was present (avoid showing a fake 00:00).
    var DateHasTime: Bool = false
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MessageContent: Codable, Identifiable {
    var id = UUID()
    
    var Content: [String] = []
    var Sender: String = ""
    var SentAt: Date? = nil
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
        Message(Sender: "Joe Doe", Title: "Important notice", PreviewContent: "Lorem ipsum", Unread: false, MessageData: MessageData(typWiersza: "", idWatku: 0, idSkrzynkiUczestnika: 0, idWszystkichWiadomosci: [0]), Date: Date(), DateHasTime: true),
        Message(Sender: "Jan Kowalski", Title: "Another important notice", PreviewContent: "Lorem ipsum", Unread: false, MessageData: MessageData(typWiersza: "", idWatku: 0, idSkrzynkiUczestnika: 0, idWszystkichWiadomosci: [0]), Date: Date(), DateHasTime: true)
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
            
            for message in try parseMessageList(html: html) {
                if !Messages.contains(where: {$0.MessageData.idWatku == message.MessageData.idWatku}) {
                    Messages.append(message)
                }
            }
            IsBusy = false
        } catch {
            IsBusy = false
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
                let header = messageHeaders[index]
                let headerDivs = try header.select("div").array()
                let senderElement = try header.select(".fltlft").array().first ?? headerDivs.first
                guard let senderElement, let sender = try? senderElement.text(), !sender.isEmpty else { continue }
                MessageContentData.Sender = sender
                MessageContentData.SentAt = try verbisMessageDate(in: header)
                
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
    
    func updateMessageDate(threadId: Int, date: Date, includesTime: Bool) {
        guard let index = Messages.firstIndex(where: { $0.MessageData.idWatku == threadId }) else { return }
        Messages[index].Date = date
        Messages[index].DateHasTime = includesTime
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

/// Parse the inbox table into messages with portal send dates.
func parseMessageList(html: String) throws -> [Message] {
    let doc: Document = try SwiftSoup.parse(html)
    let messageHeaders = try doc.select(".wiadomosc-tr-header").array()
    let datesByHeaderIndex = try contentHeaderDatesByMessageIndex(in: doc, messageHeaders: messageHeaders)
    var messages: [Message] = []

    for (index, messageHeader) in messageHeaders.enumerated() {
        guard let sender = try messageHeader.select(".wiadomosc-nadawca").array().first?.text(),
              let title = try messageHeader.select(".wiadomosc-zawartosc-glowna").array().first?.text(),
              let preview = try messageHeader.select(".wiadomosc-zawartosc-szczegoly").array().first?.text()
        else { continue }
        let unread = messageHeader.hasClass("wiadomosci-nowe")

        let rawRow = try messageHeader.attr("data-vdo-dane-wiersza")
        guard let rowData = rawRow.data(using: .utf8),
              let messageData = try? JSONDecoder().decode(MessageData.self, from: rowData)
        else { continue }

        let sentAt = try messageListDate(
            for: messageHeader,
            contentHeaderDate: datesByHeaderIndex[index],
            rowJSON: rowData
        )

        messages.append(
            Message(
                Sender: sender,
                Title: title,
                PreviewContent: preview,
                Unread: unread,
                MessageData: messageData,
                Date: sentAt?.date,
                DateHasTime: sentAt?.includesTime ?? false
            )
        )
    }
    return messages
}

/// Prefer content-header dates (timed when available), then list-row / JSON fallbacks.
func messageListDate(
    for messageHeader: Element,
    contentHeaderDate: VerbisMessageDate?,
    rowJSON: Data? = nil
) throws -> VerbisMessageDate? {
    var best = contentHeaderDate

    if let siblingHeader = try nextMessageContentHeader(after: messageHeader),
       let siblingDate = try verbisMessageDateValue(in: siblingHeader) {
        best = betterMessageDate(best, siblingDate)
    }

    if let rowJSON, let jsonDate = messageDate(fromRowJSON: rowJSON) {
        best = betterMessageDate(best, jsonDate)
    }

    if let listRowDate = try listRowMessageDate(in: messageHeader) {
        best = betterMessageDate(best, listRowDate)
    }

    return best
}

func betterMessageDate(_ current: VerbisMessageDate?, _ candidate: VerbisMessageDate) -> VerbisMessageDate {
    guard let current else { return candidate }
    if candidate.includesTime && !current.includesTime {
        return candidate
    }
    return current
}

/// Some Verbis row payloads include a send timestamp beside the ids we already decode.
func messageDate(fromRowJSON data: Data) -> VerbisMessageDate? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

    let preferredKeys = [
        "dataWyslania", "dataNadania", "dataWiadomosci",
        "czasWyslania", "timestamp", "dataUtworzenia"
    ]
    for key in preferredKeys {
        if let value = object[key], let parsed = messageDate(fromJSONValue: value) {
            return parsed
        }
    }
    for (key, value) in object {
        let lower = key.lowercased()
        // Avoid matching unrelated keys like typWiersza; require a clear date/time token.
        guard lower.hasPrefix("data") || lower.hasPrefix("czas") || lower.contains("timestamp") || lower.hasSuffix("date") || lower.hasSuffix("time") else {
            continue
        }
        if key == "data" { continue }
        if let parsed = messageDate(fromJSONValue: value) {
            return parsed
        }
    }
    return nil
}

private func messageDate(fromJSONValue value: Any) -> VerbisMessageDate? {
    if let text = value as? String {
        return parseVerbisMessageDateValue(text)
    }
    if let number = value as? NSNumber {
        let millis = number.doubleValue
        // Portal timestamps are usually epoch milliseconds.
        let interval = millis > 10_000_000_000 ? millis / 1000 : millis
        let date = Date(timeIntervalSince1970: interval)
        return VerbisMessageDate(date: date, includesTime: true)
    }
    return nil
}

/// Pair content-header dates with list rows. Accept date-only; prefer timed values.
func contentHeaderDatesByMessageIndex(in document: Document, messageHeaders: [Element]) throws -> [Int: VerbisMessageDate] {
    var dates: [Int: VerbisMessageDate] = [:]
    let contentHeaders = try document.select(".wiadomosc-tr-content-header").array()

    // Primary: document-order index pairing (stable when every row has a content header).
    for (index, contentHeader) in contentHeaders.enumerated() where index < messageHeaders.count {
        if let parsed = try verbisMessageDateValue(in: contentHeader) {
            dates[index] = betterMessageDate(dates[index], parsed)
        }
    }

    // Secondary: DOM proximity, including separate <tbody> wrappers.
    for contentHeader in contentHeaders {
        guard let parsed = try verbisMessageDateValue(in: contentHeader) else { continue }
        guard let messageHeader = try nearestPrecedingMessageHeader(before: contentHeader) else { continue }
        guard let index = messageHeaders.firstIndex(where: { $0 === messageHeader }) else { continue }
        dates[index] = betterMessageDate(dates[index], parsed)
    }

    return dates
}

private let messageBodySelectors = ".wiadomosc-nadawca, .wiadomosc-zawartosc-glowna, .wiadomosc-zawartosc-szczegoly"

/// Read dates from the list row while ignoring sender/title/preview text.
func listRowMessageDate(in messageHeader: Element) throws -> VerbisMessageDate? {
    var best: VerbisMessageDate?

    for floated in try messageHeader.select(".fltrt").array() {
        if let parsed = parseVerbisMessageDateValue(try floated.text()) {
            best = betterMessageDate(best, parsed)
        }
    }

    for cell in try messageHeader.select("td").array() {
        if let parsed = try dateValue(in: cell, strippingBodyText: true) {
            best = betterMessageDate(best, parsed)
        }
    }

    if let parsed = try dateValue(in: messageHeader, strippingBodyText: true) {
        best = betterMessageDate(best, parsed)
    }

    return best
}

private func dateValue(in element: Element, strippingBodyText: Bool) throws -> VerbisMessageDate? {
    if !strippingBodyText {
        return parseVerbisMessageDateValue(try element.text())
    }

    var text = try element.text()
    for node in try element.select(messageBodySelectors).array() {
        let bodyText = try node.text()
        guard !bodyText.isEmpty else { continue }
        text = text.replacingOccurrences(of: bodyText, with: " ")
    }
    return parseVerbisMessageDateValue(text)
}

func nextMessageContentHeader(after messageHeader: Element) throws -> Element? {
    if let found = try firstContentHeader(inSiblingsStartingAt: try messageHeader.nextElementSibling()) {
        return found
    }

    // Rows are often wrapped in separate <tbody> elements.
    var ancestor = messageHeader.parent()
    while let parent = ancestor {
        if let found = try firstContentHeader(inSiblingsStartingAt: try parent.nextElementSibling()) {
            return found
        }
        if parent.nodeName() == "table" { break }
        ancestor = parent.parent()
    }
    return nil
}

func nearestPrecedingMessageHeader(before element: Element) throws -> Element? {
    if let found = try lastMessageHeader(inPreviousSiblingsOf: element) {
        return found
    }

    var ancestor = element.parent()
    while let parent = ancestor {
        if let found = try lastMessageHeader(inPreviousSiblingsOf: parent) {
            return found
        }
        if parent.nodeName() == "table" { break }
        ancestor = parent.parent()
    }
    return nil
}

private func firstContentHeader(inSiblingsStartingAt start: Element?) throws -> Element? {
    var sibling = start
    while let current = sibling {
        if current.hasClass("wiadomosc-tr-header") {
            return nil
        }
        if current.hasClass("wiadomosc-tr-content-header") {
            return current
        }
        if let nested = try current.select(".wiadomosc-tr-content-header").array().first {
            return nested
        }
        if try current.select(".wiadomosc-tr-header").array().first != nil {
            return nil
        }
        sibling = try current.nextElementSibling()
    }
    return nil
}

private func lastMessageHeader(inPreviousSiblingsOf element: Element) throws -> Element? {
    var sibling = try element.previousElementSibling()
    while let current = sibling {
        if current.hasClass("wiadomosc-tr-header") {
            return current
        }
        if let nested = try current.select(".wiadomosc-tr-header").array().last {
            return nested
        }
        sibling = try current.previousElementSibling()
    }
    return nil
}
