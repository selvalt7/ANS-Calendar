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
            
            let html = decodePortalHTML(data)
            
            for message in try parseMessageList(html: html) {
                if let index = Messages.firstIndex(where: { $0.MessageData.idWatku == message.MessageData.idWatku }) {
                    // Refresh dates for rows that were appended earlier without a stamp.
                    if Messages[index].Date == nil, let date = message.Date {
                        Messages[index].Date = date
                        Messages[index].DateHasTime = message.DateHasTime
                    } else if let date = message.Date,
                              message.DateHasTime,
                              !(Messages[index].DateHasTime) {
                        Messages[index].Date = date
                        Messages[index].DateHasTime = true
                    }
                } else {
                    Messages.append(message)
                }
            }
            // Ensure @Published emits after in-place date fixes.
            Messages = Messages
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
            
            let html = decodePortalHTML(data)
            let doc: Document = try SwiftSoup.parse(html)
            let rawHeaderDates = contentHeaderDatePairsFromHTML(html)
            
            let MessagesRowContent: Elements = try doc.select(".wiadomosc-tr-content")
            
            var MessageThread: [MessageContent] = []
            var rawDateIndex = 0
            
            for MessageData in MessagesRowContent.array() {
                var MessageContentData = MessageContent()
                
                // Pair each body row with its neighboring content-header — never a global index into
                // every list header on the page (that assigned one message's date to another).
                guard let header = try contentHeader(forContentRow: MessageData) else { continue }
                let headerDivs = try header.select("div").array()
                let senderElement = try header.select(".fltlft").array().first ?? headerDivs.first
                guard let senderElement, let sender = try? senderElement.text(), !sender.isEmpty else { continue }
                MessageContentData.Sender = sender
                if let parsed = try verbisMessageDateValue(in: header) {
                    MessageContentData.SentAt = parsed.date
                } else if rawDateIndex < rawHeaderDates.count {
                    // Fall back to stamps extracted from the raw markup order.
                    MessageContentData.SentAt = rawHeaderDates[rawDateIndex].stamp.date
                }
                rawDateIndex += 1
                
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
        Messages = Messages
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
    let contentHeaderDates = try contentHeaderDatesForMessageHeaders(messageHeaders, in: doc)
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
            contentHeaderDate: contentHeaderDates[index],
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

/// Prefer each row's own content-header date (timed when available), then list-row / JSON fallbacks.
func messageListDate(
    for messageHeader: Element,
    contentHeaderDate: VerbisMessageDate?,
    rowJSON: Data? = nil
) throws -> VerbisMessageDate? {
    var best = contentHeaderDate

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

/// Resolve each list row's date without relying on element identity.
/// Uses interleaved document order, raw HTML fltrt pairs, neighbors, sender, then index.
func contentHeaderDatesForMessageHeaders(_ messageHeaders: [Element], in document: Document) throws -> [Int: VerbisMessageDate] {
    var dates: [Int: VerbisMessageDate] = [:]

    // 1) Interleaved document order: each content-header belongs to the previous list row.
    var messageIndex = -1
    for row in try document.select(".wiadomosc-tr-header, .wiadomosc-tr-content-header").array() {
        if row.hasClass("wiadomosc-tr-header") {
            messageIndex += 1
            continue
        }
        guard row.hasClass("wiadomosc-tr-content-header"),
              messageIndex >= 0,
              messageIndex < messageHeaders.count
        else { continue }
        if let parsed = try verbisMessageDateValue(in: row) {
            dates[messageIndex] = betterMessageDate(dates[messageIndex], parsed)
        }
    }

    // 2) Raw HTML pairs (survives odd DOM nesting / entity encoding).
    let html = try document.outerHtml()
    var rawPairs = contentHeaderDatePairsFromHTML(html)
    if rawPairs.isEmpty, let body = try? document.body()?.html() {
        rawPairs = contentHeaderDatePairsFromHTML(body)
    }
    var usedRaw = Set<Int>()
    for (index, messageHeader) in messageHeaders.enumerated() {
        if let existing = dates[index], existing.includesTime { continue }
        let sender = normalizeMessageSenderText(try messageHeader.select(".wiadomosc-nadawca").array().first?.text() ?? "")
        if !sender.isEmpty,
           let rawIndex = rawPairs.indices.first(where: { !usedRaw.contains($0) && rawPairs[$0].sender == sender }) {
            dates[index] = betterMessageDate(dates[index], rawPairs[rawIndex].stamp)
            usedRaw.insert(rawIndex)
            continue
        }
        if dates[index] == nil,
           let rawIndex = rawPairs.indices.first(where: { !usedRaw.contains($0) }) {
            // Preserve remaining markup order when sender labels differ slightly.
            dates[index] = rawPairs[rawIndex].stamp
            usedRaw.insert(rawIndex)
        }
    }

    // 3) Neighboring content-header after each list row.
    for (index, messageHeader) in messageHeaders.enumerated() {
        if let existing = dates[index], existing.includesTime { continue }
        guard let sibling = try nextMessageContentHeader(after: messageHeader),
              let date = try verbisMessageDateValue(in: sibling)
        else { continue }
        dates[index] = betterMessageDate(dates[index], date)
    }

    // 4) Classic parallel index for any remaining gaps.
    let contentHeaders = try document.select(".wiadomosc-tr-content-header").array()
    for (index, contentHeader) in contentHeaders.enumerated() where index < messageHeaders.count {
        if let existing = dates[index], existing.includesTime { continue }
        if let parsed = try verbisMessageDateValue(in: contentHeader) {
            dates[index] = betterMessageDate(dates[index], parsed)
        }
    }

    return dates
}

/// Content body rows are preceded by their content-header; list headers on the same page must not be used by index.
func contentHeader(forContentRow contentRow: Element) throws -> Element? {
    if let header = try nearestPrecedingContentHeader(before: contentRow) {
        return header
    }
    // Some markup nests the header inside a wrapper before the body.
    if let parent = contentRow.parent() {
        if let header = try nearestPrecedingContentHeader(before: parent) {
            return header
        }
        if let nested = try parent.select(".wiadomosc-tr-content-header").array().first {
            return nested
        }
    }
    return nil
}

func nearestPrecedingContentHeader(before element: Element) throws -> Element? {
    var sibling = try element.previousElementSibling()
    while let current = sibling {
        if current.hasClass("wiadomosc-tr-header") {
            return nil
        }
        if current.hasClass("wiadomosc-tr-content") {
            return nil
        }
        if current.hasClass("wiadomosc-tr-content-header") {
            return current
        }
        if let nested = try current.select(".wiadomosc-tr-content-header").array().last {
            return nested
        }
        sibling = try current.previousElementSibling()
    }

    var ancestor = element.parent()
    while let parent = ancestor {
        var uncle = try parent.previousElementSibling()
        while let current = uncle {
            if current.hasClass("wiadomosc-tr-header") {
                return nil
            }
            if current.hasClass("wiadomosc-tr-content-header") {
                return current
            }
            if let nested = try current.select(".wiadomosc-tr-content-header").array().last {
                return nested
            }
            uncle = try current.previousElementSibling()
        }
        if parent.nodeName() == "table" { break }
        ancestor = parent.parent()
    }
    return nil
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
