//
//  Grades.swift
//  ANS Calendar
//

import SwiftUI
import SwiftSoup

let GradesPageURL = "stud.info.StudentProgress"

struct CreditTriple: Equatable {
    var parts: [String]

    var display: String { parts.joined(separator: " / ") }

    /// ECTS and hours are printed as enrolled / passed / failed.
    var passedOfEnrolled: String {
        guard parts.count >= 2 else { return display.isEmpty ? "—" : display }
        let enrolled = parts[0]
        let passed = parts[1]
        if parts.count >= 3, !creditTokenIsZero(parts[2]) {
            return "\(passed) of \(enrolled), \(parts[2]) failed"
        }
        return "\(passed) of \(enrolled)"
    }
}

struct GradeAttempt: Equatable {
    var context: String?
    var label: String
    var grade: String
    var date: String?

    var valueText: String {
        if let date, !date.isEmpty {
            return "\(grade) · \(date)"
        }
        return grade
    }
}

struct CourseGroup: Equatable {
    var code: String
    var lecturers: [String]
}

struct HourComponent: Equatable {
    var code: String
    var hours: String

    var title: String {
        switch code.uppercased() {
        case "W": return "Lecture"
        case "CA": return "Seminar"
        case "CP": return "Project"
        case "CL": return "Lab"
        case "CW": return "Practical"
        case "PZ": return "Internship"
        default: return code
        }
    }
}

struct CourseGrade: Identifiable, Equatable {
    var id: String
    var catalogNumber: String
    var name: String
    var coordinator: String?
    var grade: String
    var isPending: Bool
    var isUnsatisfactory: Bool
    var attempts: [GradeAttempt]
    var ects: String
    var ectsPending: Bool
    var hours: String
    var hoursPending: Bool
    var hourBreakdown: [HourComponent]
    var costUnits: String
    var groups: [CourseGroup]
    var isExam: Bool

    var displayGrade: String {
        isEmptyGrade(grade) ? "—" : grade
    }

    var listMeta: String {
        [catalogNumber, ects.isEmpty ? nil : "\(ects) ECTS", isExam ? "Exam" : nil]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct StudySemester: Identifiable, Equatable {
    var id: String
    var term: String
    var termTitle: String
    var studySemester: String
    var trackTitle: String
    var stage: String
    var status: String
    var ects: CreditTriple
    var cumulativeECTS: CreditTriple
    var hours: CreditTriple
    var costUnits: CreditTriple
    var semesterAverage: String?
    var yearlyAverage: String?
    var cumulativeAverage: String?
    var deanGroup: String
    var program: String?
    var advisor: String?
    var courses: [CourseGrade]

    var listSubtitle: String {
        var bits: [String] = []
        if !studySemester.isEmpty {
            bits.append("Semester \(studySemester)")
        }
        if !deanGroup.isEmpty {
            bits.append(deanGroup)
        }
        if !status.isEmpty {
            bits.append(status)
        }
        return bits.joined(separator: " · ")
    }

    var listAverage: String { semesterAverage ?? "—" }
}

struct AcademicProgress: Equatable {
    var semesters: [StudySemester]

    var latest: StudySemester? { semesters.last }
    var newestFirst: [StudySemester] { semesters.reversed() }
}

func parseAcademicProgress(html: String) throws -> AcademicProgress {
    let document = try SwiftSoup.parse(html)
    let rows = try document.select("#progress-table tr").array()
    var semesters: [StudySemester] = []
    for row in rows {
        let rowID = try row.attr("id")
        guard rowID.wholeMatch(of: /\d+/) != nil else { continue }
        guard try cell(in: row, headers: "th-semestr") != nil else { continue }
        semesters.append(try parseSemester(row, id: rowID, document: document))
    }
    return AcademicProgress(semesters: semesters)
}

@MainActor
final class GradesModel: ObservableObject {
    @Published var progress: AcademicProgress?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(api: VerbisAPI) async {
        if progress == nil {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let request = api.InitRequest(EndUrl: GradesPageURL)
            let (data, _) = try await URLSession.shared.data(for: request)
            let html: String
            if let decoded = String(data: data, encoding: .utf8) {
                html = decoded
            } else {
                html = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            }
            let parsed = try parseAcademicProgress(html: html)
            guard !parsed.semesters.isEmpty else {
                if progress == nil {
                    errorMessage = "Couldn't load grades."
                }
                return
            }
            progress = parsed
            errorMessage = nil
        } catch {
            if progress == nil {
                errorMessage = "Couldn't load grades."
            }
            print("Failed to load grades: \(error.localizedDescription)")
        }
    }
}

private func parseSemester(_ row: Element, id: String, document: Document) throws -> StudySemester {
    let term = try text(of: cell(in: row, headers: "th-semestr"))
    let track = try text(of: cell(in: row, headers: "th-tok-studiow"))
    let groupCell = try cell(in: row, headers: "th-grupa-dziekanska")
    let group = try text(of: groupCell)
    let programTitle = try (groupCell?.attr("title") ?? "").cleanedPortalText()
    let details = try document.getElementById("tr-progress-details\(id)")
    return StudySemester(
        id: id,
        term: term,
        termTitle: studyTermTitle(term),
        studySemester: try text(of: cell(in: row, headers: "th-semestr-studiow")),
        trackTitle: studyTermTitle(track),
        stage: translatedStage(try text(of: cell(in: row, headers: "th-etap-studiow"))),
        status: translatedStatus(try text(of: cell(in: row, headers: "th-status"))),
        ects: try credit(of: cell(in: row, headers: "th-ects-semestralnie")),
        cumulativeECTS: try credit(of: cell(in: row, headers: "th-ects-skumulowane")),
        hours: try credit(of: cell(in: row, headers: "th-godziny-semestralnie")),
        costUnits: try credit(of: cell(in: row, headers: "th-jk")),
        semesterAverage: meaningfulAverage(try text(of: cell(in: row, headers: "th-srednia-semestralna"))),
        yearlyAverage: meaningfulAverage(try text(of: cell(in: row, headers: "th-srednia-roczna"))),
        cumulativeAverage: meaningfulAverage(try text(of: cell(in: row, headers: "th-srednia-skumulowana"))),
        deanGroup: group,
        program: programTitle.isEmpty || programTitle == group ? nil : programTitle,
        advisor: nonempty(try text(of: cell(in: row, headers: "th-opiekun"))),
        courses: try courses(in: details)
    )
}

private func courses(in details: Element?) throws -> [CourseGrade] {
    guard let details else { return [] }
    let rows = try details.select("tr").array().filter { row in
        (try? row.attr("id").hasPrefix("instancja")) == true
    }
    return try rows.map(parseCourse)
}

private func parseCourse(_ row: Element) throws -> CourseGrade {
    let gradeCell = try cell(in: row, headerSuffix: "-ocena")
    let gradeSpan = directSpans(gradeCell).first
    let grade = try (gradeSpan?.text() ?? "").cleanedPortalText()
    let pending = gradeSpan?.hasClass("inactive") == true || isEmptyGrade(grade)
    let hoursCell = try cell(in: row, headerSuffix: "-godziny")
    let ectsCell = try cell(in: row, headerSuffix: "-ects")
    let passCell = try cell(in: row, headerSuffix: "-typ-zaliczenia")
    let passSpan = directSpans(passCell).first
    let passToken = try (passSpan?.text() ?? "").cleanedPortalText()
    let passTitle = try passSpan?.attr("title") ?? ""
    let costCell = try cell(in: row, headerSuffix: "-jk")
    let rowID = try row.attr("id")
    let catalog = try text(of: cell(in: row, headerSuffix: "-nr-katalogowy"))
    let name = try text(of: cell(in: row, headerSuffix: "-nazwa-przedmiotu"))
    return CourseGrade(
        id: rowID.isEmpty ? "\(catalog)-\(name)" : rowID,
        catalogNumber: catalog,
        name: name,
        coordinator: try coordinator(in: cell(in: row, headerSuffix: "-wersja")),
        grade: grade,
        isPending: pending,
        isUnsatisfactory: isUnsatisfactoryGrade(grade),
        attempts: try gradeAttempts(in: gradeCell),
        ects: try spanOrCellText(directSpans(ectsCell).first, fallback: ectsCell),
        ectsPending: directSpans(ectsCell).first?.hasClass("inactive") == true,
        hours: try spanOrCellText(directSpans(hoursCell).first, fallback: hoursCell),
        hoursPending: directSpans(hoursCell).first?.hasClass("inactive") == true,
        hourBreakdown: try hourBreakdown(in: hoursCell),
        costUnits: try spanOrCellText(directSpans(costCell).first, fallback: nil),
        groups: try courseGroups(in: cell(in: row, headerSuffix: "-grupy")),
        isExam: passToken.uppercased() == "E" || foldedPortalText(passTitle) == "egzamin"
    )
}

private func coordinator(in cell: Element?) throws -> String? {
    guard let cell else { return nil }
    let version = cell.children().array().first { node in
        node.tagName().lowercased() == "div" && !node.hasClass("dijitTooltipData")
    }
    let shortName = try (version?.text() ?? "").cleanedPortalText()
    let versionID = try version?.attr("id") ?? ""
    let tooltip = versionID.isEmpty ? nil : tooltipDivs(cell).first { (try? $0.attr("connectid")) == versionID }
    let fullName = try (tooltip?.text() ?? "").cleanedPortalText()
    let value = translateNoData(fullName.isEmpty ? shortName : fullName)
    return value.isEmpty ? nil : value
}

private func gradeAttempts(in cell: Element?) throws -> [GradeAttempt] {
    guard let cell, let table = try cell.select("table.student-grades").array().first else { return [] }
    var context: String?
    var attempts: [GradeAttempt] = []
    for attemptRow in try table.select("tr").array() {
        let columns = try attemptRow.select("td").array()
        guard let labelCell = columns.first else { continue }
        let heading = try labelCell.text().cleanedPortalText()
        if columns.count < 2 || !(try labelCell.attr("colspan")).isEmpty {
            context = attemptContext(heading)
            continue
        }
        let parsed = splitGradeAndDate(try columns[1].text().cleanedPortalText())
        guard !isEmptyGrade(parsed.grade) else { continue }
        let label = translatedAttemptLabel(heading)
        guard !label.isEmpty else { continue }
        attempts.append(GradeAttempt(context: context, label: label, grade: parsed.grade, date: parsed.date))
    }
    return attempts
}

private func hourBreakdown(in cell: Element?) throws -> [HourComponent] {
    guard let cell else { return [] }
    var components: [HourComponent] = []
    for tooltip in tooltipDivs(cell) {
        for span in try tooltip.select("span").array() {
            let line = try span.text().cleanedPortalText()
            guard let match = line.wholeMatch(of: /([A-Za-z]+):\s*(\d+)/) else { continue }
            components.append(HourComponent(code: String(match.1).uppercased(), hours: String(match.2)))
        }
    }
    return components
}

private func courseGroups(in cell: Element?) throws -> [CourseGroup] {
    guard let cell else { return [] }
    let tooltips = tooltipDivs(cell)
    var groups: [CourseGroup] = []
    for span in directSpans(cell) {
        let code = try span.text().cleanedPortalText().trimmingCharacters(in: CharacterSet(charactersIn: ","))
        guard !code.isEmpty else { continue }
        let spanID = try span.attr("id")
        let tooltip = tooltips.first { (try? $0.attr("connectid")) == spanID }
        groups.append(CourseGroup(code: code, lecturers: try lecturers(in: tooltip)))
    }
    return groups
}

private func lecturers(in tooltip: Element?) throws -> [String] {
    guard let tooltip else { return [] }
    var names: [String] = []
    for node in tooltip.children().array() {
        let name = try node.text().cleanedPortalText()
        let key = foldedPortalText(name)
        if name.isEmpty || key.contains("brak wykladowcow") { continue }
        names.append(name)
    }
    return names
}

private func cell(in row: Element, headers: String) throws -> Element? {
    try row.select("td").array().first { try $0.attr("headers") == headers }
}

private func cell(in row: Element, headerSuffix: String) throws -> Element? {
    try row.select("td").array().first { try $0.attr("headers").hasSuffix(headerSuffix) }
}

private func text(of cell: Element?) throws -> String {
    guard let cell else { return "" }
    return try cell.text().cleanedPortalText()
}

private func spanOrCellText(_ span: Element?, fallback: Element?) throws -> String {
    if let span {
        return try span.text().cleanedPortalText()
    }
    return try text(of: fallback)
}

private func credit(of cell: Element?) throws -> CreditTriple {
    let raw = try text(of: cell)
    let parts = raw
        .components(separatedBy: "/")
        .map { $0.cleanedPortalText() }
        .filter { !$0.isEmpty }
    return CreditTriple(parts: parts)
}

private func directSpans(_ cell: Element?) -> [Element] {
    guard let cell else { return [] }
    return cell.children().array().filter { $0.tagName().lowercased() == "span" }
}

private func tooltipDivs(_ cell: Element) -> [Element] {
    cell.children().array().filter { $0.hasClass("dijitTooltipData") }
}

private func studyTermTitle(_ raw: String) -> String {
    let parts = raw.split(whereSeparator: \.isWhitespace).map(String.init)
    guard parts.count >= 2 else { return raw }
    let year = parts[0]
    switch parts[1].uppercased() {
    case "Z": return "Winter \(year)"
    case "L": return "Summer \(year)"
    default: return raw
    }
}

private func meaningfulAverage(_ raw: String) -> String? {
    let trimmed = raw.cleanedPortalText()
    if trimmed.isEmpty || trimmed == "--" || trimmed == "—" || trimmed == "-" { return nil }
    return trimmed
}

private func nonempty(_ raw: String) -> String? {
    let trimmed = raw.cleanedPortalText()
    return trimmed.isEmpty ? nil : trimmed
}

private func translatedStatus(_ raw: String) -> String {
    switch foldedPortalText(raw) {
    case "rekrutacja": return "Recruitment"
    case "rejestracja": return "Registered"
    case "rejestracja reczna": return "Manual registration"
    default: return raw.cleanedPortalText()
    }
}

private func translatedStage(_ raw: String) -> String {
    switch foldedPortalText(raw).replacingOccurrences(of: ".", with: "") {
    case "inz": return "Engineer"
    case "lic": return "Bachelor"
    case "mgr": return "Master"
    default: return raw.cleanedPortalText()
    }
}

private func translatedAttemptLabel(_ raw: String) -> String {
    switch foldedPortalText(raw).replacingOccurrences(of: ":", with: "") {
    case "ocena koncowa": return "Final grade"
    case "podstawowy": return "First sitting"
    case "poprawkowy": return "Retake"
    case "komisja", "komisyjny": return "Board exam"
    default:
        let cleaned = raw.cleanedPortalText().trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return cleaned
    }
}

private func attemptContext(_ heading: String) -> String? {
    switch foldedPortalText(heading) {
    case "", "terminy": return nil
    case "ocena w dziekanacie": return "Dean's office"
    case "arkusz w edycji u wykladowcy": return "Lecturer's draft"
    default: return heading.cleanedPortalText()
    }
}

private func splitGradeAndDate(_ raw: String) -> (grade: String, date: String?) {
    let trimmed = raw.cleanedPortalText()
    guard let match = trimmed.wholeMatch(of: /(.+?)\s*\((\d{1,2}\.\d{1,2}\.\d{4})\)/) else {
        return (trimmed, nil)
    }
    let grade = String(match.1).cleanedPortalText()
    return (grade, String(match.2))
}

private func translateNoData(_ text: String) -> String {
    text.replacingOccurrences(of: "(?i)brak danych", with: "No data", options: .regularExpression)
        .cleanedPortalText()
}

private func isEmptyGrade(_ grade: String) -> Bool {
    switch foldedPortalText(grade) {
    case "", "---", "--", "—", "-": return true
    default: return false
    }
}

private func isUnsatisfactoryGrade(_ grade: String) -> Bool {
    switch foldedPortalText(grade).replacingOccurrences(of: ".", with: ",") {
    case "2", "2,0", "nzal", "nk": return true
    default: return false
    }
}

private func creditTokenIsZero(_ token: String) -> Bool {
    let normalized = token.replacingOccurrences(of: ",", with: ".")
    return Double(normalized) == 0
}

private func foldedPortalText(_ text: String) -> String {
    text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pl_PL"))
        .lowercased()
        .cleanedPortalText()
}

private extension String {
    func cleanedPortalText() -> String {
        replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
