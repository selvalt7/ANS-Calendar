//
//  MonthCalendarView.swift
//  ANS Calendar
//
//  Created by Stanisław on 07/03/2026.
//

import SwiftUI

struct MonthCalendarView: View {
    @EnvironmentObject var model: ScheduleModel
    @State private var visibleMonth: Date?
    @State private var windowAnchor = Date().startOfMonth
    @State private var suppressScrollSelection = false

    private let rowHeight: CGFloat = 44
    private var gridHeight: CGFloat { rowHeight * 6 }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(headerTitle)
                    .font(.title3.bold())
                Spacer()
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal)

            HStack(spacing: 0) {
                ForEach(Array(Calendar.mondayFirstWeekdaySymbols.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            Group {
                if visibleMonth != nil {
                    pager
                } else {
                    Color.clear
                }
            }
            .frame(height: gridHeight)
        }
        .padding(.vertical, 8)
        .onAppear {
            if visibleMonth == nil {
                let month = model.SelectedDay.startOfMonth
                windowAnchor = month
                visibleMonth = month
                publish(month)
            }
        }
        .onChange(of: model.SelectedDay) { _, newDay in
            let month = newDay.startOfMonth
            guard visibleMonth?.IsSameMonth(date: month) != true else { return }
            if !monthWindow.contains(month) {
                windowAnchor = month
            }
            assignVisibleMonth(month)
        }
        .onChange(of: visibleMonth) { _, month in
            guard let month else { return }
            if suppressScrollSelection {
                publish(month)
                return
            }
            guard month.monthDistance(to: model.DisplayedMonth) <= 18 else {
                assignVisibleMonth(model.DisplayedMonth.startOfMonth)
                return
            }
            publish(month)
        }
    }

    private func assignVisibleMonth(_ month: Date) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            suppressScrollSelection = true
            visibleMonth = month.startOfMonth
        }
        DispatchQueue.main.async {
            suppressScrollSelection = false
        }
    }

    private var headerTitle: String {
        (visibleMonth ?? model.DisplayedMonth).formatted(.dateTime.month(.wide).year())
    }

    private var monthPosition: Binding<Date?> {
        Binding(
            get: { visibleMonth },
            set: { visibleMonth = $0?.startOfMonth }
        )
    }

    private var monthWindow: [Date] {
        let anchor = windowAnchor.startOfMonth
        var months: [Date] = []
        for offset in -24...24 {
            let month = anchor.addingMonths(offset).startOfMonth
            if months.last != month {
                months.append(month)
            }
        }
        return months
    }

    private var pager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(monthWindow, id: \.self) { month in
                    MonthGrid(month: month, rowHeight: rowHeight)
                        .containerRelativeFrame(.horizontal)
                        .id(month)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: monthPosition)
    }

    private func shiftMonth(by delta: Int) {
        let current = (visibleMonth ?? model.DisplayedMonth).startOfMonth
        let next = current.addingMonths(delta).startOfMonth
        if !monthWindow.contains(next) {
            windowAnchor = next
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            visibleMonth = next
        }
    }

    private func publish(_ month: Date) {
        let start = month.startOfMonth
        if !model.DisplayedMonth.IsSameMonth(date: start) {
            model.DisplayedMonth = start
        }
    }
}

private struct MonthGrid: View {
    @EnvironmentObject var model: ScheduleModel
    let month: Date
    let rowHeight: CGFloat

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(month.monthGridDates().enumerated()), id: \.offset) { _, day in
                dayCell(day)
            }
        }
        .padding(.horizontal, 8)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = day.IsSameDay(date: model.SelectedDay)
        let isToday = Date().IsSameDay(date: day)
        let inMonth = day.IsSameMonth(date: month)
        let events = model.schedules(on: day)

        return Button {
            model.SelectDay(day: day)
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.ans.component(.day, from: day))")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(textColor(isSelected: isSelected, isToday: isToday, inMonth: inMonth, day: day))
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                Circle()
                    .fill(dotColor(events: events, inMonth: inMonth))
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func textColor(isSelected: Bool, isToday: Bool, inMonth: Bool, day: Date) -> Color {
        if isSelected { return .white }
        if !inMonth { return .secondary.opacity(0.45) }
        if isToday { return .accentColor }
        if day.isWeekend { return .secondary }
        return .primary
    }

    private func dotColor(events: [ScheduleInfo], inMonth: Bool) -> Color {
        guard !events.isEmpty else { return .clear }
        let color: Color = events.contains(where: \.isExam) ? .red : .accentColor
        return inMonth ? color : color.opacity(0.4)
    }
}

#Preview {
    MonthCalendarView()
        .environmentObject(ScheduleModel())
}
