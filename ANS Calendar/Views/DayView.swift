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
    let currentDate: Date = Date()
    
    let offset = (Double(Date().GetDateComponent(Date: Date(), Component: .hour) - 6) * hourHeight) + ((Double(Date().GetDateComponent(Date: Date(), Component: .minute)) / 60) * hourHeight)
    
    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(6..<22) { hour in
                        HStack {
                            Text("\(hour):00")
                                .frame(width: 50, height: 2, alignment: .trailing)
                            VStack {
                                Divider()
                            }
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }
                HStack(spacing: 0) {
                    Text("\(currentDate.formatted(date: .omitted, time: .shortened))")
                        .frame(width: 50, height: 20, alignment: .center)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.red))
                        .offset(x: 0)
                        .foregroundStyle(.white)
                    VStack {
                        Rectangle()
                            .fill(.red)
                            .frame(height: 2)
                    }
                }
                .frame(height: hourHeight, alignment: .top)
                .offset(y: -10 + offset)
                .opacity(Calendar.current.isDate(currentDate, equalTo: date, toGranularity: .day) ? 1 : 0)
                
                ForEach(schedules) { schedule in
                    ScheduleCard(Schedule: schedule)
                }
            }
            .padding(.leading, 15)
            .padding(.top, 30)
        }
        .padding(0)
    }
}

#Preview {
    DayView(date: Date(timeIntervalSince1970: Double(1731681900000 / 1000)), schedules: ScheduleInfo.SampleData)
}
