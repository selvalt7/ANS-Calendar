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

    @Test func profilePageParsesPersonalData() throws {
        let html = """
        <div id="moj-profil-container">
          <div class="person-data">
            <div class="photo"><img alt="Twoja fotografia" src="/ppuz-stud-app/ledge/view/stud.info.ZdjecieMojeView"></div>
            <div class="vdo-title big">Jan Kowalski</div>
          </div>
          <div class="person-info data">
            <div>Imię ojca:</div><div class="large"></div>
            <div>Data urodzenia:</div><div>01.01.2000</div>
            <div>Miejsce urodzenia:</div><div class="large">Kraków</div>
            <div>Płeć:</div><div class="large">Mężczyzna</div>
            <div>PESEL:</div><div>00010112345</div>
            <div>Adres e-mail uczelniany:</div><div>10000@example.edu</div>
          </div>
          <div class="jednostka-info data">
            <div>Login:</div><div>10000</div>
            <div>Grupa dziekańska:</div><div>IE1.1</div>
            <div>Uczelnia:</div><div>Akademia Nauk Stosowanych</div>
          </div>
          <div class="addresses data">
            <div>Adres zamieszkania:</div>
            <div class="large"><p>Testowa 1, Kraków<br>30-001</p><p>Polska</p></div>
            <div>Adres tymczasowy:</div>
            <div class="large">Brak danych</div>
          </div>
        </div>
        """
        let profile = try parseStudentProfile(html: html)
        #expect(profile.name == "Jan Kowalski")
        #expect(profile.photoPath == "/ppuz-stud-app/ledge/view/stud.info.ZdjecieMojeView")
        #expect(absolutePortalURL(from: profile.photoPath ?? "")?.absoluteString == "https://wu.ans-nt.edu.pl/ppuz-stud-app/ledge/view/stud.info.ZdjecieMojeView")
        #expect(profile.personal.contains(ProfileField(label: "Date of birth", value: "01.01.2000")))
        #expect(profile.personal.contains(ProfileField(label: "Place of birth", value: "Kraków")))
        #expect(profile.personal.contains(ProfileField(label: "Gender", value: "Male")))
        #expect(!profile.personal.contains { $0.label == "Father's name" })
        #expect(profile.studies.contains(ProfileField(label: "Login", value: "10000")))
        #expect(profile.studies.contains(ProfileField(label: "Dean's group", value: "IE1.1")))
        #expect(profile.addresses.contains(ProfileField(label: "Home address", value: "Testowa 1, Kraków\n30-001\nPolska")))
        #expect(profile.addresses.contains(ProfileField(label: "Temporary address", value: "No data")))
    }

    @Test func messageDateIgnoresPolishWeekday() {
        let parsed = parseVerbisMessageDate("wtorek 30.06.2026 13:04")
        let calendar = Calendar.ans
        #expect(parsed != nil)
        #expect(calendar.component(.day, from: parsed!) == 30)
        #expect(calendar.component(.month, from: parsed!) == 6)
        #expect(calendar.component(.year, from: parsed!) == 2026)
        #expect(calendar.component(.hour, from: parsed!) == 13)
        #expect(calendar.component(.minute, from: parsed!) == 4)
        #expect(verbisMessageDateText(parsed!) == "30.06.2026 13:04")
        #expect(parseVerbisMessageDate("mgr Katarzyna Wysocka") == nil)
        #expect(parseVerbisMessageDate("30.06.2026 13:04") == parsed)
    }

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
