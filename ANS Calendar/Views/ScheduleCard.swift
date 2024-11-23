//
//  ScheduleCard.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI

struct ScheduleCard: View {
    let Schedule: ScheduleInfo
    var startHour: Int
    var startMinute: Int
    var Offset: Double
    var Duration: Double
    var StartDate: Date
    var EndDate: Date
    var Height: Double
    
    init(Schedule: ScheduleInfo) {
        self.Schedule = Schedule
        
        StartDate = Date(timeIntervalSince1970: Double(Schedule.dataRozpoczecia / 1000))
        
        EndDate = Date(timeIntervalSince1970: Double(Schedule.dataZakonczenia / 1000))
        
        startHour = Date().GetDateComponent(Date: StartDate, Component: .hour)
        startMinute = Date().GetDateComponent(Date: StartDate, Component: .minute)
        
        Offset = (Double(startHour - 6) * hourHeight) + ((Double(startMinute) / 60) * hourHeight)
        
        Duration = EndDate.timeIntervalSince(StartDate)
        Height = (Duration / 60 / 60) * hourHeight
    }
    
    var body: some View {
        VStack() {
            HStack {
                Text(Schedule.nazwaPelnaPrzedmiotu)
                    .font(.headline)
                Text("\(Schedule.listaIdZajecInstancji[0].typZajec)\(Schedule.listaIdZajecInstancji[0].nrZajec)")
            }
            HStack {
                Text(Date(timeIntervalSince1970: Double(Schedule.dataRozpoczecia / 1000)).formatted(date: .omitted, time: .shortened))
                Text(Date(timeIntervalSince1970: Double(Schedule.dataZakonczenia / 1000)).formatted(date: .omitted, time: .shortened))
            }
            Text(Schedule.sale[0].nazwaSkrocona)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Height, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 5).fill(.blue).opacity(0.5))
        .padding(.trailing, 60)
        .offset(x: 60, y: Offset)
    }
}

#Preview(traits: .fixedLayout(width: 400, height: 60)) {
    var Schedule = ScheduleInfo.SampleData[0]
    ScheduleCard(Schedule: Schedule)
}
