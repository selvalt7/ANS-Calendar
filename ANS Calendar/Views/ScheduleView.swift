//
//  ScheduleView.swift
//  ANS Calendar
//

import SwiftUI

enum CalendarLayout: String, CaseIterable {
    case daily = "Daily"
    case monthly = "Monthly"
}

private struct ScheduleObscuredBottomKey: EnvironmentKey {
    static let defaultValue: CGFloat = 96
}

extension EnvironmentValues {
    var scheduleObscuredBottom: CGFloat {
        get { self[ScheduleObscuredBottomKey.self] }
        set { self[ScheduleObscuredBottomKey.self] = newValue }
    }
}

/// Reads how much of the bottom edge is covered by the tab bar and home indicator.
private struct ObscuredBottomReader: UIViewRepresentable {
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            let resolved = Self.resolve(uiView.safeAreaInsets.bottom)
            if abs(resolved - height) > 0.5 {
                height = resolved
            }
        }
    }

    static func resolve(_ measured: CGFloat) -> CGFloat {
        if measured >= 70 { return measured }
        if measured > 0 { return measured + 49 }
        return 96
    }
}

struct ScheduleView: View {
    @EnvironmentObject var VerbisANSApi: VerbisAPI
    @StateObject var model = ScheduleModel()
    @State private var currentLayout: CalendarLayout = .daily
    @State private var selectedSchedule: ScheduleInfo?
    @State private var obscuredBottom: CGFloat = 96

    private var isViewingToday: Bool {
        Date().IsSameDay(date: model.SelectedDay)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if currentLayout == .monthly {
                    MonthCalendarView()
                        .environmentObject(model)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    TabbedWeek { week in
                        WeekView(week: week)
                    }
                    .environmentObject(model)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider()

                TabbedDay(onRefresh: reload) { day in
                    DayView(
                        date: day,
                        schedules: model.schedules(on: day),
                        isLoading: model.IsLoading,
                        statusText: model.LoadError,
                        onSelect: { selectedSchedule = $0 }
                    )
                }
                .environmentObject(model)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                ObscuredBottomReader(height: $obscuredBottom)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .opacity(0)
            }
            .environment(\.scheduleObscuredBottom, obscuredBottom)
            .task {
                await model.LoadSchedule(VerbisANSApi: VerbisANSApi)
            }
            .onChange(of: model.SelectedWeek) { _, _ in
                Task { await model.LoadSchedule(VerbisANSApi: VerbisANSApi) }
            }
            .onChange(of: model.DisplayedMonth) { _, month in
                guard currentLayout == .monthly else { return }
                Task { await model.LoadMonth(month, VerbisANSApi: VerbisANSApi) }
            }
            .onChange(of: currentLayout) { _, layout in
                Task {
                    if layout == .monthly {
                        await model.LoadMonth(model.DisplayedMonth, VerbisANSApi: VerbisANSApi)
                    } else {
                        await model.LoadSchedule(VerbisANSApi: VerbisANSApi)
                    }
                }
            }
            .navigationTitle(model.SelectedDay.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: toggleMonth) {
                        Image(systemName: currentLayout == .monthly ? "rectangle.grid.1x2" : "calendar")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel(currentLayout == .monthly ? "Day" : "Month")
                }

                if !isViewingToday {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Today") {
                            model.SelectDay(day: Date())
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentLayout)
            .sheet(item: $selectedSchedule) { schedule in
                ScheduleDetailSheet(schedule: schedule)
            }
        }
        // Draw the timeline underneath the translucent tab bar. Scroll views add
        // bottom padding so the last hour can still be scrolled clear of it.
        .ignoresSafeArea(edges: .bottom)
    }

    private func reload() async {
        if currentLayout == .monthly {
            await model.LoadMonth(model.DisplayedMonth, VerbisANSApi: VerbisANSApi)
        }
        await model.LoadSchedule(VerbisANSApi: VerbisANSApi)
    }

    private func toggleMonth() {
        if currentLayout == .monthly {
            currentLayout = .daily
            return
        }
        let month = model.SelectedDay.startOfMonth
        if !model.DisplayedMonth.IsSameMonth(date: month) {
            model.DisplayedMonth = month
        }
        currentLayout = .monthly
    }
}

#Preview {
    ScheduleView()
        .environmentObject(VerbisAPI())
}
