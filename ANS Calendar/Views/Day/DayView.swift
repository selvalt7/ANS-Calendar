//
//  DayView.swift
//  ANS Calendar
//
//  Created by Stanisław on 19/11/2024.
//

import SwiftUI

let hourHeight = 56.0
let dayStartHour = 7
let dayEndHour = 22

struct DayView: View {
    let date: Date
    let schedules: [ScheduleInfo]
    var isLoading = false
    var statusText: String? = nil
    var onSelect: (ScheduleInfo) -> Void = { _ in }

    private var timelineHeight: CGFloat {
        hourHeight * CGFloat(dayEndHour - dayStartHour)
    }

    var body: some View {
        Color.clear
            .frame(height: timelineHeight)
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    timeline(width: geo.size.width)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
    }

    private func timeline(width: CGFloat) -> some View {
        let placements = timelinePlacements(for: schedules, dayStartHour: dayStartHour, dayEndHour: dayEndHour)
        let gutter: CGFloat = 52
        let available = max(0, width - gutter - 8)

        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(dayStartHour..<dayEndHour, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(hour):00")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                            .offset(y: -7)
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 1)
                    }
                    .frame(height: hourHeight, alignment: .top)
                    .id("hour-\(hour)")
                }
            }

            if schedules.isEmpty {
                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                        Text("Loading schedule")
                    } else {
                        Image(systemName: "calendar")
                            .font(.title3)
                        Text(statusText ?? "No classes")
                            .multilineTextAlignment(.center)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, hourHeight * 2)
                .allowsHitTesting(false)
            }

            ForEach(placements) { placement in
                let columnWidth = available / CGFloat(placement.columnCount)
                let clippedStart = max(placement.startMinutes, dayStartHour * 60)
                let clippedEnd = min(placement.endMinutes, dayEndHour * 60)
                let y = CGFloat(clippedStart - dayStartHour * 60) / 60 * hourHeight
                let height = max(28, CGFloat(clippedEnd - clippedStart) / 60 * hourHeight - 3)

                ScheduleCard(schedule: placement.schedule, height: height) {
                    onSelect(placement.schedule)
                }
                .frame(width: max(0, columnWidth - 4), height: height)
                .offset(x: gutter + CGFloat(placement.column) * columnWidth, y: y)
                .id("event-\(placement.schedule.dataRozpoczecia)-\(placement.column)")
            }

            TimelineView(.periodic(from: .now, by: 30)) { context in
                if date.IsSameDay(date: context.date) {
                    let minutes = context.date.minutesFromMidnight
                    if minutes >= dayStartHour * 60 && minutes <= dayEndHour * 60 {
                        nowIndicator(at: context.date, width: width)
                            .id("now")
                    }
                }
            }
            .frame(width: width, height: timelineHeight, alignment: .topLeading)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: timelineHeight, alignment: .topLeading)
    }

    private func nowIndicator(at time: Date, width: CGFloat) -> some View {
        let y = CGFloat(time.minutesFromMidnight - dayStartHour * 60) / 60 * hourHeight
        return HStack(spacing: 0) {
            Text(time.formatted(date: .omitted, time: .shortened))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(.red))
                .fixedSize()
            Rectangle()
                .fill(.red)
                .frame(height: 1.5)
        }
        .frame(width: width, alignment: .leading)
        .offset(y: y - 8)
    }
}

#Preview {
    ScrollView {
        DayView(date: Date(timeIntervalSince1970: Double(1731681900000) / 1000), schedules: ScheduleInfo.SampleData)
    }
}
