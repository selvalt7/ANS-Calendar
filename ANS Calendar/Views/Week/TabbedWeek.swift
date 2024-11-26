//
//  TabbedWeek.swift
//  ANS Calendar
//
//  Created by Stanisław on 26/11/2024.
//

import SwiftUI

struct TabbedWeek<Content: View>: View {
    @EnvironmentObject var model: ScheduleModel
    @EnvironmentObject var VerbisAPI: VerbisAPI
    @State private var selectedPage: Int = 1
    @State private var dir: Int = 0
    
    let content: (_ week: Week) -> Content
    
    init(@ViewBuilder content: @escaping (_ week: Week) -> Content) {
        self.content = content
    }
    
    var body: some View {
        VStack {
            TabView(selection: $selectedPage) {
                content(model.Weeks[0])
                    .tag(0)
                content(model.Weeks[1])
                    .tag(1)
                    .onDisappear() {
                        if dir != 0 {
                            model.ShiftWeeks(dir: dir)
                        }
                        
                        dir = 0
                        selectedPage = 1
                        
                        Task {
                            try await model.LoadSchedule(VerbisANSApi: VerbisAPI)
                        }
                    }
                content(model.Weeks[2])
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selectedPage) { value in
                if value == 0 {
                    dir = -1
                } else if value == 2 {
                    dir = 1
                }
            }
        }
    }

}

#Preview {
    TabbedWeek() { week in
        WeekView(week: week)
    }
    .environmentObject(ScheduleModel())
    .environmentObject(VerbisAPI())
}
