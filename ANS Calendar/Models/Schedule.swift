//
//  Schedule.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI

let SchedulePageURL = "stud.schedule.SchedulePage"

struct Week: Identifiable {
    let id = UUID()
    var Days: [Date]
}

enum ScheduleLoadError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        }
    }
}

struct TimelinePlacement: Identifiable {
    let schedule: ScheduleInfo
    let column: Int
    let columnCount: Int
    let startMinutes: Int
    let endMinutes: Int

    var id: UUID { schedule.id }
}

func timelinePlacements(
    for schedules: [ScheduleInfo],
    dayStartHour: Int = 7,
    dayEndHour: Int = 22
) -> [TimelinePlacement] {
    let visibleStart = dayStartHour * 60
    let visibleEnd = dayEndHour * 60

    struct Item {
        let schedule: ScheduleInfo
        let start: Int
        let end: Int
        var column = 0
    }

    let items: [Item] = schedules.compactMap { schedule in
        let start = schedule.startDate.minutesFromMidnight
        var end = schedule.endDate.minutesFromMidnight
        if end <= start {
            end = start + 30
        }
        if end - start < 30 {
            end = start + 30
        }
        guard end > visibleStart, start < visibleEnd else { return nil }
        return Item(schedule: schedule, start: start, end: end)
    }.sorted { lhs, rhs in
        if lhs.start == rhs.start { return lhs.end > rhs.end }
        return lhs.start < rhs.start
    }

    var placements: [TimelinePlacement] = []
    var index = 0
    while index < items.count {
        var cluster: [Item] = [items[index]]
        var clusterEnd = items[index].end
        index += 1
        while index < items.count, items[index].start < clusterEnd {
            cluster.append(items[index])
            clusterEnd = max(clusterEnd, items[index].end)
            index += 1
        }

        var columnEnds: [Int] = []
        for itemIndex in cluster.indices {
            if let column = columnEnds.firstIndex(where: { $0 <= cluster[itemIndex].start }) {
                cluster[itemIndex].column = column
                columnEnds[column] = cluster[itemIndex].end
            } else {
                cluster[itemIndex].column = columnEnds.count
                columnEnds.append(cluster[itemIndex].end)
            }
        }

        let columnCount = max(columnEnds.count, 1)
        for item in cluster {
            placements.append(TimelinePlacement(
                schedule: item.schedule,
                column: item.column,
                columnCount: columnCount,
                startMinutes: item.start,
                endMinutes: item.end
            ))
        }
    }
    return placements
}

@MainActor
class ScheduleModel: ObservableObject {
    @Published private(set) var Schedules: [ScheduleInfo] = []
    @Published var SelectedDay: Date
    @Published var SelectedWeek: Date
    @Published var DisplayedMonth: Date
    @Published var Weeks: [Week] = []
    @Published var IsLoading = false
    @Published var LoadError: String?

    private var cachedWeeks: [Date: [ScheduleInfo]] = [:]
    private var loadsInFlight = 0

    init() {
        let today = Date()
        SelectedDay = today
        SelectedWeek = today.startOfWeek()
        DisplayedMonth = today.startOfMonth
        SetupWeeks(for: today)
    }

    func schedules(on day: Date) -> [ScheduleInfo] {
        Schedules.filter { $0.occurs(on: day) }
    }

    func SelectDay(day: Date) {
        SelectedDay = day
        if !SelectedDay.IsSameWeek(date: SelectedWeek) {
            SelectWeek(for: SelectedDay)
        }
    }

    func SelectWeek(for date: Date) {
        SelectedWeek = date.startOfWeek()
        SetupWeeks(for: date)
    }

    func ShiftWeeks(dir: Int) {
        if dir == 0 {
            SelectWeek(for: SelectedDay)
            return
        }
        SelectDay(day: SelectedDay.addingDays(dir * 7))
    }

    func LoadSchedule(VerbisANSApi: VerbisAPI) async {
        await loadWeeks([SelectedWeek], VerbisANSApi: VerbisANSApi)
    }

    func LoadMonth(_ month: Date, VerbisANSApi: VerbisAPI) async {
        await loadWeeks(month.weekStartsCoveringMonth(), VerbisANSApi: VerbisANSApi)
    }

    func FetchSchedules(VerbisANSApi: VerbisAPI, semesterID: Int, date: Date) async throws -> [ScheduleInfo] {
        let weekStart = date.startOfWeek()
        let request = VerbisANSApi.InitAJAXRequest(
            Service: "Planowanie",
            Method: "getOpublikowaneSpotkaniaOsoby",
            Params: "\"idOsoby\":\(VerbisANSApi.StudentID),\"idSemestru\":\(semesterID),\"poczatekTygodnia\":\(weekStart.timeIntervalSince1970 * 1000)"
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let parsedJSON = try JSONDecoder().decode(AJAXReturn.self, from: data)
        if let exception = parsedJSON.exceptionClass, !exception.isEmpty {
            throw ScheduleLoadError.server(exception)
        }
        return (parsedJSON.returnedValue?.items ?? []).sorted { $0.dataRozpoczecia < $1.dataRozpoczecia }
    }

    private func loadWeeks(_ weeks: [Date], VerbisANSApi: VerbisAPI) async {
        beginLoad()
        defer { endLoad() }

        do {
            if await !VerbisANSApi.CheckAuthority() {
                try await VerbisANSApi.LoginExistingUser()
            }
            guard VerbisANSApi.IsLoggedIn else { return }

            for week in weeks {
                let items = try await FetchSchedules(
                    VerbisANSApi: VerbisANSApi,
                    semesterID: VerbisANSApi.SemesterID,
                    date: week
                )
                store(week: week, items: items)
            }
            LoadError = nil
        } catch {
            LoadError = "Couldn't load the schedule."
            print("Failed to load schedule: \(error.localizedDescription)")
        }
    }

    private func store(week: Date, items: [ScheduleInfo]) {
        cachedWeeks[week.startOfWeek()] = items
        var seen = Set<String>()
        var combined: [ScheduleInfo] = []
        for weekItems in cachedWeeks.values {
            for item in weekItems where seen.insert(item.dedupeKey).inserted {
                combined.append(item)
            }
        }
        Schedules = combined.sorted { $0.dataRozpoczecia < $1.dataRozpoczecia }
    }

    private func beginLoad() {
        loadsInFlight += 1
        IsLoading = true
    }

    private func endLoad() {
        loadsInFlight = max(0, loadsInFlight - 1)
        IsLoading = loadsInFlight > 0
    }

    private func SetupWeeks(for date: Date) {
        Weeks = [
            FillDays(with: date.addingDays(-7)),
            FillDays(with: date),
            FillDays(with: date.addingDays(7))
        ]
    }

    private func FillDays(with date: Date) -> Week {
        Week(Days: date.daysOfWeek())
    }
}

struct AJAXReturn: Codable {
    let exceptionClass: String?
    let returnedValue: ReturnedValueObject?
}

struct ReturnedValueObject: Codable {
    let identifier: String?
    let items: [ScheduleInfo]
}

struct LecturerInfo: Codable {
    let idProwadzacego: Int
    let stopienImieNazwisko: String
}

struct ScheduleInfo: Identifiable, Codable {
    let id: UUID
    let dataRozpoczecia: Int
    let dataZakonczenia: Int
    let nazwaPelnaPrzedmiotu: String
    let grupyZajeciowe: [LessonInfo]
    let grupySprawdzianu: [ExamInfo]
    let listaIdZajecInstancji: [LessonType]
    let sale: [RoomInfo]
    let wykladowcy: [LecturerInfo]

    init(
        id: UUID = UUID(),
        dataRozpoczecia: Int,
        dataZakonczenia: Int,
        nazwaPelnaPrzedmiotu: String,
        grupyZajeciowe: [LessonInfo],
        grupySprawdzianu: [ExamInfo],
        listaIdZajecInstancji: [LessonType],
        sale: [RoomInfo],
        wykladowcy: [LecturerInfo]
    ) {
        self.id = id
        self.dataRozpoczecia = dataRozpoczecia
        self.dataZakonczenia = dataZakonczenia
        self.nazwaPelnaPrzedmiotu = nazwaPelnaPrzedmiotu
        self.grupyZajeciowe = grupyZajeciowe
        self.grupySprawdzianu = grupySprawdzianu
        self.listaIdZajecInstancji = listaIdZajecInstancji
        self.sale = sale
        self.wykladowcy = wykladowcy
    }

    var startDate: Date { Date(timeIntervalSince1970: Double(dataRozpoczecia) / 1000) }
    var endDate: Date { Date(timeIntervalSince1970: Double(dataZakonczenia) / 1000) }

    var isExam: Bool { !grupySprawdzianu.isEmpty }

    var groupLabel: String {
        if let exam = grupySprawdzianu.first?.nazwaSkroconaGrupySprawdzianu, !exam.isEmpty {
            return exam
        }
        return grupyZajeciowe.first?.nazwaGrupyZajeciowej ?? ""
    }

    var roomLabel: String {
        sale.first?.nazwaSkrocona ?? "No room"
    }

    var lecturerLabel: String {
        wykladowcy.first?.stopienImieNazwisko ?? "No lecturer"
    }

    var timeRangeLabel: String {
        let start = startDate.formatted(date: .omitted, time: .shortened)
        let end = endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var dedupeKey: String {
        "\(dataRozpoczecia)|\(dataZakonczenia)|\(nazwaPelnaPrzedmiotu)|\(roomLabel)"
    }

    func occurs(on day: Date) -> Bool {
        startDate.IsSameDay(date: day)
    }

    func GetLessonColor() -> Color {
        if let lessonType = listaIdZajecInstancji.first?.typZajec {
            switch lessonType {
            case "W": return .blue
            case "CL": return .mint
            case "CP": return .orange
            case "CA": return .green
            case "CW": return .cyan
            default: return .blue
            }
        } else if isExam {
            return .red
        } else {
            return .blue
        }
    }

    private enum CodingKeys: String, CodingKey {
        case dataRozpoczecia
        case dataZakonczenia
        case nazwaPelnaPrzedmiotu
        case grupyZajeciowe
        case grupySprawdzianu
        case listaIdZajecInstancji
        case sale
        case wykladowcy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        dataRozpoczecia = try container.decode(Int.self, forKey: .dataRozpoczecia)
        dataZakonczenia = try container.decode(Int.self, forKey: .dataZakonczenia)
        nazwaPelnaPrzedmiotu = try container.decodeIfPresent(String.self, forKey: .nazwaPelnaPrzedmiotu) ?? ""
        grupyZajeciowe = try container.decodeIfPresent([LessonInfo].self, forKey: .grupyZajeciowe) ?? []
        grupySprawdzianu = try container.decodeIfPresent([ExamInfo].self, forKey: .grupySprawdzianu) ?? []
        listaIdZajecInstancji = try container.decodeIfPresent([LessonType].self, forKey: .listaIdZajecInstancji) ?? []
        sale = try container.decodeIfPresent([RoomInfo].self, forKey: .sale) ?? []
        wykladowcy = try container.decodeIfPresent([LecturerInfo].self, forKey: .wykladowcy) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dataRozpoczecia, forKey: .dataRozpoczecia)
        try container.encode(dataZakonczenia, forKey: .dataZakonczenia)
        try container.encode(nazwaPelnaPrzedmiotu, forKey: .nazwaPelnaPrzedmiotu)
        try container.encode(grupyZajeciowe, forKey: .grupyZajeciowe)
        try container.encode(grupySprawdzianu, forKey: .grupySprawdzianu)
        try container.encode(listaIdZajecInstancji, forKey: .listaIdZajecInstancji)
        try container.encode(sale, forKey: .sale)
        try container.encode(wykladowcy, forKey: .wykladowcy)
    }
}

struct LessonInfo: Codable {
    let nazwaGrupyZajeciowej: String
}

struct LessonType: Codable {
    let typZajec: String
}

struct ExamInfo: Codable {
    let nazwaGrupySprawdzianu: String
    let nazwaSkroconaGrupySprawdzianu: String
}

struct RoomInfo: Codable {
    let idSali: Int
    let nazwaSkrocona: String
}

extension ScheduleInfo {
    static let SampleData = [
        ScheduleInfo(dataRozpoczecia: 1731657600000, dataZakonczenia: 1731670000000, nazwaPelnaPrzedmiotu: "Podstawy matematyki", grupyZajeciowe: [LessonInfo(nazwaGrupyZajeciowej: "co")], grupySprawdzianu: [], listaIdZajecInstancji: [LessonType(typZajec: "W")], sale: [RoomInfo(idSali: 35, nazwaSkrocona: "BT T.0.01")], wykladowcy: [LecturerInfo(idProwadzacego: 1, stopienImieNazwisko: "mgr. Jan Kowalski")]),
        ScheduleInfo(dataRozpoczecia: 1731672000000, dataZakonczenia: 1731677400000, nazwaPelnaPrzedmiotu: "Awesome quick long named lesson", grupyZajeciowe: [LessonInfo(nazwaGrupyZajeciowej: "CW1")], grupySprawdzianu: [], listaIdZajecInstancji: [LessonType(typZajec: "CW")], sale: [RoomInfo(idSali: 2, nazwaSkrocona: "BG 314")], wykladowcy: [LecturerInfo(idProwadzacego: 6465, stopienImieNazwisko: "mgr. Joe Doe")]),
        ScheduleInfo(dataRozpoczecia: 1731681900000, dataZakonczenia: 1731690000000, nazwaPelnaPrzedmiotu: "Podstawy matematyki", grupyZajeciowe: [], grupySprawdzianu: [ExamInfo(nazwaGrupySprawdzianu: "Awesome exam", nazwaSkroconaGrupySprawdzianu: "AE")], listaIdZajecInstancji: [], sale: [RoomInfo(idSali: 35, nazwaSkrocona: "BT T.0.01")], wykladowcy: [LecturerInfo(idProwadzacego: 1, stopienImieNazwisko: "mgr. Jan Kowalski")])
    ]
}
