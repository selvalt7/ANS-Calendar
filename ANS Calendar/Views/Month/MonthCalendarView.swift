//
//  MonthCalendarView.swift
//  ANS Calendar
//
//  Created by Stanisław on 07/03/2026.
//


//
//  MonthCalendarView.swift
//  ANS Calendar
//

import SwiftUI

struct MonthCalendarView: View {
    @EnvironmentObject var model: ScheduleModel
    @State private var currentMonthOffset: Int = 0
    
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 15) {
            // MARK: - Header
            HStack {
                Text(extraDate())
                    .font(.title3.bold())
                
                Spacer()
                
                Button {
                    withAnimation { currentMonthOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(.horizontal, 10)
                }
                
                Button {
                    withAnimation { currentMonthOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding(.leading, 10)
                }
            }
            .padding(.horizontal)
            
            // MARK: - Weekdays
            HStack(spacing: 0) {
                let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // MARK: - Grid
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(extractDates()) { value in
                    CardView(value: value)
                        .onTapGesture {
                            if value.day != -1 {
                                // Uses your existing model logic!
                                model.SelectDay(day: value.date)
                            }
                        }
                }
            }
        }
        .padding()
        // Optional: Auto-jump to the month of the selected day if it changes via TabbedDay swipe
        .onChange(of: model.SelectedDay) { newDate in
            syncMonthOffset(with: newDate)
        }
    }
    
    @ViewBuilder
    func CardView(value: DateValue) -> some View {
        VStack {
            if value.day != -1 {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        // Uses your existing IsSameDay extension!
                        .scaleEffect(value.date.IsSameDay(date: model.SelectedDay) ? 1 : 0)
                        .animation(.easeOut(duration: 0.12), value: value.date.IsSameDay(date: model.SelectedDay))
                    
                    Text("\(value.day)")
                        .font(.title3)
                        .foregroundStyle(Date().IsSameDay(date: value.date) && !value.date.IsSameDay(date: model.SelectedDay) ? Color.accentColor : Color.primary)
                }
            }
        }
        .frame(height: 35, alignment: .center)
    }
    
    // MARK: - Helpers
    func extraDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM YYYY"
        return formatter.string(from: getCurrentMonth())
    }
    
    func getCurrentMonth() -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: self.currentMonthOffset, to: Date()) ?? Date()
    }
    
    func extractDates() -> [DateValue] {
        let calendar = Calendar.current
        let currentMonth = getCurrentMonth()
        
        var days = currentMonth.getAllDates().compactMap { date -> DateValue in
            let day = calendar.component(.day, from: date)
            return DateValue(day: day, date: date)
        }
        
        let firstWeekday = calendar.component(.weekday, from: days.first?.date ?? Date())
        let emptySpaces = firstWeekday == 1 ? 6 : firstWeekday - 2
        
        for _ in 0..<emptySpaces {
            days.insert(DateValue(day: -1, date: Date()), at: 0)
        }
        
        return days
    }
    
    func syncMonthOffset(with date: Date) {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        let selectedMonth = calendar.component(.month, from: date)
        let selectedYear = calendar.component(.year, from: date)
        
        let monthDiff = (selectedYear - currentYear) * 12 + (selectedMonth - currentMonth)
        if currentMonthOffset != monthDiff {
            withAnimation { currentMonthOffset = monthDiff }
        }
    }
}

// Add to your existing Date extensions if you don't have it yet:
extension Date {
    func getAllDates() -> [Date] {
        let calendar = Calendar.current
        let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: self))!
        let range = calendar.range(of: .day, in: .month, for: startDate)!
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startDate)! }
    }
}

struct DateValue: Identifiable {
    var id = UUID().uuidString
    var day: Int
    var date: Date
}