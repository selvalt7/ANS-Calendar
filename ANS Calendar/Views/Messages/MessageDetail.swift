//
//  MessageDetail.swift
//  ANS Calendar
//
//  Created by Stanisław on 28/02/2025.
//

import SwiftUI

struct MessageDetail: View {
    @EnvironmentObject var MessagesModel: MessagesModel
    @EnvironmentObject var VerbisAnsAPI: VerbisAPI
    let Message: Message
    @State private var Thread: [MessageContent]
    
    init(Message: Message) {
        self.Message = Message
        self.Thread = []
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(Message.Sender)
                    .font(.headline)
                Divider()
                VStack(alignment: .leading, spacing: 25) {
                    Text(Message.Title)
                        .font(.title)
                }
            }
            ForEach(Thread) { thread in
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<thread.Content.count) { paragraphId in
                        Text(.init(thread.Content[paragraphId]))
                    }
                    VStack(alignment: .leading) {
                        ForEach(thread.Attachments) { Attachment in
                            MessageAttachment(MessageAttachment: Attachment)
                        }
                    }
                }
            }
            
        }
        .task {
            await Thread = MessagesModel.FetchMessage(VerbisAnsAPI: VerbisAnsAPI, MessageData: Message.MessageData)
        }
        .padding()
    }
}

#Preview {
    MessageDetail(Message: MessagesModel().Placeholder[0])
        .environmentObject(MessagesModel())
        .environmentObject(VerbisAPI())
}
