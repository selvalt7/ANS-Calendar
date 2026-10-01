//
//  Date.swift
//  ANS Calendar
//
//  Created by Stanisław on 19/11/2024.
//

import Foundation
import SwiftSoup

extension Calendar {
    /// University schedule calendar. Weeks start on Monday and class times stay in Poland
    /// even if the phone is set to another region.
    static let ans: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pl_PL")
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        return calendar
    }()

    /// Short weekday names ordered from Monday, in the phone's language.
    static var mondayFirstWeekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = ans
        formatter.dateFormat = "EE"
        let monday = Date().startOfWeek()
        let symbols = (0..<7).map { formatter.string(from: monday.addingDays($0)) }
        if symbols.count == 7 { return symbols }
        return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }
}

extension Date {
    func GetDateComponentFromUnix(Unix: Int, Component: Calendar.Component) -> Int {
        let date = Date(timeIntervalSince1970: Double(Unix) / 1000)
        return Calendar.ans.component(Component, from: date)
    }

    func GetDateComponent(Date: Date, Component: Calendar.Component) -> Int {
        Calendar.ans.component(Component, from: Date)
    }

    func startOfWeek(using calendar: Calendar = .ans) -> Date {
        calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date
            ?? calendar.startOfDay(for: self)
    }

    var startOfDay: Date {
        Calendar.ans.startOfDay(for: self)
    }

    var startOfMonth: Date {
        let calendar = Calendar.ans
        return calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? startOfDay
    }

    func addingDays(_ days: Int) -> Date {
        Calendar.ans.date(byAdding: .day, value: days, to: self) ?? self
    }

    func addingMonths(_ months: Int) -> Date {
        Calendar.ans.date(byAdding: .month, value: months, to: self) ?? self
    }

    func daysOfWeek() -> [Date] {
        let start = startOfWeek()
        var days: [Date] = []
        for offset in 0..<7 {
            let day = start.addingDays(offset).startOfDay
            if days.last != day {
                days.append(day)
            }
        }
        return days
    }

    /// Six Monday-first weeks covering this month, including leading and trailing days.
    func monthGridDates() -> [Date] {
        let gridStart = startOfMonth.startOfWeek()
        var days: [Date] = []
        for offset in 0..<42 {
            let day = gridStart.addingDays(offset).startOfDay
            if days.last != day {
                days.append(day)
            }
        }
        return days
    }

    func weekStartsCoveringMonth() -> [Date] {
        var starts: [Date] = []
        for day in monthGridDates() {
            let start = day.startOfWeek()
            if !starts.contains(start) {
                starts.append(start)
            }
        }
        return starts
    }

    func GetShortDayName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = Calendar.ans
        formatter.dateFormat = "EE"
        return formatter.string(from: self)
    }

    func IsSameDay(date: Date) -> Bool {
        Calendar.ans.isDate(self, equalTo: date, toGranularity: .day)
    }

    func IsSameWeek(date: Date) -> Bool {
        Calendar.ans.isDate(self, equalTo: date, toGranularity: .weekOfYear)
    }

    func IsSameMonth(date: Date) -> Bool {
        Calendar.ans.isDate(self, equalTo: date, toGranularity: .month)
    }

    func dayDistance(to other: Date) -> Int {
        abs(Calendar.ans.dateComponents([.day], from: startOfDay, to: other.startOfDay).day ?? 0)
    }

    func monthDistance(to other: Date) -> Int {
        let calendar = Calendar.ans
        let start = calendar.dateComponents([.year, .month], from: self)
        let end = calendar.dateComponents([.year, .month], from: other)
        return abs(((end.year ?? 0) - (start.year ?? 0)) * 12 + ((end.month ?? 0) - (start.month ?? 0)))
    }

    var isWeekend: Bool {
        let weekday = Calendar.ans.component(.weekday, from: self)
        return weekday == 1 || weekday == 7
    }

    var Yesterday: Date { addingDays(-1) }
    var Tomorrow: Date { addingDays(1) }

    var Hour: Int { Calendar.ans.component(.hour, from: self) }
    var Minute: Int { Calendar.ans.component(.minute, from: self) }

    var minutesFromMidnight: Int { Hour * 60 + Minute }
}

struct VerbisMessageDate: Equatable {
    let date: Date
    let includesTime: Bool
}

func normalizeVerbisMessageDateText(_ raw: String) -> String {
    raw
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .replacingOccurrences(of: "\u{202F}", with: " ")
        .replacingOccurrences(of: ",", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
}

func verbisMessageTextHasClockTime(_ raw: String) -> Bool {
    normalizeVerbisMessageDateText(raw).contains(/\d{1,2}:\d{2}/)
}

/// Portal messages look like "wtorek 30.06.2026 13:04". The weekday is Polish and is ignored.
/// Also accepts date-only values and separators such as commas or newlines.
func parseVerbisMessageDate(_ raw: String) -> Date? {
    parseVerbisMessageDateValue(raw)?.date
}

func parseVerbisMessageDateValue(_ raw: String) -> VerbisMessageDate? {
    let text = normalizeVerbisMessageDateText(raw)

    let day: Int
    let month: Int
    let year: Int
    let hour: Int
    let minute: Int
    let includesTime: Bool

    if let match = text.firstMatch(of: /(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2})(?::\d{2})?/),
       let parsedDay = Int(match.1),
       let parsedMonth = Int(match.2),
       let parsedYear = Int(match.3),
       let parsedHour = Int(match.4),
       let parsedMinute = Int(match.5),
       (1...31).contains(parsedDay),
       (1...12).contains(parsedMonth),
       (0...23).contains(parsedHour),
       (0...59).contains(parsedMinute) {
        day = parsedDay
        month = parsedMonth
        year = parsedYear
        hour = parsedHour
        minute = parsedMinute
        includesTime = true
    } else if let match = text.firstMatch(of: /(\d{1,2})\.(\d{1,2})\.(\d{4})/),
              let parsedDay = Int(match.1),
              let parsedMonth = Int(match.2),
              let parsedYear = Int(match.3),
              (1...31).contains(parsedDay),
              (1...12).contains(parsedMonth) {
        day = parsedDay
        month = parsedMonth
        year = parsedYear
        hour = 0
        minute = 0
        includesTime = false
    } else {
        return nil
    }

    var components = DateComponents()
    components.calendar = .ans
    components.timeZone = Calendar.ans.timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    guard let date = Calendar.ans.date(from: components) else { return nil }
    return VerbisMessageDate(date: date, includesTime: includesTime)
}

/// Prefer the full element text so date and time split across child nodes still combine.
/// Timed `.fltrt` values win over date-only fragments.
func verbisMessageDate(in element: Element) throws -> Date? {
    try verbisMessageDateValue(in: element)?.date
}

func verbisMessageDateValue(in element: Element) throws -> VerbisMessageDate? {
    let fullText = try element.text()
    if let timed = parseVerbisMessageDateValue(fullText), timed.includesTime {
        return timed
    }

    for floated in try element.select(".fltrt").array() {
        let text = try floated.text()
        if let timed = parseVerbisMessageDateValue(text), timed.includesTime {
            return timed
        }
    }

    if let timed = parseVerbisMessageDateValue(fullText), timed.includesTime {
        return timed
    }

    return parseVerbisMessageDateValue(fullText)
}

func verbisMessageDateText(_ date: Date, includeTime: Bool = true) -> String {
    let calendar = Calendar.ans
    if includeTime {
        return String(
            format: "%02d.%02d.%04d %02d:%02d",
            calendar.component(.day, from: date),
            calendar.component(.month, from: date),
            calendar.component(.year, from: date),
            calendar.component(.hour, from: date),
            calendar.component(.minute, from: date)
        )
    }
    return String(
        format: "%02d.%02d.%04d",
        calendar.component(.day, from: date),
        calendar.component(.month, from: date),
        calendar.component(.year, from: date)
    )
}
