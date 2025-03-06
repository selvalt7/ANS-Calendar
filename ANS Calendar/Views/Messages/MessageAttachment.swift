//
//  MessageAttachment.swift
//  ANS Calendar
//
//  Created by Stanisław on 04/03/2025.
//

import SwiftUI

struct MessageAttachment: View {
    let MessageAttachment: Attachment
    @State private var isWebViewPresented = false
    @EnvironmentObject var VerbisAnsAPI: VerbisAPI
    
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
        .sheet(isPresented: $isWebViewPresented) {
            NavigationStack {
                WebView(request: VerbisAnsAPI.InitRequest(EndUrl: MessageAttachment.Link.replacingOccurrences(of: "/ppuz-stud-app/ledge/view/", with: "")))
                    .navigationTitle(MessageAttachment.AttachmentName)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onTapGesture {
            isWebViewPresented.toggle()
        }
    }
}

#Preview {
    MessageAttachment(MessageAttachment: Attachment(AttachmentName: "Awesome file", Size: "1 MB"))
        .environmentObject(VerbisAPI())
}
