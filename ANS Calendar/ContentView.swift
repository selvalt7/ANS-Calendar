//
//  ContentView.swift
//  ANS Calendar
//
//  Created by Stanisław on 15/11/2024.
//

import SwiftUI

let AJAXUrl = "https://wu.ans-nt.edu.pl/ppuz-stud-app/ledge/view/AJAX"

struct ContentView: View {
    @Binding var LoginData: LoginResult
    @AppStorage("JSessionID") var JSessionID: String = ""
    @AppStorage("StudentID") var StudentID: Int = 0
    
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text(String(StudentID))
            Text(String(JSessionID))
        }
        .padding()
    }
}

#Preview {
    @Previewable @State var LoginData: LoginResult = LoginResult(Success: true, JSessionID: "", StudentID: 0)
    ContentView(LoginData: $LoginData)
}
