//
//  MessageRow.swift
//  ANS Calendar
//
//  Created by Stanisław on 28/02/2025.
//

import SwiftUI

struct MessageRow: View {
    let Message: Message
    var body: some View {
        HStack {
            Circle()
                .foregroundStyle(.blue)
                .frame(width: 10)
                .opacity(Message.Unread ? 1 : 0)
            VStack(alignment: .leading) {
                HStack {
                    Text(Message.Sender)
                        .font(.headline)
                    Spacer()
                    Text(Message.Date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
                Text(Message.Title)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(10)
    }
}

#Preview {
    MessageRow(Message: MessagesModel().Placeholder[0])
}
