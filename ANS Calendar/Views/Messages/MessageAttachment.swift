//
//  MessageAttachment.swift
//  ANS Calendar
//
//  Created by Stanisław on 04/03/2025.
//

import SwiftUI

struct MessageAttachment: View {
    let MessageAttachment: Attachment
    
    var body: some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading) {
                Text(MessageAttachment.AttachmentName)
                Text(MessageAttachment.Size)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

#Preview {
    MessageAttachment(MessageAttachment: Attachment(AttachmentName: "Awesome file", Size: "1 MB"))
}
