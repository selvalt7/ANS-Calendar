//
//  TabbedDay.swift
//  ANS Calendar
//
//  Created by Stanisław on 23/11/2024.
//

import SwiftUI

struct TabbedDay<Content: View>: View {
    @EnvironmentObject var model: ScheduleModel
    @State private var scrolledDay: Date?
    @State private var windowAnchor = Date().startOfDay
    @State private var suppressScrollSelection = false

    var onRefresh: () async -> Void = {}
    let content: (_ date: Date) -> Content

    init(onRefresh: @escaping () async -> Void = {}, @ViewBuilder content: @escaping (_ date: Date) -> Content) {
        self.onRefresh = onRefresh
        self.content = content
    }

    var body: some View {
        Group {
            if scrolledDay != nil {
                pager
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if scrolledDay == nil {
                let day = model.SelectedDay.startOfDay
                windowAnchor = day
                scrolledDay = day
            }
        }
        .onChange(of: model.SelectedDay) { _, newValue in
            let day = newValue.startOfDay
            if !pagingDays.contains(day) {
                windowAnchor = day
            }
            guard scrolledDay?.IsSameDay(date: day) != true else { return }
            assignScrolledDay(day)
        }
        .onChange(of: scrolledDay) { _, newValue in
            guard let newValue else { return }
            if newValue.IsSameDay(date: model.SelectedDay) || suppressScrollSelection { return }
            // The pager's first layout can report the first page instead of the selected day.
            guard newValue.dayDistance(to: model.SelectedDay) <= 400 else {
                assignScrolledDay(model.SelectedDay.startOfDay)
                return
            }
            model.SelectDay(day: newValue)
        }
    }

    private func assignScrolledDay(_ day: Date) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            suppressScrollSelection = true
            scrolledDay = day.startOfDay
        }
        DispatchQueue.main.async {
            suppressScrollSelection = false
        }
    }

    private var dayPosition: Binding<Date?> {
        Binding(
            get: { scrolledDay },
            set: { scrolledDay = $0?.startOfDay }
        )
    }

    private var pagingDays: [Date] {
        makePagingDays(anchor: windowAnchor)
    }

    private var pager: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(pagingDays, id: \.self) { day in
                        DayPage(
                            date: day,
                            anchorID: anchorID(for: day),
                            onRefresh: onRefresh
                        ) {
                            content(day)
                        }
                        .frame(width: geo.size.width, height: max(geo.size.height, 1))
                        .id(day)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: dayPosition)
        }
    }

    private func anchorID(for day: Date) -> String {
        if day.IsSameDay(date: Date()) {
            let minutes = Date().minutesFromMidnight
            if minutes >= dayStartHour * 60 && minutes <= dayEndHour * 60 {
                return "now"
            }
        }
        if let first = model.schedules(on: day).min(by: { $0.dataRozpoczecia < $1.dataRozpoczecia }),
           first.startDate.minutesFromMidnight < dayEndHour * 60 {
            return "event-\(first.dataRozpoczecia)-0"
        }
        return "hour-8"
    }

    private func makePagingDays(anchor: Date) -> [Date] {
        let start = anchor.startOfDay
        var days: [Date] = []
        days.reserveCapacity(1001)
        for offset in -500...500 {
            let day = start.addingDays(offset).startOfDay
            if days.last != day {
                days.append(day)
            }
        }
        return days
    }
}

private struct DayPage<Content: View>: View {
    @Environment(\.scheduleObscuredBottom) private var obscuredBottom

    let date: Date
    let anchorID: String
    var onRefresh: () async -> Void
    let content: () -> Content

    @State private var appliedAnchor: String?

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.background)
            ParkingDayBanner(date: date)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    content()
                        .padding(.bottom, obscuredBottom)
                }
                .ignoresSafeArea(edges: .bottom)
                .refreshable { await onRefresh() }
                .onAppear { scroll(proxy) }
                .onChange(of: anchorID) { _, _ in
                    scroll(proxy)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var title: String {
        let formatted = date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        if date.IsSameDay(date: Date()) {
            return "Today · \(formatted)"
        }
        return formatted
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        if appliedAnchor == anchorID { return }
        if let appliedAnchor, appliedAnchor != "hour-8" { return }
        let target = anchorID
        let anchor: UnitPoint = target == "now" ? .center : .top
        appliedAnchor = target
        Task { @MainActor in
            proxy.scrollTo(target, anchor: anchor)
            try? await Task.sleep(for: .milliseconds(80))
            proxy.scrollTo(target, anchor: anchor)
        }
    }
}

#Preview {
    TabbedDay { date in
        Text(date.formatted(date: .abbreviated, time: .omitted))
            .frame(maxWidth: .infinity, minHeight: 400)
    }
    .environmentObject(ScheduleModel())
    .environmentObject(ParkingModel())
}
