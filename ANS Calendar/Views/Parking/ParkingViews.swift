//
//  ParkingViews.swift
//  ANS Calendar
//

import SwiftUI

func parkingTint(_ pressure: ParkingPressure) -> Color {
    switch pressure {
    case .open: return .green
    case .limited: return .orange
    case .full: return .red
    }
}

struct ParkingDayBanner: View {
    @EnvironmentObject private var parking: ParkingModel
    let date: Date
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: parking.isEnabled ? "car.fill" : "car")
                    .foregroundStyle(parking.isEnabled ? Color.accentColor : Color.secondary)
                Text("Parking estimate")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Toggle("Parking estimate", isOn: $parking.isEnabled)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, parking.isEnabled ? 4 : 8)

            if parking.isEnabled {
                if date.IsSameDay(date: Date()) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        content(now: context.date)
                    }
                } else {
                    content(now: Date())
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let forecast = parking.detailedForecast(on: date) {
                ParkingDetailSheet(forecast: forecast)
            }
        }
        .onChange(of: parking.isEnabled) { _, enabled in
            if !enabled {
                showDetail = false
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let forecast = parking.forecast(on: date, now: now) {
            let copy = parkingBannerCopy(forecast: forecast, now: now)
            Button {
                showDetail = true
            } label: {
                card(tint: parkingTint(copy.pressure)) {
                    HStack(spacing: 10) {
                        Image(systemName: "car.fill")
                            .foregroundStyle(parkingTint(copy.pressure))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(bannerSubtitle(copy.subtitle))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(copy.title). \(copy.subtitle)")
            .accessibilityHint("Shows the parking estimate through the day")
        } else if parking.isLoading {
            card(tint: .secondary) {
                HStack(spacing: 10) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estimating parking…")
                            .font(.subheadline.weight(.semibold))
                        Text(loadingDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .accessibilityLabel("Estimating parking")
        } else if parking.loadError != nil {
            card(tint: .secondary) {
                HStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Couldn't estimate parking")
                            .font(.subheadline.weight(.semibold))
                        Text("Pull to refresh and try again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var loadingDetail: String {
        if parking.expectedGroupCount > 0 {
            return "\(parking.fetchedGroupCount) of \(parking.expectedGroupCount) groups"
        }
        return "Loading dean groups"
    }

    private func bannerSubtitle(_ base: String) -> String {
        if let loadError = parking.loadError, !parking.isLoading {
            return loadError
        }
        return base
    }

    private func card(tint: Color, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }
}

struct ParkingDetailSheet: View {
    let forecast: ParkingForecast
    @Environment(\.dismiss) private var dismiss
    @State private var pinnedHour: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(parkingBannerTitle(
                            moment: focus,
                            capacity: forecast.assumptions.capacity,
                            today: pinnedHour == nil && forecast.day.IsSameDay(date: Date())
                        ))
                            .font(.title3.weight(.semibold))
                        Text(headerDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        scenarioLine("Worst case", "One student per car", focus.worst)
                        scenarioLine("Best case", "\(ParkingDefaults.bestPeoplePerCar) students per car", focus.best)
                        Text(staffLotText(focus))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if forecast.failedGroupFetches > 0 {
                            Text("Schedules for \(forecast.failedGroupFetches) groups didn't load, so this can undercount the lot.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Through the day") {
                    ForEach(forecast.hours) { hour in
                        Button {
                            pinnedHour = hour.hour
                        } label: {
                            hourRow(hour)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(focusTitle) {
                    if focus.groups.isEmpty {
                        Text("No dean's group is on campus then.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(focus.groups) { group in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                Text(groupDetail(group))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(lectureLine(group))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("How this is estimated") {
                    Text(parkingAssumptionsText(forecast.assumptions))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Parking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var focus: ParkingMoment {
        if let pinnedHour, let hour = forecast.hours.first(where: { $0.hour == pinnedHour }) {
            return hour.moment
        }
        return parkingFocusMoment(forecast: forecast, now: Date())
    }

    private var highlightedHour: Int {
        Calendar.ans.component(.hour, from: focus.time)
    }

    private var focusTitle: String {
        "On campus at \(parkingTimeText(focus.time))"
    }

    private var headerDetail: String {
        let moment = focus
        if moment.lecturerCars > 0 {
            let noun = moment.lecturerCars == 1 ? "lecturer" : "lecturers"
            return "\(moment.studentHeadcount) students on campus · \(moment.lecturerCars) \(noun)"
        }
        return "\(moment.studentHeadcount) students on campus"
    }

    private func scenarioLine(_ title: String, _ detail: String, _ scenario: ParkingCase) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("\(detail) · \(scenarioSummary(scenario))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func staffLotText(_ moment: ParkingMoment) -> String {
        let spaces = forecast.assumptions.lecturerCapacity
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

    private func scenarioSummary(_ scenario: ParkingCase) -> String {
        let capacity = forecast.assumptions.capacity
        if scenario.cars > capacity {
            return "\(scenario.cars) cars · \(scenario.cars - capacity) over capacity"
        }
        return "\(scenario.cars) cars · \(scenario.freeSpots) free"
    }

    private func hourRow(_ hour: ParkingHour) -> some View {
        let selected = hour.hour == highlightedHour
        return HStack(spacing: 8) {
            Text(String(format: "%d:00", hour.hour))
                .font(.caption.monospacedDigit().weight(selected ? .bold : .regular))
                .frame(width: 44, alignment: .leading)
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(parkingTint(parkingPressure(
                            freeSpots: hour.moment.freeSpots,
                            capacity: forecast.assumptions.capacity
                        )))
                        .scaleEffect(x: fill(for: hour.moment), y: 1, anchor: .leading)
                }
                .frame(height: 8)
            Text(freeLabel(hour.moment))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .accessibilityLabel("\(hour.hour):00, \(freeLabel(hour.moment)), worst \(hour.moment.worst.cars) cars, best \(hour.moment.best.cars) cars")
    }

    private func freeLabel(_ moment: ParkingMoment) -> String {
        if moment.worst.freeSpots == moment.best.freeSpots {
            return "\(moment.freeSpots) free"
        }
        return "\(moment.worst.freeSpots)–\(moment.best.freeSpots) free"
    }

    private func fill(for moment: ParkingMoment) -> CGFloat {
        guard forecast.assumptions.capacity > 0 else { return 1 }
        let fraction = Double(moment.cars) / Double(forecast.assumptions.capacity)
        return CGFloat(min(1, max(0, fraction)))
    }

    private func groupDetail(_ group: PresentGroup) -> String {
        var parts: [String] = []
        if let unit = group.unit, !unit.isEmpty {
            parts.append(unit)
        }
        if let program = group.program, !program.isEmpty {
            parts.append(program)
        }
        parts.append("\(group.headcount) students")
        return parts.joined(separator: " · ")
    }

    private func lectureLine(_ group: PresentGroup) -> String {
        guard let lecture = group.activeClass else {
            return "Between classes, still counted on campus"
        }
        var parts: [String] = []
        let title = lecture.title.trimmingCharacters(in: .whitespacesAndNewlines)
        parts.append(title.isEmpty ? "In class" : title)
        let room = lecture.room.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty, room != "No room" {
            parts.append(room)
        }
        parts.append("\(parkingTimeText(lecture.start))–\(parkingTimeText(lecture.end))")
        return parts.joined(separator: " · ")
    }
}
