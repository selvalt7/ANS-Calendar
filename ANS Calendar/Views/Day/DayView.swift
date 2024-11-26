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
    @State private var currentDate: Date = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var CurrentTimeOffset = (Double(Date().Hour - 7) * hourHeight) + ((Double(Date().Minute) / 60) * hourHeight)
    
    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .padding(8)
            Divider()
            ScrollView {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(7..<22) { hour in
                            HStack {
                                Text("\(hour):00")
                                    .frame(width: 50, height: 2, alignment: .trailing)
                                    .font(.footnote)
                                    .foregroundStyle(Color.secondary)
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
                    .onReceive(timer) { time in
                        currentDate = time
                        CurrentTimeOffset = (Double(time.Hour - 7) * hourHeight) + ((Double(time.Minute) / 60) * hourHeight)
                    }
                    .frame(height: hourHeight, alignment: .top)
                    .offset(y: -10 + CurrentTimeOffset)
                    .opacity(currentDate.IsSameDay(date: date) && (7...20).contains(currentDate.Hour) ? 1 : 0)
                    
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
}

#Preview {
    DayView(date: Date(timeIntervalSince1970: Double(1731681900000 / 1000)), schedules: ScheduleInfo.SampleData)
}
