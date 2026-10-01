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
    var text = raw
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&#160;", with: " ")
        .replacingOccurrences(of: "&#322;", with: "ł")
        .replacingOccurrences(of: "&#x142;", with: "ł")
        .replacingOccurrences(of: "&#x0142;", with: "ł")
        .replacingOccurrences(of: "&lstrok;", with: "ł")
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .replacingOccurrences(of: "\u{202F}", with: " ")
        .replacingOccurrences(of: "\u{2007}", with: " ")
        .replacingOccurrences(of: "\u{2009}", with: " ")
        .replacingOccurrences(of: "\u{200A}", with: " ")
        .replacingOccurrences(of: "\u{200B}", with: "") // zero-width space
        .replacingOccurrences(of: "\u{FEFF}", with: "")
        .replacingOccurrences(of: "\u{FF1A}", with: ":") // fullwidth colon
        .replacingOccurrences(of: "\u{2236}", with: ":") // ratio colon
        .replacingOccurrences(of: ",", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\t", with: " ")
    while text.contains("  ") {
        text = text.replacingOccurrences(of: "  ", with: " ")
    }
    return text
}

/// Decode portal HTML responses that may not be UTF-8.
func decodePortalHTML(_ data: Data) -> String {
    if let utf8 = String(data: data, encoding: .utf8), utf8.contains("wiadomosc") || utf8.contains("<") {
        return utf8
    }
    if let latin1 = String(data: data, encoding: .isoLatin1) {
        return latin1
    }
    return String(decoding: data, as: UTF8.self)
}

/// Pull sender/date pairs straight from markup so DOM pairing quirks cannot drop rows.
func contentHeaderDatePairsFromHTML(_ html: String) -> [(sender: String, stamp: VerbisMessageDate)] {
    var pairs: [(sender: String, stamp: VerbisMessageDate)] = []
    let blockPattern = try? NSRegularExpression(
        pattern: #"wiadomosc-tr-content-header[\s\S]*?</tr>"#,
        options: [.caseInsensitive]
    )
    let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
    let blocks = blockPattern?.matches(in: html, options: [], range: fullRange) ?? []
    for block in blocks {
        guard let chunkRange = Range(block.range, in: html) else { continue }
        let chunk = String(html[chunkRange])
        let sender = firstDivBody(in: chunk, className: "fltlft") ?? ""
        let stampText = firstDivBody(in: chunk, className: "fltrt") ?? chunk
        if let stamp = parseVerbisMessageDateValue(stampText) {
            pairs.append((sender: normalizeMessageSenderText(sender), stamp: stamp))
        }
    }

    // Fallback: any fltrt stamp, even outside a matched content-header block.
    if pairs.isEmpty {
        let fltrtPattern = try? NSRegularExpression(
            pattern: #"class=["'][^"']*\bfltrt\b[^"']*["'][^>]*>([\s\S]*?)</div>"#,
            options: [.caseInsensitive]
        )
        for match in fltrtPattern?.matches(in: html, options: [], range: fullRange) ?? [] {
            guard let bodyRange = Range(match.range(at: 1), in: html) else { continue }
            if let stamp = parseVerbisMessageDateValue(String(html[bodyRange])) {
                pairs.append((sender: "", stamp: stamp))
            }
        }
    }
    return pairs
}

func normalizeMessageSenderText(_ raw: String) -> String {
    normalizeVerbisMessageDateText(raw)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
        .lowercased()
}

private func firstDivBody(in html: String, className: String) -> String? {
    let pattern = try? NSRegularExpression(
        pattern: "class=[\"'][^\"']*\\b\(NSRegularExpression.escapedPattern(for: className))\\b[^\"']*[\"'][^>]*>([\\s\\S]*?)</div>",
        options: [.caseInsensitive]
    )
    guard let pattern else { return nil }
    let range = NSRange(html.startIndex..<html.endIndex, in: html)
    guard let match = pattern.firstMatch(in: html, options: [], range: range),
          let bodyRange = Range(match.range(at: 1), in: html)
    else { return nil }
    return String(html[bodyRange])
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

    // Match starts at digits, so Polish weekdays (including "poniedziałek") are ignored.
    if let match = text.firstMatch(of: /(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2})/),
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
    var best: VerbisMessageDate?

    func consider(_ raw: String) {
        guard let parsed = parseVerbisMessageDateValue(raw) else { return }
        if let current = best {
            if parsed.includesTime && !current.includesTime {
                best = parsed
            }
        } else {
            best = parsed
        }
    }

    // Portal stamps live in `.fltrt` — read that before combining with the sender name.
    for floated in try element.select(".fltrt").array() {
        consider(try floated.text())
        consider(floated.ownText())
        for attr in ["title", "data-original-title", "aria-label"] {
            consider(try floated.attr(attr))
        }
    }

    // Legacy portal markup used the second div in the content-header.
    let divs = try element.select("div").array()
    if divs.count > 1 {
        consider(try divs[1].text())
        consider(divs[1].ownText())
    }

    for attr in ["title", "data-original-title", "aria-label"] {
        consider(try element.attr(attr))
        for child in try element.select("[\(attr)]").array() {
            consider(try child.attr(attr))
        }
    }

    consider(try element.text())
    return best
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
