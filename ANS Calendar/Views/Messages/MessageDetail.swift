//
//  MessageDetail.swift
//  ANS Calendar
//
//  Created by Stanisław on 28/02/2025.
//

import SwiftUI

struct MessageDetail: View {
    let Message: Message
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(Message.Sender)
                    .font(.headline)
                Divider()
                VStack(alignment: .leading, spacing: 25) {
                    Text(Message.Title)
                        .font(.title)
                    Text(Message.Content)
                        .textSelection(.enabled)
                }
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    MessageDetail(Message: Message(Sender: "Joe Doe", Title: "Important notice", Content: "Lorem ipsum", Unread: false))
}
