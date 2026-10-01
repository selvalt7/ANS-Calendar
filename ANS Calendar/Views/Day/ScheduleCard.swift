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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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

            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func detailBlock(title: String, systemImage: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Label(value, systemImage: systemImage)
                .font(.body)
        }
    }
}

#Preview(traits: .fixedLayout(width: 320, height: 88)) {
    ScheduleCard(schedule: ScheduleInfo.SampleData[1], height: 88) {}
        .padding()
}
