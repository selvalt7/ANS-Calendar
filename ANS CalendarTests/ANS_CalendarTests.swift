//
//  ANS_CalendarTests.swift
//  ANS CalendarTests
//
//  Created by Stanisław on 15/11/2024.
//

import Testing
import Foundation
@testable import ANS_Calendar

struct ANS_CalendarTests {
    private let calendar = Calendar.ans

    @Test func distancesCountCalendarDays() {
        let october = date(year: 2026, month: 10, day: 1)
        let january = date(year: 2026, month: 1, day: 31)
        #expect(october.monthDistance(to: january) == 9)
        #expect(january.dayDistance(to: date(year: 2026, month: 2, day: 1)) == 1)
        #expect(date(year: 2026, month: 10, day: 24).dayDistance(to: date(year: 2026, month: 10, day: 26)) == 2)
    }

    @Test func weekStartsOnMonday() {
        let thursday = date(year: 2026, month: 10, day: 1)
        let start = thursday.startOfWeek()
        #expect(calendar.component(.weekday, from: start) == 2)
        #expect(calendar.component(.day, from: start) == 28)
        #expect(calendar.component(.month, from: start) == 9)
        #expect(thursday.IsSameWeek(date: start))
    }

    @Test func monthNavigationDoesNotOverflowPastShortMonths() {
        let january31 = date(year: 2026, month: 1, day: 31)
        let february = january31.startOfMonth.addingMonths(1)
        #expect(calendar.component(.month, from: february) == 2)
        #expect(calendar.component(.day, from: february) == 1)
    }

    @Test func october2026GridIsMondayAligned() {
        let october = date(year: 2026, month: 10, day: 1)
        let grid = october.monthGridDates()
        #expect(grid.count == 42)
        #expect(calendar.component(.weekday, from: grid[0]) == 2)
        #expect(calendar.component(.day, from: grid[3]) == 1)
        #expect(calendar.component(.month, from: grid[3]) == 10)
        #expect(Set(grid).count == grid.count)

        let weeks = october.weekStartsCoveringMonth()
        #expect(weeks.count == 6)
        #expect(weeks.allSatisfy { calendar.component(.weekday, from: $0) == 2 })
    }

    @Test func weekAcrossDaylightSavingHasSevenDistinctDays() {
        let days = date(year: 2026, month: 10, day: 25).daysOfWeek()
        #expect(days.count == 7)
        #expect(Set(days).count == 7)
        #expect(calendar.component(.day, from: days[0]) == 19)
        #expect(calendar.component(.day, from: days[6]) == 25)
    }

    @Test func chunkedArrayNeverDividesByZero() {
        #expect([1, 2, 3, 4, 5, 6, 7].chunked(into: 3).map { $0 } == [[1, 2, 3], [4, 5, 6], [7]])
        #expect([Int]().chunked(into: 0).isEmpty)
        #expect([1, 2].chunked(into: 0) == [[1, 2]])
    }

    @Test func overlappingLessonsShareColumns() {
        let morning = lesson(startHour: 9, endHour: 10, endMinute: 30, title: "Math")
        let overlapping = lesson(startHour: 10, endHour: 11, title: "Physics")
        let later = lesson(startHour: 12, endHour: 13, title: "History")

        let placements = timelinePlacements(for: [overlapping, morning, later])
        #expect(placements.count == 3)

        let firstCluster = placements.filter { $0.schedule.nazwaPelnaPrzedmiotu != "History" }
        #expect(firstCluster.allSatisfy { $0.columnCount == 2 })
        #expect(Set(firstCluster.map(\.column)) == [0, 1])

        let history = placements.first { $0.schedule.nazwaPelnaPrzedmiotu == "History" }
        #expect(history?.column == 0)
        #expect(history?.columnCount == 1)
    }

    @Test func backToBackLessonsDoNotOverlap() {
        let first = lesson(startHour: 9, endHour: 10, title: "Math")
        let second = lesson(startHour: 10, endHour: 11, title: "Physics")
        let placements = timelinePlacements(for: [first, second])
        #expect(placements.allSatisfy { $0.columnCount == 1 })
    }

    @Test func missingScheduleFieldsDoNotRequireIndexes() {
        let schedule = lesson(startHour: 9, endHour: 10, title: "Exam")
        #expect(schedule.groupLabel.isEmpty)
        #expect(schedule.roomLabel == "No room")
        #expect(schedule.lecturerLabel == "No lecturer")
        #expect(!schedule.isExam)
        #expect(schedule.occurs(on: date(year: 2026, month: 10, day: 1)))
    }

    @Test func scheduleDecodesNullCollections() throws {
        let json = """
        {"dataRozpoczecia":1731657600000,"dataZakonczenia":1731670000000,"nazwaPelnaPrzedmiotu":"Math","grupyZajeciowe":null,"grupySprawdzianu":null,"listaIdZajecInstancji":null,"sale":null,"wykladowcy":null}
        """
        let decoded = try JSONDecoder().decode(ScheduleInfo.self, from: Data(json.utf8))
        #expect(decoded.nazwaPelnaPrzedmiotu == "Math")
        #expect(decoded.grupyZajeciowe.isEmpty)
        #expect(decoded.sale.isEmpty)
        #expect(decoded.wykladowcy.isEmpty)
        #expect(decoded.roomLabel == "No room")
    }

    @Test func scheduleResponseWithoutIdentifierStillDecodes() throws {
        let json = """
        {"exceptionClass":null,"returnedValue":{"items":[]}}
        """
        let decoded = try JSONDecoder().decode(AJAXReturn.self, from: Data(json.utf8))
        #expect(decoded.returnedValue?.items.isEmpty == true)
        #expect(decoded.exceptionClass == nil)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func lesson(startHour: Int, startMinute: Int = 0, endHour: Int, endMinute: Int = 0, title: String) -> ScheduleInfo {
        let day = date(year: 2026, month: 10, day: 1)
        func timestamp(hour: Int, minute: Int) -> Int {
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            return Int(calendar.date(from: components)!.timeIntervalSince1970 * 1000)
        }
        return ScheduleInfo(
            dataRozpoczecia: timestamp(hour: startHour, minute: startMinute),
            dataZakonczenia: timestamp(hour: endHour, minute: endMinute),
            nazwaPelnaPrzedmiotu: title,
            grupyZajeciowe: [],
            grupySprawdzianu: [],
            listaIdZajecInstancji: [],
            sale: [],
            wykladowcy: []
        )
    }
}
