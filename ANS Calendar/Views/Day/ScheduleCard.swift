//
//  ScheduleCard.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI

struct ScheduleCard: View {
    @State private var isShowingSheet = false
    let Schedule: ScheduleInfo
    var startHour: Int
    var startMinute: Int
    var Offset: Double
    var Duration: Double
    var StartDate: Date
    var EndDate: Date
    var Height: Double
    let isExam: Bool
    let groupName: String
    
    init(Schedule: ScheduleInfo) {
        self.Schedule = Schedule
        
        StartDate = Date(timeIntervalSince1970: Double(Schedule.dataRozpoczecia / 1000))
        
        EndDate = Date(timeIntervalSince1970: Double(Schedule.dataZakonczenia / 1000))
        
        startHour = Date().GetDateComponent(Date: StartDate, Component: .hour)
        startMinute = Date().GetDateComponent(Date: StartDate, Component: .minute)
        
        Offset = (Double(startHour - 7) * hourHeight) + ((Double(startMinute) / 60) * hourHeight)
        
        Duration = EndDate.timeIntervalSince(StartDate)
        Height = (Duration / 60 / 60) * hourHeight
        
        isExam = Schedule.grupySprawdzianu.count > 0
        
        if isExam {
            groupName = Schedule.grupySprawdzianu[0].nazwaSkroconaGrupySprawdzianu
        } else {
            groupName = Schedule.grupyZajeciowe[0].nazwaGrupyZajeciowej
        }
    }
    
    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Schedule.GetLessonColor())
                .frame(width: 5)
                .padding(.top, 4)
                .padding(.bottom, 4)
                .frame(minHeight: 0, maxHeight: .infinity)
            VStack() {
                HStack {
                    Text(Schedule.nazwaPelnaPrzedmiotu)
                        .font(.headline)
                    Text(groupName)
                    Spacer()
                }
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(Date(timeIntervalSince1970: Double(Schedule.dataRozpoczecia / 1000)).formatted(date: .omitted, time: .shortened))
                    Text("-")
                    Text(Date(timeIntervalSince1970: Double(Schedule.dataZakonczenia / 1000)).formatted(date: .omitted, time: .shortened))
                    Spacer()
                }
                HStack {
                    Image(systemName: "door.left.hand.open")
                        .foregroundStyle(.secondary)
                    Text(Schedule.sale[0].nazwaSkrocona)
                    Spacer()
                }
                HStack() {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                    Text(Schedule.wykladowcy[0].stopienImieNazwisko)
                    Spacer()
                }
            }
            .frame(height: Height, alignment: .top)
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .frame(height: Height)
        .clipped()
        .background(RoundedRectangle(cornerRadius: 5).fill(Schedule.GetLessonColor()).opacity(0.5))
        .padding(.trailing, 65)
        .offset(x: 60, y: Offset)
        .onTapGesture {
            isShowingSheet.toggle()
        }
        .sheet(isPresented: $isShowingSheet) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(Schedule.nazwaPelnaPrzedmiotu)
                        .font(.title)
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                        .font(.system(size: 20))
                        .opacity(0.8)
                        .onTapGesture {
                            isShowingSheet.toggle()
                        }
                }
                Divider()
                VStack(alignment: .leading) {
                    Text("Room")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    HStack {
                        Image(systemName: "door.left.hand.open")
                            .foregroundStyle(.secondary)
                        Text(Schedule.sale[0].nazwaSkrocona)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Lecturer")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                        Text(Schedule.wykladowcy[0].stopienImieNazwisko)
                    }
                }
                Spacer()
            }
            .padding(20)
            .presentationDetents([.medium])
            .frame(alignment: .top)
        }
    }
}

#Preview(traits: .fixedLayout(width: 400, height: 60)) {
    var Schedule = ScheduleInfo.SampleData[1]
    ScheduleCard(Schedule: Schedule)
}
