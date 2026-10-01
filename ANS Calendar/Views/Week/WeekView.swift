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
        HStack(spacing: 0) {
            ForEach(Array(week.Days.enumerated()), id: \.offset) { _, day in
                dayCell(day)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = day.IsSameDay(date: model.SelectedDay)
        let isToday = Date().IsSameDay(date: day)
        let hasClasses = !model.schedules(on: day).isEmpty

        return Button {
            model.SelectDay(day: day)
        } label: {
            VStack(spacing: 4) {
                Text(day.GetShortDayName())
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(String(Calendar.ans.component(.day, from: day)))
                    .font(.body.weight(isToday ? .bold : .semibold))
                    .foregroundStyle(numberColor(isSelected: isSelected, isToday: isToday, day: day))
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                Circle()
                    .fill(hasClasses ? (isSelected ? Color.accentColor : Color.accentColor.opacity(0.85)) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func numberColor(isSelected: Bool, isToday: Bool, day: Date) -> Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        if day.isWeekend { return .secondary }
        return .primary
    }
}

#Preview {
    WeekView(week: Week(Days: Date().daysOfWeek()))
        .environmentObject(ScheduleModel())
}
