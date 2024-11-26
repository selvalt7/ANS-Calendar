//
//  WeekView.swift
//  ANS Calendar
//
//  Created by Stanisław on 26/11/2024.
//

import SwiftUI

struct WeekView: View {
    @EnvironmentObject var model: ScheduleModel
    var week: Week
    
    var body: some View {
        HStack() {
            ForEach(0..<7) {day in
                VStack() {
                    Text(week.Days[day].GetShortDayName())
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .scaleEffect(week.Days[day].IsSameDay(date: model.SelectedDay) ? 1 : 0)
                            .animation(.easeOut(duration: 0.12), value: week.Days[day].IsSameDay(date: model.SelectedDay))
                        Text(String(Calendar.current.component(.day, from: week.Days[day])))
                            .font(.title2)
                            .foregroundStyle(Date().IsSameDay(date: week.Days[day]) && !week.Days[day].IsSameDay(date: model.SelectedDay) ? Color.accentColor : Color.primary)
                    }
                }
                .onTapGesture {
                    model.SelectDay(day: week.Days[day])
                }
            }
        }
        .padding()
    }
}

#Preview {
    WeekView(week: Week(Days: [
        Date().Yesterday.Yesterday.Yesterday,
        Date().Yesterday.Yesterday,
        Date().Yesterday,
        Date(),
        Date().Tomorrow,
        Date().Tomorrow.Tomorrow,
        Date().Tomorrow.Tomorrow.Tomorrow
    ]))
    .environmentObject(ScheduleModel())
}
