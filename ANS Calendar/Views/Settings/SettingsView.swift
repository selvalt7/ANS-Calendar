//
//  SettingsView.swift
//  ANS Calendar
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var api: VerbisAPI
    @EnvironmentObject private var parking: ParkingModel
    @Binding var showPasswordChangeSheet: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Button("Change Password") {
                        showPasswordChangeSheet = true
                    }

                    Button("Logout", role: .destructive) {
                        Task {
                            await api.Logout()
                        }
                    }
                }

                Section {
                    Stepper(
                        value: $parking.capacity,
                        in: ParkingDefaults.minimumCapacity...ParkingDefaults.maximumCapacity,
                        step: 10
                    ) {
                        LabeledContent("Spaces", value: "\(parking.capacity)")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(
                            "Students driving",
                            value: "\(Int((parking.driverShare * 100).rounded()))%"
                        )
                        Slider(value: $parking.driverShare, in: 0...1, step: 0.05)
                    }
                } header: {
                    Text("Parking")
                } footer: {
                    Text("Free spaces are estimated from the published schedules of every dean group. Worst case is one student per car. Best case is three students sharing a car. Set the lot size and the share of students you expect to arrive by car.")
                }

                Section {
                    NavigationLink {
                        DebugSettingsView()
                    } label: {
                        Label("Debug", systemImage: "ladybug")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct DebugSettingsView: View {
    @EnvironmentObject private var api: VerbisAPI

    var body: some View {
        Form {
            Section("Session") {
                labeledValue("Session ID", value: api.JSessionID.isEmpty ? "Empty" : api.JSessionID)
                labeledValue("Student ID", value: String(api.StudentID))
                labeledValue("Tour ID", value: String(api.TourID))
                labeledValue("Semester ID", value: String(api.SemesterID))
            }

            Section {
                Button("Invalidate Session ID", role: .destructive) {
                    api.JSessionID = ""
                    UserDefaults.standard.set("", forKey: "JSessionID")
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeledValue(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView(showPasswordChangeSheet: .constant(false))
        .environmentObject(VerbisAPI())
        .environmentObject(ParkingModel())
}
