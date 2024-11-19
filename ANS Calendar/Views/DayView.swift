//
//  DayView.swift
//  ANS Calendar
//
//  Created by Stanisław on 19/11/2024.
//

import SwiftUI

let hourHeight = 50.0

struct DayView: View {
    let date: Date
    let schedules: [ScheduleInfo]
    
    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(6..<22) { hour in
                        HStack {
                            Text("\(hour)")
                                .frame(height: 2)
                            VStack {
                                Divider()
                            }
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }
                ForEach(schedules) { schedule in
                    ScheduleCard(Schedule: schedule)
                }
            }
            .padding(20)
        }
        .padding(0)
    }
}

#Preview {
    DayView(date: Date(timeIntervalSince1970: Double(1731681900000 / 1000)), schedules: ScheduleInfo.SampleData)
}
