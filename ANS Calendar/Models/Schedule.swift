//
//  Schedule.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI
import SwiftSoup

let SchedulePageURL = "https://wu.ans-nt.edu.pl/ppuz-stud-app/ledge/view/stud.schedule.SchedulePage"

struct Week: Identifiable {
    let id = UUID()
    var Days: [Date]
}

@MainActor
class ScheduleModel: ObservableObject {
    @Published var Schedules: [ScheduleInfo] = []
    @Published var SelectedDay: Date
    @Published var SelectedWeek: Date
    @Published var Weeks: [Week] = .init()
    
    init() {
        self.SelectedDay = Date()
        self.SelectedWeek = Date().startOfWeek()
        SetupWeeks(for: SelectedDay)
    }
    
    private func SetupWeeks(for date: Date) {
        Weeks = [
            FillDays(with: Calendar.current.date(byAdding: .day, value: -7, to: SelectedDay)!),
            FillDays(with: SelectedDay),
            FillDays(with: Calendar.current.date(byAdding: .day, value: 7, to: SelectedDay)!)
        ]
    }
    
    private func FillDays(with date: Date) -> Week {
        var days: [Date] = .init()
        
        (0...6).forEach({ day in
            let day = Calendar.current.date(byAdding: .day, value: day, to: date.startOfWeek())!
            days.append(day)
        })
        
        return .init(Days: days)
    }
    
    func SelectDay(day: Date) {
        SelectedDay = day
    }
    
    func ShiftWeeks(dir: Int) {
        if (dir == -1) {
            SelectDay(day: Calendar.current.date(byAdding: .day, value: -7, to: SelectedDay)!)
        }
        
        if (dir == 1) {
            SelectDay(day: Calendar.current.date(byAdding: .day, value: 7, to: SelectedDay)!)
        }
        
        SelectedWeek = SelectedDay.startOfWeek()
        
        SetupWeeks(for: SelectedDay)
    }
    
    func LoadSchedule(VerbisANSApi: VerbisAPI) async throws {
        do {
            if await !VerbisANSApi.CheckAuthority() {
                try await VerbisANSApi.LoginExistingUser()
            } else {
                Schedules = try await FetchSchedules(VerbisANSApi: VerbisANSApi, semesterID: VerbisANSApi.SemesterID, date: SelectedWeek)
            }
        } catch {
            print("Hmmge")
        }
    }
    
    func FetchSchedules(VerbisANSApi: VerbisAPI, semesterID: Int, date: Date) async throws -> [ScheduleInfo] {
        do {
            let url = URL(string: AJAXUrl)
            var request = URLRequest(url: url!)
            request.httpMethod = "POST"
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.setValue("JSESSIONID=\(VerbisANSApi.JSessionID)", forHTTPHeaderField: "Cookie")
            
            request.httpBody = "{\"service\":\"Planowanie\",\"method\":\"getUlozoneTerminyOsoby\",\"params\":{\"idOsoby\":\(VerbisANSApi.StudentID),\"idSemestru\":\(semesterID),\"poczatekTygodnia\":\(date.timeIntervalSince1970 * 1000)}}".data(using: .utf8)
            
            let session = URLSession.shared
            let (data, _) = try await session.data(for: request)
            
            let parsedJSON: AJAXReturn = try! JSONDecoder().decode(AJAXReturn.self, from: data)
            
            let SchedulesToday: [ScheduleInfo] = parsedJSON.returnedValue!.items
            
            return SchedulesToday.sorted { $0.dataRozpoczecia < $1.dataRozpoczecia }
        } catch {
            return ScheduleInfo.SampleData
        }
    }
}

struct AJAXReturn: Codable {
    let exceptionClass: String?
    let returnedValue: ReturnedValueObject?
}

struct ReturnedValueObject: Codable {
    let identifier: String
    let items: [ScheduleInfo]
}

struct ScheduleInfo: Identifiable, Codable {
    let id = UUID()
    let dataRozpoczecia: Int
    let dataZakonczenia: Int
    let nazwaPelnaPrzedmiotu: String
    let listaIdZajecInstancji: [LessonInfo]
    let sale: [RoomInfo]
    
    private enum CodingKeys: String, CodingKey {
        case dataRozpoczecia
        case dataZakonczenia
        case nazwaPelnaPrzedmiotu
        case listaIdZajecInstancji
        case sale
    }
}

struct LessonInfo: Codable {
    let nrZajec: Int
    let typZajec: String
}

struct RoomInfo: Codable {
    let idSali: Int
    let nazwaSkrocona: String
}

extension ScheduleInfo {
    static let SampleData = [
        ScheduleInfo(dataRozpoczecia: 1731660000000, dataZakonczenia: 1731670000000, nazwaPelnaPrzedmiotu: "Podstawy matematyki", listaIdZajecInstancji: [LessonInfo(nrZajec: 1, typZajec: "co")], sale: [RoomInfo(idSali: 35, nazwaSkrocona: "BT T.0.01")]),
        ScheduleInfo(dataRozpoczecia: 1731681900000, dataZakonczenia: 1731690000000, nazwaPelnaPrzedmiotu: "Podstawy matematyki", listaIdZajecInstancji: [LessonInfo(nrZajec: 1, typZajec: "co")], sale: [RoomInfo(idSali: 35, nazwaSkrocona: "BT T.0.01")])
    ]
}
