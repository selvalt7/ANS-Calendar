//
//  ScheduleCard.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI

struct ScheduleCard: View {
    let Schedule: ScheduleInfo
    var body: some View {
        VStack {
            HStack {
                Text(Schedule.nazwaPelnaPrzedmiotu)
                    .font(.headline)
                Text(Schedule.listaIdZajecInstancji[0].typZajec)
            }
            HStack {
                Text(Date(timeIntervalSince1970: Double(Schedule.dataRozpoczecia / 1000)).formatted(date: .omitted, time: .shortened))
                Text(Date(timeIntervalSince1970: Double(Schedule.dataZakonczenia / 1000)).formatted(date: .omitted, time: .shortened))
            }
            Text(Schedule.sale[0].nazwaSkrocona)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth: 2))
    }
}

#Preview(traits: .fixedLayout(width: 400, height: 60)) {
    var Schedule = ScheduleInfo.SampleData[0]
    ScheduleCard(Schedule: Schedule)
}
