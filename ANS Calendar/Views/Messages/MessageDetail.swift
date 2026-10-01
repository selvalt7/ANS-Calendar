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
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Message.Title)
                        .font(.title)
                        .padding()
                    ForEach(Thread) { thread in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(thread.Sender)
                                    .font(.headline)
                                Spacer()
                                if let sentAt = thread.SentAt {
                                    Text(verbisMessageDateText(sentAt, includeTime: true))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Divider()
                            ForEach(0..<thread.Content.count) { paragraphId in
                                Text(.init(thread.Content[paragraphId]))
                            }
                            VStack(alignment: .leading) {
                                ForEach(thread.Attachments) { Attachment in
                                    MessageAttachment(MessageAttachment: Attachment)
                                        .environmentObject(VerbisAnsAPI)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                    }
                }
                Spacer()
            }
            .task {
                await Thread = MessagesModel.FetchMessage(VerbisAnsAPI: VerbisAnsAPI, MessageData: Message.MessageData)
                if let sentAt = Thread.compactMap(\.SentAt).first {
                    MessagesModel.updateMessageDate(
                        threadId: Message.MessageData.idWatku,
                        date: sentAt,
                        includesTime: true
                    )
                }
                
                await MessagesModel.NotifyRead(VerbisAPI: VerbisAnsAPI, MessageData: Message.MessageData)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

#Preview {
    MessageDetail(Message: MessagesModel().Placeholder[0])
        .environmentObject(MessagesModel())
        .environmentObject(VerbisAPI())
}
