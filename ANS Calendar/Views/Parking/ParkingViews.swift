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
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
        .sheet(isPresented: $showDetail) {
            if let forecast = parking.forecast(on: date) {
                ParkingDetailSheet(forecast: forecast)
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
        return "\(moment.cars) cars · \(moment.studentCars) from students, \(moment.lecturerCars) from lecturers · \(moment.freeSpots) free"
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
            Text("\(hour.moment.freeSpots) free")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .accessibilityLabel("\(hour.hour):00, \(hour.moment.freeSpots) spaces free, \(hour.moment.cars) cars")
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
}
