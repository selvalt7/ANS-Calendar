//
//  Schedule.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI
import SwiftSoup

let SchedulePageURL = "stud.schedule.SchedulePage"

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
            let request = VerbisANSApi.InitAJAXRequest(Service: "Planowanie", Method: "getUlozoneTerminyOsoby", Params: "\"idOsoby\":\(VerbisANSApi.StudentID),\"idSemestru\":\(semesterID),\"poczatekTygodnia\":\(date.timeIntervalSince1970 * 1000)")
            
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

struct LecturerInfo: Codable {
    let idProwadzacego: Int
    let stopienImieNazwisko: String
}

struct ScheduleInfo: Identifiable, Codable {
    let id = UUID()
    let dataRozpoczecia: Int
    let dataZakonczenia: Int
    let nazwaPelnaPrzedmiotu: String
    let grupyZajeciowe: [LessonInfo]
    let grupySprawdzianu: [ExamInfo]
    let sale: [RoomInfo]
    let wykladowcy: [LecturerInfo]
    
    private enum CodingKeys: String, CodingKey {
        case dataRozpoczecia
        case dataZakonczenia
        case nazwaPelnaPrzedmiotu
        case grupyZajeciowe
        case grupySprawdzianu
        case sale
        case wykladowcy
    }
}

struct LessonInfo: Codable {
    let nazwaGrupyZajeciowej: String
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
        ScheduleInfo(dataRozpoczecia: 1731660000000, dataZakonczenia: 1731670000000, nazwaPelnaPrzedmiotu: "Podstawy matematyki", grupyZajeciowe: [LessonInfo(nazwaGrupyZajeciowej: "co")], grupySprawdzianu: [], sale: [RoomInfo(idSali: 35, nazwaSkrocona: "BT T.0.01")], wykladowcy: [LecturerInfo(idProwadzacego: 1, stopienImieNazwisko: "mgr. Jan Kowalski")]),
        ScheduleInfo(dataRozpoczecia: 1731681900000, dataZakonczenia: 1731690000000, nazwaPelnaPrzedmiotu: "Podstawy matematyki", grupyZajeciowe: [LessonInfo(nazwaGrupyZajeciowej: "co")], grupySprawdzianu: [ExamInfo(nazwaGrupySprawdzianu: "Awesome exam", nazwaSkroconaGrupySprawdzianu: "AE")], sale: [RoomInfo(idSali: 35, nazwaSkrocona: "BT T.0.01")], wykladowcy: [LecturerInfo(idProwadzacego: 1, stopienImieNazwisko: "mgr. Jan Kowalski")])
    ]
}
