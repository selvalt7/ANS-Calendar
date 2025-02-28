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

struct Message: Hashable, Codable, Identifiable {
    var id = UUID()
    
    let Sender: String
    let Title: String
    let Content: String
    var Unread: Bool
}

@MainActor
class MessagesModel: ObservableObject {
    @Published var UnreadMessages: Int = 0
    @Published var Messages: [Message] = []
    
    var Placeholder: [Message] = [
        Message(Sender: "Joe Doe", Title: "Important notice", Content: "Lorem ipsum", Unread: false),
        Message(Sender: "Jan Kowalski", Title: "Another important notice", Content: "Lorem ipsum", Unread: false)
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
                
                let Message = Message(Sender: Sender, Title: Title, Content: Content, Unread: Unread)
                
                Messages.append(Message)
            }
        } catch {
            
        }
    }
}
