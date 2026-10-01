//
//  ScheduleView.swift
//  ANS Calendar
//

import SwiftUI

// 1. Define your three layout states
enum CalendarLayout: String, CaseIterable {
    case daily = "Daily"
    case multiDay = "Multi-Day"
    case monthly = "Monthly"
}

struct ScheduleView: View {
    @EnvironmentObject var VerbisANSApi: VerbisAPI
    @StateObject var model = ScheduleModel()
    
    // 2. Track the current layout instead of a boolean
    @State private var currentLayout: CalendarLayout = .daily
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Main Content Area
                if currentLayout == .multiDay {
                    // THE NEW THIRD LAYOUT
                    // Takes up the entire screen to show side-by-side days
                    ResponsiveWeekView()
                        .environmentObject(model)
                        .transition(.opacity)
                } else {
                    // THE ORIGINAL DAILY/MONTHLY SPLIT LAYOUT
                    VStack(spacing: 0) {
                        // Top Header (Month Grid or Week Strip)
                        VStack {
                            if currentLayout == .monthly {
                                MonthCalendarView()
                                    .environmentObject(model)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            } else { // .daily
                                TabbedWeek() { week in
                                    WeekView(week: week)
                                }
                                .frame(height: 110)
                                .environmentObject(model)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .clipped()
                        
                        Divider()
                        
                        // Bottom Timeline (Single Day)
                        TabbedDay() { day in
                            DayView(date: day, schedules: model.Schedules.filter({
                                Date(timeIntervalSince1970: Double($0.dataRozpoczecia / 1000)).IsSameDay(date: day)
                            }))
                        }
                        .refreshable {
                            do { try await model.LoadSchedule(VerbisANSApi: VerbisANSApi) } catch { }
                        }
                        .environmentObject(model)
                    }
                }
            }
            // Fetch initial data
            .task {
                do { try await model.LoadSchedule(VerbisANSApi: VerbisANSApi) } catch { }
            }
            // Fetch data if week changes
            .onChange(of: model.SelectedWeek) { _ in
                Task {
                    do { try await model.LoadSchedule(VerbisANSApi: VerbisANSApi) } catch { }
                }
            }
            .navigationTitle(model.SelectedDay.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // MARK: - Toolbar Controls
                ToolbarItem(placement: .topBarTrailing) {
                    // A sleek iOS native drop-down menu to pick the layout
                    Menu {
                        Picker("Layout", selection: $currentLayout) {
                            Label("Daily", systemImage: "rectangle.grid.1x2")
                                .tag(CalendarLayout.daily)
                            
                            Label("Multi-Day", systemImage: "rectangle.grid.3x2")
                                .tag(CalendarLayout.multiDay)
                            
                            Label("Monthly", systemImage: "calendar")
                                .tag(CalendarLayout.monthly)
                        }
                    } label: {
                        // Icon dynamically changes based on selected layout
                        Image(systemName: layoutIcon(for: currentLayout))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                
                // Today button
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") {
                        withAnimation {
                            model.SelectDay(day: Date())
                        }
                    }
                    .opacity(Date().IsSameDay(date: model.SelectedDay) ? 0 : 1)
                }
            }
            // Animate layout changes beautifully
            .animation(.easeInOut, value: currentLayout)
        }
    }
    
    // Helper function to change the toolbar icon based on mode
    private func layoutIcon(for layout: CalendarLayout) -> String {
        switch layout {
        case .daily: return "rectangle.grid.1x2"
        case .multiDay: return "rectangle.grid.3x2"
        case .monthly: return "calendar"
        }
    }
}

#Preview {
    ScheduleView()
        .environmentObject(VerbisAPI())
}
