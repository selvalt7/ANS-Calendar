//
//  ScheduleView.swift
//  ANS Calendar
//
//  Created by Stanisław on 26/11/2024.
//

import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var VerbisANSApi: VerbisAPI
    @StateObject var model = ScheduleModel()
    
    var body: some View {
        VStack(spacing: 0) {
            TabbedWeek() { week in
                WeekView(week: week)
            }
            .frame(height: 110)
            .environmentObject(model)
            TabbedDay() { day in
                DayView(date: day, schedules: model.Schedules.filter({ Date(timeIntervalSince1970: Double($0.dataRozpoczecia / 1000)).IsSameDay(date: day) }))
            }
            .refreshable {
                do {
                    try await model.LoadSchedule(VerbisANSApi: VerbisANSApi)
                } catch {
                    
                }
            }
            .task {
                do {
                    try await model.LoadSchedule(VerbisANSApi: VerbisANSApi)
                } catch {
                    
                }
            }
            .environmentObject(model)
        }
    }
}

#Preview {
    ScheduleView()
        .environmentObject(VerbisAPI())
}
