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
    @StateObject private var parking = ParkingModel()
    
    @State private var showPasswordChangeSheet = false;
    
    var body: some View {
        TabView {
            Tab("Schedule", systemImage: "calendar") {
                ScheduleView()
                    .environmentObject(parking)
            }
            Tab("Messages", systemImage: "envelope") {
                MessagesView()
                    .environmentObject(Messages)
                    .environmentObject(VerbisANSApi)
            }
            .badge(Messages.UnreadMessages)
            Tab("Grades", systemImage: "graduationcap") {
                GradesView()
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
            }
            Tab("Settings", systemImage: "slider.horizontal.3") {
                SettingsView(showPasswordChangeSheet: $showPasswordChangeSheet)
                    .environmentObject(parking)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environmentObject(parking)
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
