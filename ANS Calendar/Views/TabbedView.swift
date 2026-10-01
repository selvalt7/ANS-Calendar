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
    
    @State private var showPasswordChangeSheet = false;
    
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
            .badge(Messages.UnreadMessages)
            Tab("Settings", systemImage: "slider.horizontal.3") {
                Form {
                    // 2. Add an Account section for user actions
                    Section(header: Text("Account")) {
                        Button("Change Password") {
                            showPasswordChangeSheet = true
                        }
                        
                        Button("Logout") {
                            Task {
                                await VerbisANSApi.Logout()
                            }
                        }
                        .foregroundColor(.red) // Optional: highlights the destructive action
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
        // 3. Bind the sheet to BOTH the manual button press and the API error
        .sheet(isPresented: Binding(
            get: {
                showPasswordChangeSheet || VerbisANSApi.AuthError == .ExpiredPassword
            },
            set: { isVisible in
                showPasswordChangeSheet = isVisible
                
                // Safety clear: if the sheet is dismissed, ensure the forced error state is wiped
                if !isVisible && VerbisANSApi.AuthError == .ExpiredPassword {
                    VerbisANSApi.AuthError = nil
                }
            }
        )) {
            PasswordChangeView()
                // Inject the environment object if PasswordChangeView expects it
                .environmentObject(VerbisANSApi)
        }
        .task {
            if VerbisANSApi.IsLoggedIn {
                await Messages.getUnreadMessages(VerbisANSApi: VerbisANSApi)
            }
        }
    }
}

#Preview {
    TabbedView()
        .environmentObject(VerbisAPI())
}
