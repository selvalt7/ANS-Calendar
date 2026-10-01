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
        #expect(profile.personal.contains(ProfileField(label: "Date of birth", value: "01.01.2000", isSensitive: true)))
        #expect(profile.personal.contains(ProfileField(label: "Place of birth", value: "Kraków", isSensitive: true)))
        #expect(profile.personal.contains(ProfileField(label: "PESEL", value: "00010112345", isSensitive: true)))
        #expect(profile.personal.contains(ProfileField(label: "Gender", value: "Male")))
        #expect(profile.personal.contains(ProfileField(label: "University email", value: "10000@example.edu")))
        #expect(!profile.personal.contains { $0.label == "Father's name" })
        #expect(profile.studies.contains(ProfileField(label: "Login", value: "10000")))
        #expect(profile.studies.contains(ProfileField(label: "Dean's group", value: "IE1.1")))
        #expect(profile.addresses.contains(ProfileField(label: "Home address", value: "Testowa 1, Kraków\n30-001\nPolska", isSensitive: true)))
        #expect(profile.addresses.contains(ProfileField(label: "Temporary address", value: "No data", isSensitive: true)))
        #expect(profile.hasSensitiveFields)
    }

    @Test func progressPageParsesSemesterGrades() throws {
        let html = """
        <div id="progress-table">
        <table class="vdbo-table">
        <tbody>
        <tr id="10">
          <td headers="th-semestr"><span class="hidden-link">2024 Z</span></td>
          <td headers="th-semestr-studiow"><a name="item1">1</a></td>
          <td headers="th-tok-studiow">2024 Z</td>
          <td headers="th-etap-studiow">Inż.</td>
          <td headers="th-status">Rekrutacja<br></td>
          <td headers="th-ects-semestralnie"><span class="inactive">30</span> / 30 / <span class="warn">0</span></td>
          <td headers="th-ects-skumulowane"><span class="inactive">30</span> / 30 / <span class="warn">0</span></td>
          <td headers="th-godziny-semestralnie"><span class="inactive">60</span> / 60 / <span class="warn">0</span></td>
          <td headers="th-jk">6 / <span class="warn">0</span></td>
          <td headers="th-srednia-semestralna">4,50        </td>
          <td headers="th-srednia-roczna">--</td>
          <td headers="th-srednia-skumulowana">4,50</td>
          <td headers="th-grupa-dziekanska" title="Informatyka testowa IT1.1">IT1.1</td>
          <td headers="th-opiekun">&nbsp;</td>
        </tr>
        <tr id="tr-progress-details10">
          <td colspan="14">
            <div id="progress-details10">
              <table class="credits">
                <tbody>
                  <tr id="instancja100">
                    <td headers="th10-lp">1.</td>
                    <td headers="th10-nr-katalogowy">IE.TEST.1</td>
                    <td headers="th10-wersja">
                      <div id="version100" class="overflow-elipsis">A - A. Nowak</div>
                      <div class="dijitTooltipData" connectid="version100"><span>A - dr Anna Nowak</span></div>
                    </td>
                    <td headers="th10-nazwa-przedmiotu">
                      <table class="borderless"><tr><td class="left">Algorytmy</td></tr></table>
                    </td>
                    <td headers="th10-ocena" id="grade100">
                      <span class="">            5,0
                      </span>
                      <div class="dijitTooltipData" connectid="grade100">
                        <table class="student-grades">
                          <tr><td>Ocena końcowa:</td><td>5,0 (03.02.2025)</td></tr>
                          <tr><td colspan="2"><strong>Terminy</strong></td></tr>
                          <tr><td>Podstawowy:</td><td>5,0 (03.02.2025)</td></tr>
                        </table>
                      </div>
                    </td>
                    <td headers="th10-ects"><span class="">4</span></td>
                    <td headers="th10-godziny" id="hours100">
                      <span class="">60</span>
                      <div class="dijitTooltipData" connectid="hours100">
                        <span>W: 30</span><span></span><span>CL: 30</span>
                      </div>
                    </td>
                    <td headers="th10-jk"><span class="">4</span></td>
                    <td headers="th10-grupy">
                      <span id="100_1">W1,</span>
                      <div class="dijitTooltipData" connectid="100_1">
                        <div>dr Anna Nowak</div>
                        <div>mgr Jan Test</div>
                      </div>
                      <span id="100_2">CL1</span>
                      <div class="dijitTooltipData" connectid="100_2">
                        <span>Brak wykładowców przypisanych do tej grupy</span>
                      </div>
                    </td>
                    <td headers="th10-typ-zaliczenia"><span title="Egzamin">E</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </td>
        </tr>
        <tr class="invisible"></tr>
        <tr id="11">
          <td headers="th-semestr"><span>2025 L</span></td>
          <td headers="th-semestr-studiow">2</td>
          <td headers="th-tok-studiow">2024 Z</td>
          <td headers="th-etap-studiow">Inż.</td>
          <td headers="th-status">Rejestracja ręczna</td>
          <td headers="th-ects-semestralnie"><span class="inactive">10</span> / 4 / <span class="warn">2</span></td>
          <td headers="th-ects-skumulowane"><span class="inactive">40</span> / 34 / <span class="warn">2</span></td>
          <td headers="th-godziny-semestralnie"><span class="inactive">120</span> / 40 / <span class="warn">0</span></td>
          <td headers="th-jk">4 / <span class="warn">0</span></td>
          <td headers="th-srednia-semestralna">0,00</td>
          <td headers="th-srednia-roczna">4,25</td>
          <td headers="th-srednia-skumulowana">4,40</td>
          <td headers="th-grupa-dziekanska" title="IT2.1">IT2.1</td>
          <td headers="th-opiekun"></td>
        </tr>
        <tr id="tr-progress-details11">
          <td>
            <table class="credits">
              <tr id="instancja200">
                <td headers="th11-nr-katalogowy">IE.TEST.2</td>
                <td headers="th11-wersja"><div id="version200" class="overflow-elipsis">A - Brak Danych</div></td>
                <td headers="th11-nazwa-przedmiotu"><table><tr><td>Praktyka</td></tr></table></td>
                <td headers="th11-ocena">
                  <span class="inactive">---</span>
                  <div class="dijitTooltipData">
                    <table class="student-grades">
                      <tr><td colspan="2">Ocena w dziekanacie</td></tr>
                      <tr><td>Ocena końcowa:</td><td>---</td></tr>
                    </table>
                  </div>
                </td>
                <td headers="th11-ects"><span class="inactive">6</span></td>
                <td headers="th11-godziny"><span class="inactive">120</span></td>
                <td headers="th11-jk"><span class="inactive">6</span></td>
                <td headers="th11-grupy"><span id="200_1">PZ1</span></td>
                <td headers="th11-typ-zaliczenia"></td>
              </tr>
            </table>
          </td>
        </tr>
        </tbody>
        </table>
        </div>
        """

        let progress = try parseAcademicProgress(html: html)
        #expect(progress.semesters.count == 2)
        #expect(progress.latest?.termTitle == "Summer 2025")
        #expect(progress.newestFirst.first?.term == "2025 L")

        let winter = progress.semesters[0]
        #expect(winter.termTitle == "Winter 2024")
        #expect(winter.studySemester == "1")
        #expect(winter.trackTitle == "Winter 2024")
        #expect(winter.stage == "Engineer")
        #expect(winter.status == "Recruitment")
        #expect(winter.ects.passedOfEnrolled == "30 of 30")
        #expect(winter.hours.passedOfEnrolled == "60 of 60")
        #expect(winter.costUnits.display == "6 / 0")
        #expect(winter.semesterAverage == "4,50")
        #expect(winter.yearlyAverage == nil)
        #expect(winter.cumulativeAverage == "4,50")
        #expect(winter.deanGroup == "IT1.1")
        #expect(winter.program == "Informatyka testowa IT1.1")
        #expect(winter.advisor == nil)
        #expect(winter.courses.count == 1)

        let course = winter.courses[0]
        #expect(course.name == "Algorytmy")
        #expect(course.catalogNumber == "IE.TEST.1")
        #expect(course.grade == "5,0")
        #expect(!course.grade.contains("Ocena"))
        #expect(!course.isPending)
        #expect(course.isExam)
        #expect(course.coordinator == "A - dr Anna Nowak")
        #expect(course.ects == "4")
        #expect(!course.ectsPending)
        #expect(course.attempts.count == 2)
        #expect(course.attempts[0].label == "Final grade")
        #expect(course.attempts[0].grade == "5,0")
        #expect(course.attempts[0].date == "03.02.2025")
        #expect(course.attempts[0].context == nil)
        #expect(course.attempts[1].label == "First sitting")
        #expect(course.hourBreakdown.map(\.title) == ["Lecture", "Lab"])
        #expect(course.hourBreakdown.map(\.hours) == ["30", "30"])
        #expect(course.groups.count == 2)
        #expect(course.groups[0].code == "W1")
        #expect(course.groups[0].lecturers == ["dr Anna Nowak", "mgr Jan Test"])
        #expect(course.groups[1].code == "CL1")
        #expect(course.groups[1].lecturers.isEmpty)

        let summer = progress.semesters[1]
        #expect(summer.termTitle == "Summer 2025")
        #expect(summer.status == "Manual registration")
        #expect(summer.ects.passedOfEnrolled == "4 of 10, 2 failed")
        #expect(summer.cumulativeECTS.passedOfEnrolled == "34 of 40, 2 failed")
        #expect(summer.semesterAverage == "0,00")
        #expect(summer.yearlyAverage == "4,25")
        #expect(summer.cumulativeAverage == "4,40")
        #expect(summer.program == nil)
        #expect(summer.trackTitle == "Winter 2024")
        #expect(summer.courses.count == 1)

        let pending = summer.courses[0]
        #expect(pending.name == "Praktyka")
        #expect(pending.grade == "---")
        #expect(pending.displayGrade == "—")
        #expect(pending.isPending)
        #expect(!pending.isExam)
        #expect(pending.attempts.isEmpty)
        #expect(pending.coordinator == "A - No data")
        #expect(pending.ectsPending)
        #expect(pending.ects == "6")
        #expect(pending.groups == [CourseGroup(code: "PZ1", lecturers: [])])

        let empty = try parseAcademicProgress(html: "<div id=\"progress-table\"></div>")
        #expect(empty.semesters.isEmpty)
    }

    @Test func messageDateIgnoresPolishWeekday() {
        let parsed = parseVerbisMessageDateValue("wtorek 30.06.2026 13:04")
        let calendar = Calendar.ans
        #expect(parsed != nil)
        #expect(parsed?.includesTime == true)
        #expect(calendar.component(.day, from: parsed!.date) == 30)
        #expect(calendar.component(.month, from: parsed!.date) == 6)
        #expect(calendar.component(.year, from: parsed!.date) == 2026)
        #expect(calendar.component(.hour, from: parsed!.date) == 13)
        #expect(calendar.component(.minute, from: parsed!.date) == 4)
        #expect(verbisMessageDateText(parsed!.date) == "30.06.2026 13:04")
        #expect(parseVerbisMessageDate("mgr Katarzyna Wysocka") == nil)
        #expect(parseVerbisMessageDate("30.06.2026 13:04") == parsed?.date)
        #expect(parseVerbisMessageDate("30.06.2026, 13:04") == parsed?.date)
        #expect(parseVerbisMessageDate("30.06.2026 13:04:59") == parsed?.date)

        let dateOnly = parseVerbisMessageDateValue("30.06.2026")
        #expect(dateOnly != nil)
        #expect(dateOnly?.includesTime == false)
        #expect(calendar.component(.day, from: dateOnly!.date) == 30)
        #expect(verbisMessageDateText(dateOnly!.date, includeTime: false) == "30.06.2026")
    }

    @Test func messageListReadsDatesFromHiddenContentHeaders() throws {
        let html = """
        <table>
          <tr class="wiadomosc-tr-header wiadomosci-nowe" data-vdo-dane-wiersza='{"typWiersza":"W","idWatku":11,"idSkrzynkiUczestnika":21,"idWszystkichWiadomosci":[31]}'>
            <td></td>
            <td>
              <div class="wiadomosc-nadawca">mgr Katarzyna Wysocka</div>
              <div class="wiadomosc-zawartosc-glowna">Important notice</div>
              <div class="wiadomosc-zawartosc-szczegoly">Please read on 01.01.2020</div>
            </td>
            <td></td>
          </tr>
          <tr class="wiadomosc-tr-content-header" style="display: none;">
            <td colspan="3">
              <div class="fltlft" style="font-weight: bold;">mgr Katarzyna Wysocka</div>
              <div class="fltrt" style="font-weight: bold;">wtorek 30.06.2026 13:04</div>
            </td>
          </tr>
          <tr class="wiadomosc-tr-header" data-vdo-dane-wiersza='{"typWiersza":"W","idWatku":12,"idSkrzynkiUczestnika":22,"idWszystkichWiadomosci":[32]}'>
            <td></td>
            <td>
              <div class="wiadomosc-nadawca">Jan Kowalski</div>
              <div class="wiadomosc-zawartosc-glowna">Older notice</div>
              <div class="wiadomosc-zawartosc-szczegoly">Details</div>
            </td>
            <td>01.05.2026 09:15</td>
          </tr>
          <tr class="wiadomosc-tr-content-header" style="display: none;">
            <td colspan="3">
              <div class="fltlft">Jan Kowalski</div>
              <div class="fltrt">piątek 01.05.2026 09:15</div>
            </td>
          </tr>
        </table>
        """

        let messages = try parseMessageList(html: html)
        #expect(messages.count == 2)

        #expect(messages[0].Sender == "mgr Katarzyna Wysocka")
        #expect(messages[0].Title == "Important notice")
        #expect(messages[0].Unread)
        #expect(messages[0].Date != nil)
        #expect(messages[0].DateHasTime)
        #expect(verbisMessageDateText(messages[0].Date!) == "30.06.2026 13:04")

        #expect(messages[1].Sender == "Jan Kowalski")
        #expect(messages[1].Date != nil)
        #expect(messages[1].DateHasTime)
        #expect(verbisMessageDateText(messages[1].Date!) == "01.05.2026 09:15")
        #expect(messages[0].Date != messages[1].Date)
    }

    @Test func messageListReadsDatesAcrossSeparateTbodyWrappers() throws {
        let html = """
        <table>
          <tbody>
            <tr class="wiadomosc-tr-header" data-vdo-dane-wiersza='{"typWiersza":"W","idWatku":11,"idSkrzynkiUczestnika":21,"idWszystkichWiadomosci":[31]}'>
              <td>
                <div class="wiadomosc-nadawca">mgr Katarzyna Wysocka</div>
                <div class="wiadomosc-zawartosc-glowna">Important notice</div>
                <div class="wiadomosc-zawartosc-szczegoly">Please read</div>
              </td>
              <td><div>30.06.2026</div><div>13:04</div></td>
            </tr>
          </tbody>
          <tbody>
            <tr class="wiadomosc-tr-content-header" style="display: none;">
              <td colspan="3">
                <div class="fltlft">mgr Katarzyna Wysocka</div>
                <div class="fltrt">wtorek 30.06.2026 13:04</div>
              </td>
            </tr>
          </tbody>
          <tbody>
            <tr class="wiadomosc-tr-header" data-vdo-dane-wiersza='{"typWiersza":"W","idWatku":12,"idSkrzynkiUczestnika":22,"idWszystkichWiadomosci":[32]}'>
              <td>
                <div class="wiadomosc-nadawca">Jan Kowalski</div>
                <div class="wiadomosc-zawartosc-glowna">Older notice</div>
                <div class="wiadomosc-zawartosc-szczegoly">Meeting on 15.03.2025 in room 1</div>
              </td>
              <td>01.05.2026</td>
            </tr>
          </tbody>
          <tbody>
            <tr class="wiadomosc-tr-content-header" style="display: none;">
              <td colspan="3">
                <div class="fltlft">Jan Kowalski</div>
                <div class="fltrt">piątek 01.05.2026 09:15</div>
              </td>
            </tr>
          </tbody>
        </table>
        """

        let messages = try parseMessageList(html: html)
        #expect(messages.count == 2)
        #expect(messages[0].DateHasTime)
        #expect(verbisMessageDateText(messages[0].Date!) == "30.06.2026 13:04")
        #expect(messages[1].DateHasTime)
        #expect(verbisMessageDateText(messages[1].Date!) == "01.05.2026 09:15")
    }

    @Test func messageListIgnoresPreviewDatesAndKeepsDateOnlyWithoutMidnight() throws {
        let html = """
        <table>
          <tr class="wiadomosc-tr-header" data-vdo-dane-wiersza='{"typWiersza":"W","idWatku":99,"idSkrzynkiUczestnika":1,"idWszystkichWiadomosci":[1]}'>
            <td>
              <div class="wiadomosc-nadawca">No Header Sender</div>
              <div class="wiadomosc-zawartosc-glowna">Subject</div>
              <div class="wiadomosc-zawartosc-szczegoly">Body mentions 15.03.2025 only</div>
            </td>
            <td>15.03.2025</td>
          </tr>
        </table>
        """
        let messages = try parseMessageList(html: html)
        #expect(messages.count == 1)
        #expect(messages[0].Date != nil)
        #expect(!messages[0].DateHasTime)
        #expect(verbisMessageDateText(messages[0].Date!, includeTime: messages[0].DateHasTime) == "15.03.2025")
    }

    @Test func messageListDoesNotInventCurrentDateWhenMissing() throws {
        let html = """
        <table>
          <tr class="wiadomosc-tr-header" data-vdo-dane-wiersza='{"typWiersza":"W","idWatku":99,"idSkrzynkiUczestnika":1,"idWszystkichWiadomosci":[1]}'>
            <td>
              <div class="wiadomosc-nadawca">No Date Sender</div>
              <div class="wiadomosc-zawartosc-glowna">Subject</div>
              <div class="wiadomosc-zawartosc-szczegoly">Body</div>
            </td>
          </tr>
        </table>
        """
        let messages = try parseMessageList(html: html)
        #expect(messages.count == 1)
        #expect(messages[0].Date == nil)
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

    @Test func confirmPasswordRejectsAMismatch() {
        #expect(!passwordConfirmationMismatch(newPassword: "Secret1a", confirmation: ""))
        #expect(!passwordConfirmationMismatch(newPassword: "Secret1a", confirmation: "Secret1a"))
        #expect(passwordConfirmationMismatch(newPassword: "Secret1a", confirmation: "Secret1b"))
        #expect(passwordConfirmationMismatch(newPassword: "", confirmation: "Secret1a"))
        #expect(passwordMeetsRules("Secret1a"))
        #expect(!passwordMeetsRules("secret1a"))
        #expect(!passwordMeetsRules("SECRET1A"))
        #expect(!passwordMeetsRules("SecretAA"))
        #expect(!passwordMeetsRules("Aa1"))
        #expect(VerbisAPIError.BadPassword.errorDescription == "The album number or password is incorrect.")
        #expect(VerbisAPIError.PasswordsDoNotMatch.errorDescription == "Passwords do not match.")
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
