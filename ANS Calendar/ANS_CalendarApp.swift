//
//  ANS_CalendarApp.swift
//  ANS Calendar
//
//  Created by Stanisław on 15/11/2024.
//

import SwiftUI
import Security

@main
struct ANS_CalendarApp: App {
    @StateObject var VerbisANSApi = VerbisAPI()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if (VerbisANSApi.IsLoggedIn) {
                    TabbedView()
                        .environmentObject(VerbisANSApi)
                } else {
                    LoginView()
                        .environmentObject(VerbisANSApi)
                }
                if VerbisANSApi.IsBusy {
                    ProgressView()
                        .frame(alignment: .top)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }
}
