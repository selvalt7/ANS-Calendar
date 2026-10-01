//
//  ProfileView.swift
//  ANS Calendar
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var api: VerbisAPI
    @StateObject private var model: ProfileModel

    init(model: ProfileModel = ProfileModel()) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = model.profile {
                    profileList(profile)
                } else if model.isLoading || model.errorMessage == nil {
                    ProgressView("Loading profile")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("Profile unavailable", systemImage: "person.crop.circle")
                    } description: {
                        Text(model.errorMessage ?? "Couldn't load the profile.")
                    } actions: {
                        Button("Try Again") {
                            Task { await model.load(api: api) }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                await model.load(api: api)
            }
            .task {
                await model.load(api: api)
            }
        }
    }

    private func profileList(_ profile: StudentProfile) -> some View {
        List {
            Section {
                VStack(spacing: 12) {
                    profilePhoto
                    Text(profile.name.isEmpty ? "Profile" : profile.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            fieldSection("Personal", fields: profile.personal)
            fieldSection("Studies", fields: profile.studies)
            fieldSection("Addresses", fields: profile.addresses)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var profilePhoto: some View {
        Group {
            if let photo = model.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.rectangle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .foregroundStyle(.secondary)
                    .background(Color(UIColor.secondarySystemFill))
            }
        }
        .frame(width: 96, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Profile photo")
    }

    @ViewBuilder
    private func fieldSection(_ title: String, fields: [ProfileField]) -> some View {
        if !fields.isEmpty {
            Section(title) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(field.value)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

#Preview {
    let model = ProfileModel()
    model.profile = StudentProfile(
        name: "Jan Kowalski",
        photoPath: nil,
        personal: [
            ProfileField(label: "Date of birth", value: "01.01.2000"),
            ProfileField(label: "Gender", value: "Male")
        ],
        studies: [ProfileField(label: "Login", value: "10000")],
        addresses: [ProfileField(label: "Home address", value: "Testowa 1\nKraków")]
    )
    return ProfileView(model: model)
        .environmentObject(VerbisAPI())
}
