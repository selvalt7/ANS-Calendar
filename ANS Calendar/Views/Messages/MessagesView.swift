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
    @State private var Offset: Int = 0
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                List(Messages.Messages) { Message in
                    NavigationLink {
                        MessageDetail(Message: Message)
                    } label: {
                        MessageRow(Message: Message)
                            .environmentObject(Messages)
                            .environmentObject(VerbisANSApi)
                            .onAppear() {
                                if (self.Messages.Messages.last == Message) {
                                    Task {
                                        await Messages.FetchMessages(VerbisAnsAPI: VerbisANSApi, Offset: self.Offset + 50)
                                    }
                                    self.Offset += 50
                                }
                            }
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
                    Messages.Messages.removeAll()
                    try await Messages.FetchMessages(VerbisAnsAPI: VerbisANSApi)
                } catch {
                    
                }
            }
            if Messages.IsBusy {
                ProgressView()
                    .frame(alignment: .top)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

#Preview {
    MessagesView()
        .environmentObject(MessagesModel())
        .environmentObject(VerbisAPI())
}
