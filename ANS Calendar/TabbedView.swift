//
//  TabbedView.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI

struct TabbedView: View {
    @AppStorage("JSessionID") var JSessionID: String = ""
    @AppStorage("StudentID") var StudentID: Int = 0
    @AppStorage("TourID") var TourID: Int = 0
    var body: some View {
        TabView {
            Tab("Home", systemImage: "") {
                Text("Home")
            }
            Tab("Schedule", systemImage: "") {
                Schedule()
            }
            Tab("Settings", systemImage: "") {
                Text(JSessionID)
                Text(String(StudentID))
                Text(String(TourID))
            }
        }
    }
}

#Preview {
    TabbedView()
}
