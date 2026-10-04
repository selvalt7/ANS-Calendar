//
//  ScheduleCard.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI

struct ScheduleCard: View {
    let schedule: ScheduleInfo
    let height: CGFloat
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(schedule.GetLessonColor())
                    .frame(width: 3)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(schedule.nazwaPelnaPrzedmiotu)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(height > 56 ? 2 : 1)
                        if !schedule.groupLabel.isEmpty {
                            Text(schedule.groupLabel)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    if height > 40 {
                        Text(schedule.timeRangeLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if height > 68 {
                        detailRow(systemImage: "door.left.hand.open", text: schedule.roomLabel)
                    }

                    if height > 88 {
                        detailRow(systemImage: "person.fill", text: schedule.lecturerLabel)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(schedule.GetLessonColor().opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(schedule.GetLessonColor().opacity(0.85), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func detailRow(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(text)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

struct ScheduleDetailSheet: View {
    let schedule: ScheduleInfo
    @EnvironmentObject private var parking: ParkingModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(schedule.nazwaPelnaPrzedmiotu)
                            .font(.title2.weight(.semibold))
                        if !schedule.groupLabel.isEmpty {
                            Text(schedule.isExam ? "Exam · \(schedule.groupLabel)" : schedule.groupLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                Divider()

                detailBlock(title: "Time", systemImage: "clock", value: schedule.timeRangeLabel)
                detailBlock(title: "Room", systemImage: "door.left.hand.open", value: schedule.roomLabel)
                detailBlock(title: "Lecturer", systemImage: "person.fill", value: schedule.lecturerLabel)
                lectureParking
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var lectureParking: some View {
        if parking.isEnabled {
            if let info = parking.classParking(for: schedule) {
                detailBlock(
                    title: "People",
                    systemImage: "person.3.fill",
                    value: peopleText(info)
                )
                detailBlock(
                    title: "Parking during this class",
                    systemImage: "car.fill",
                    value: parkingText(info)
                )
            } else if parking.isLoading {
                detailBlock(
                    title: "Parking during this class",
                    systemImage: "car.fill",
                    value: "Estimating how many people are on campus…"
                )
            } else if parking.loadError != nil {
                detailBlock(
                    title: "Parking during this class",
                    systemImage: "car.fill",
                    value: "Couldn't estimate parking for this class."
                )
            }
        }
    }

    private func peopleText(_ info: ClassParkingInfo) -> String {
        if let crowd = info.crowd {
            let names = crowd.groups.map { group in
                var parts = ["\(group.name) · \(group.headcount)"]
                if let program = group.program, !program.isEmpty {
                    parts.append(program)
                }
                return parts.joined(separator: " · ")
            }
            let noun = crowd.students == 1 ? "student" : "students"
            let campus = info.moment.studentHeadcount
            let campusNoun = campus == 1 ? "student" : "students"
            let listed = names.joined(separator: "\n")
            if listed.isEmpty {
                return "\(crowd.students) \(noun) in this class\n\(campus) \(campusNoun) estimated on campus"
            }
            return "\(crowd.students) \(noun) in this class\n\(listed)\n\(campus) \(campusNoun) estimated on campus"
        }
        let campus = info.moment.studentHeadcount
        if campus == 0 {
            return "No other groups are estimated on campus then"
        }
        let noun = campus == 1 ? "student" : "students"
        return "\(campus) \(noun) estimated on campus during this class"
    }

    private func parkingText(_ info: ClassParkingInfo) -> String {
        let moment = info.moment
        let capacity = parking.capacity
        let range: String
        if moment.worst.freeSpots == moment.best.freeSpots {
            range = "About \(moment.freeSpots) of \(capacity) free"
        } else {
            let low = min(moment.worst.freeSpots, moment.best.freeSpots)
            let high = max(moment.worst.freeSpots, moment.best.freeSpots)
            range = "About \(low)–\(high) of \(capacity) free"
        }
        let staff = staffLotText(moment, spaces: parking.lecturerCapacity)
        return "\(range)\nWorst case, one student per car · best case, \(ParkingDefaults.bestPeoplePerCar) per car\n\(staff)"
    }

    private func staffLotText(_ moment: ParkingMoment, spaces: Int) -> String {
        if moment.lecturerCars == 0 {
            return spaces == 0 ? "No lecturers on campus" : "No lecturers on campus · staff lot is empty"
        }
        if spaces == 0 {
            let noun = moment.lecturerCars == 1 ? "lecturer parks" : "lecturers park"
            return "No staff lot · \(moment.lecturerCars) \(noun) in the public lot"
        }
        if moment.lecturerPublicCars == 0 {
            let used = min(moment.lecturerCars, spaces)
            return "Staff lot \(used) of \(spaces) used"
        }
        let noun = moment.lecturerPublicCars == 1 ? "lecturer" : "lecturers"
        return "Staff lot full · \(moment.lecturerPublicCars) \(noun) in the public lot"
    }

    private func detailBlock(title: String, systemImage: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Label {
                Text(value)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.body)
        }
    }
}

#Preview(traits: .fixedLayout(width: 320, height: 88)) {
    ScheduleCard(schedule: ScheduleInfo.SampleData[1], height: 88) {}
        .padding()
}
