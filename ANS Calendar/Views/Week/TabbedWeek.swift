//
//  TabbedWeek.swift
//  ANS Calendar
//
//  Created by Stanisław on 26/11/2024.
//

import SwiftUI

struct TabbedWeek<Content: View>: View {
    @EnvironmentObject var model: ScheduleModel
    @State private var visibleWeek: Date?
    @State private var windowAnchor = Date().startOfWeek()
    @State private var suppressScrollSelection = false

    let content: (_ week: Week) -> Content

    init(@ViewBuilder content: @escaping (_ week: Week) -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if visibleWeek != nil {
                pager
            } else {
                Color.clear
            }
        }
        .frame(height: 96)
        .onAppear {
            if visibleWeek == nil {
                let week = model.SelectedWeek.startOfWeek()
                windowAnchor = week
                visibleWeek = week
            }
        }
        .onChange(of: model.SelectedWeek) { _, newValue in
            let week = newValue.startOfWeek()
            if !weekStarts.contains(week) {
                windowAnchor = week
            }
            guard visibleWeek?.IsSameWeek(date: week) != true else { return }
            assignVisibleWeek(week)
        }
        .onChange(of: visibleWeek) { _, newValue in
            guard let newValue, !suppressScrollSelection else { return }
            guard !newValue.IsSameWeek(date: model.SelectedDay) else { return }
            guard newValue.dayDistance(to: model.SelectedDay) <= 400 else {
                assignVisibleWeek(model.SelectedDay.startOfWeek())
                return
            }
            let weekday = Calendar.ans.component(.weekday, from: model.SelectedDay)
            guard let match = newValue.daysOfWeek().first(where: {
                Calendar.ans.component(.weekday, from: $0) == weekday
            }) else { return }
            model.SelectDay(day: match)
        }
    }

    private func assignVisibleWeek(_ week: Date) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            suppressScrollSelection = true
            visibleWeek = week.startOfWeek()
        }
        DispatchQueue.main.async {
            suppressScrollSelection = false
        }
    }

    private var weekPosition: Binding<Date?> {
        Binding(
            get: { visibleWeek },
            set: { visibleWeek = $0?.startOfWeek() }
        )
    }

    private var weekStarts: [Date] {
        let anchor = windowAnchor.startOfWeek()
        var weeks: [Date] = []
        for offset in -80...80 {
            let week = anchor.addingDays(offset * 7).startOfWeek()
            if weeks.last != week {
                weeks.append(week)
            }
        }
        return weeks
    }

    private var pager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(weekStarts, id: \.self) { week in
                    content(Week(Days: week.daysOfWeek()))
                        .containerRelativeFrame(.horizontal)
                        .id(week)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: weekPosition)
    }
}

#Preview {
    TabbedWeek { week in
        WeekView(week: week)
    }
    .environmentObject(ScheduleModel())
}
