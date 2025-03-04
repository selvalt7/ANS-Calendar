//
//  MessagesView.swift
//  ANS Calendar
//
//  Created by Stanisław on 28/02/2025.
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var Messages: MessagesModel
    @EnvironmentObject var VerbisANSApi: VerbisAPI
    
    var body: some View {
        NavigationSplitView {
            List(Messages.Messages) { Message in
                NavigationLink {
                    MessageDetail(Message: Message)
                } label: {
                    MessageRow(Message: Message)
                        .environmentObject(Messages)
                        .environmentObject(VerbisANSApi)
                }
            }
            .listStyle(.plain)
        } detail: {
            Text("Select message")
        }
        .task {
            do {
                try await Messages.FetchMessages(VerbisAnsAPI: VerbisANSApi)
            } catch {
                
            }
        }
        .refreshable {
            do {
                try await Messages.FetchMessages(VerbisAnsAPI: VerbisANSApi)
            } catch {
                
            }
        }
    }
}

#Preview {
    MessagesView()
        .environmentObject(MessagesModel())
        .environmentObject(VerbisAPI())
}
