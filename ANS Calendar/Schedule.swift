//
//  Schedule.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI
import SwiftSoup

let SchedulePageURL = "https://wu.ans-nt.edu.pl/ppuz-stud-app/ledge/view/stud.schedule.SchedulePage"

@MainActor
class ScheduleModel: ObservableObject {
    @Published var Schedules: [ScheduleInfo] = []
    @AppStorage("JSessionID") var SessionID: String = ""
    @AppStorage("StudentID") var StudentID: Int = 0
    @AppStorage("TourID") var TourID: Int = 0
    @AppStorage("SemesterID") var SemesterID: Int = 0
    
    init() {}
    
    func LoadSchedule(date: Date) async throws {
        do {
            if await (!CheckAuthority(SessionID: SessionID)) {
                await LoginExistingUser()
            }
            else {
                if SemesterID == 0 {
                    let apiurl = URL(string: SchedulePageURL)
                    
                    var request = URLRequest(url: apiurl!)
                    request.httpMethod = "POST"
                    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                    request.setValue("JSESSIONID=\(SessionID)", forHTTPHeaderField: "Cookie")
                    
                    let loginData: Data = "idosoby=\(StudentID)&nrtury=\(TourID)".data(using: .utf8)!
                    request.httpBody = loginData
                    
                    let session = URLSession.shared
                    let (data, response) = try await session.data(for: request)
                    let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
                    let doc: Document = try SwiftSoup.parse(html)
                    
                    let scripts: Elements = try doc.select("script")
                    
                    var SemesterID = 0
                    
                    let semesterIDRegex = /(idSemestru:)\s(\d+)/
                    for script in scripts {
                        if let match = try script.data().firstMatch(of: semesterIDRegex) {
                            SemesterID = NumberFormatter().number(from: String(match.2))!.intValue
                            UserDefaults.standard.set(SemesterID, forKey: "SemesterID")
                            break
                        }
                    }
                }
                
                Schedules = try await FetchSchedules(semesterID: SemesterID, date: date)
            }
        } catch {
            print("Hmmge")
        }
    }
    
    func FetchSchedules(semesterID: Int, date: Date) async throws -> [ScheduleInfo] {
        do {
            let url = URL(string: AJAXUrl)
            var request = URLRequest(url: url!)
            request.httpMethod = "POST"
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.setValue("JSESSIONID=\(SessionID)", forHTTPHeaderField: "Cookie")
            
            request.httpBody = "{\"service\":\"Planowanie\",\"method\":\"getUlozoneTerminyOsoby\",\"params\":{\"idOsoby\":\(StudentID),\"idSemestru\":\(semesterID),\"poczatekTygodnia\":\(date.timeIntervalSince1970 * 1000)}}".data(using: .utf8)
            
            let session = URLSession.shared
            let (data, _) = try await session.data(for: request)
            let parsedJSON: AJAXReturn = try! JSONDecoder().decode(AJAXReturn.self, from: data)
            var SchedulesToday: [ScheduleInfo] = []
            for schedule in parsedJSON.returnedValue.items {
                if Calendar.current.isDate(date, equalTo: Date(timeIntervalSince1970: Double(schedule.dataRozpoczecia / 1000)), toGranularity: .day) {
                    SchedulesToday.append(schedule)
                }
            }
            
            return SchedulesToday.sorted { $0.dataRozpoczecia < $1.dataRozpoczecia }
        } catch {
            return ScheduleInfo.SampleData
        }
    }
}

struct Schedule: View {
    @State private var date = Date()
    @StateObject var model = ScheduleModel()
    var body: some View {
        VStack {
            DatePicker("Schedule day", selection: $date, displayedComponents: [.date]).task(id: date, priority: .userInitiated) {
                do {
                    try await model.LoadSchedule(date: date)
                } catch {
                    
                }
            }
            DayView(date: date, schedules: model.Schedules)
                .task {
                    do {
                        try await model.LoadSchedule(date: date)
                    } catch {
                        
                    }
                }
        }
    }
}

struct AJAXReturn: Codable {
    let returnedValue: ReturnedValueObject
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

#Preview {
    Schedule()
}
