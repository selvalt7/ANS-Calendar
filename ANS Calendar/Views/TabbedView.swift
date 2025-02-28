//
//  TabbedView.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI

struct TabbedView: View {
    @EnvironmentObject var VerbisANSApi: VerbisAPI
    @StateObject var Messages = MessagesModel()
    
    var body: some View {
        TabView {
            Tab("Schedule", systemImage: "calendar") {
                ScheduleView()
            }
            Tab("Messages", systemImage: "envelope") {
                MessagesView()
                    .environmentObject(Messages)
                    .environmentObject(VerbisANSApi)
            }
            Tab("Settings", systemImage: "slider.horizontal.3") {
                Form {
                    Button("Logout") {
                        Task {
                            await VerbisANSApi.Logout()
                        }
                    }
                    Section(header: Text("Debug")) {
                        Text(VerbisANSApi.JSessionID)
                        Text(String(VerbisANSApi.StudentID))
                        Text(String(VerbisANSApi.TourID))
                        Button("Invalidate SessionID") {
                            VerbisANSApi.JSessionID = ""
                            UserDefaults.standard.set("", forKey: "JSessionID")
                        }
                    }
                }
                
            }
        }
    }
}

#Preview {
    TabbedView()
        .environmentObject(VerbisAPI())
}
