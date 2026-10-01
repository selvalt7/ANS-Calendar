//
//  GradesView.swift
//  ANS Calendar
//

import SwiftUI

struct GradesView: View {
    @EnvironmentObject private var api: VerbisAPI
    @StateObject private var model: GradesModel

    @MainActor
    init(model: GradesModel? = nil) {
        _model = StateObject(wrappedValue: model ?? GradesModel())
    }

    var body: some View {
        NavigationStack {
            Group {
                if let progress = model.progress {
                    gradesList(progress)
                } else if model.isLoading || model.errorMessage == nil {
                    ProgressView("Loading grades")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("Grades unavailable", systemImage: "graduationcap")
                    } description: {
                        Text(model.errorMessage ?? "Couldn't load grades.")
                    } actions: {
                        Button("Try Again") {
                            Task { await model.load(api: api) }
                        }
                    }
                }
            }
            .navigationTitle("Grades")
            .refreshable {
                await model.load(api: api)
            }
            .task {
                await model.load(api: api)
            }
        }
    }

    private func gradesList(_ progress: AcademicProgress) -> some View {
        List {
            if let latest = progress.latest {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(latest.termTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(latest.cumulativeAverage ?? latest.semesterAverage ?? "—")
                            .font(.largeTitle.weight(.semibold).monospacedDigit())
                            .textSelection(.enabled)
                        Text("Cumulative ECTS \(latest.cumulativeECTS.passedOfEnrolled)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
            }

            Section("Semesters") {
                ForEach(progress.newestFirst) { semester in
                    NavigationLink {
                        SemesterGradesView(semester: semester)
                    } label: {
                        SemesterGradeRow(semester: semester)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct SemesterGradeRow: View {
    let semester: StudySemester

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(semester.termTitle)
                    .font(.headline)
                if !semester.listSubtitle.isEmpty {
                    Text(semester.listSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("ECTS \(semester.ects.passedOfEnrolled)")
                    .font(.caption)
                    .foregroundStyle(semester.ects.parts.count >= 3 && !creditLooksClear(semester.ects.parts[2]) ? Color.orange : Color.secondary)
            }
            Spacer(minLength: 8)
            Text(semester.listAverage)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(semester.semesterAverage == nil ? Color.secondary : Color.primary)
        }
        .padding(.vertical, 4)
    }
}

struct SemesterGradesView: View {
    let semester: StudySemester

    var body: some View {
        List {
            Section {
                if let program = semester.program {
                    Text(program)
                        .font(.headline)
                }
                labeled("Status", semester.status)
                labeled("Stage", semester.stage)
                labeled("Dean's group", semester.deanGroup)
                labeled("Track", semester.trackTitle)
                if let advisor = semester.advisor {
                    labeled("Advisor", advisor)
                }
            }

            Section("Results") {
                if let average = semester.semesterAverage {
                    labeled("Semester average", average)
                }
                if let yearly = semester.yearlyAverage {
                    labeled("Yearly average", yearly)
                }
                if let cumulative = semester.cumulativeAverage {
                    labeled("Cumulative average", cumulative)
                }
                labeled("ECTS", semester.ects.passedOfEnrolled)
                labeled("Cumulative ECTS", semester.cumulativeECTS.passedOfEnrolled)
                labeled("Hours", semester.hours.passedOfEnrolled)
                if !semester.costUnits.display.isEmpty {
                    labeled("Cost units", semester.costUnits.display)
                }
            }

            Section("Courses") {
                if semester.courses.isEmpty {
                    Text("No courses")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(semester.courses) { course in
                        NavigationLink {
                            CourseGradeView(course: course)
                        } label: {
                            CourseGradeRow(course: course)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(semester.termTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct CourseGradeRow: View {
    let course: CourseGrade

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.body)
                if !course.listMeta.isEmpty {
                    Text(course.listMeta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(course.displayGrade)
                .font(.headline.monospacedDigit())
                .foregroundStyle(gradeColor(course))
        }
        .padding(.vertical, 4)
    }
}

struct CourseGradeView: View {
    let course: CourseGrade

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.name)
                        .font(.title3.bold())
                        .textSelection(.enabled)
                    Text(course.displayGrade)
                        .font(.largeTitle.weight(.semibold).monospacedDigit())
                        .foregroundStyle(gradeColor(course))
                        .textSelection(.enabled)
                    if course.isExam {
                        Text("Exam")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Section("Course") {
                if !course.catalogNumber.isEmpty {
                    labeled("Catalog number", course.catalogNumber)
                }
                if let coordinator = course.coordinator {
                    labeled("Coordinator", coordinator)
                }
                if !course.ects.isEmpty {
                    labeled("ECTS", course.ectsPending ? "\(course.ects) planned" : course.ects)
                }
                if !course.hours.isEmpty {
                    labeled("Hours", course.hoursPending ? "\(course.hours) planned" : course.hours)
                }
                if !course.costUnits.isEmpty {
                    labeled("Cost units", course.costUnits)
                }
            }

            if !course.attempts.isEmpty {
                Section("Sittings") {
                    ForEach(Array(course.attempts.enumerated()), id: \.offset) { _, attempt in
                        VStack(alignment: .leading, spacing: 2) {
                            if let context = attempt.context {
                                Text(context)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(attempt.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(attempt.valueText)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !course.hourBreakdown.isEmpty {
                Section("Hours") {
                    ForEach(Array(course.hourBreakdown.enumerated()), id: \.offset) { _, component in
                        LabeledContent(component.title, value: component.hours)
                    }
                }
            }

            if !course.groups.isEmpty {
                Section("Groups") {
                    ForEach(Array(course.groups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.code)
                                .font(.body.weight(.medium))
                            if !group.lecturers.isEmpty {
                                Text(group.lecturers.joined(separator: "\n"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Course")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}

private func gradeColor(_ course: CourseGrade) -> Color {
    if course.isUnsatisfactory { return .red }
    if course.isPending { return .secondary }
    return .primary
}

private func creditLooksClear(_ token: String) -> Bool {
    Double(token.replacingOccurrences(of: ",", with: ".")) == 0
}

#Preview {
    let model = GradesModel()
    model.progress = AcademicProgress(semesters: [
        StudySemester(
            id: "1",
            term: "2024 Z",
            termTitle: "Winter 2024",
            studySemester: "1",
            trackTitle: "Winter 2024",
            stage: "Engineer",
            status: "Registered",
            ects: CreditTriple(parts: ["30", "30", "0"]),
            cumulativeECTS: CreditTriple(parts: ["30", "30", "0"]),
            hours: CreditTriple(parts: ["60", "60", "0"]),
            costUnits: CreditTriple(parts: ["6", "0"]),
            semesterAverage: "4,50",
            yearlyAverage: nil,
            cumulativeAverage: "4,50",
            deanGroup: "IT1.1",
            program: "Informatyka testowa IT1.1",
            advisor: nil,
            courses: [
                CourseGrade(
                    id: "instancja100",
                    catalogNumber: "IE.TEST.1",
                    name: "Algorytmy",
                    coordinator: "A - dr Anna Nowak",
                    grade: "5,0",
                    isPending: false,
                    isUnsatisfactory: false,
                    attempts: [GradeAttempt(context: nil, label: "Final grade", grade: "5,0", date: "03.02.2025")],
                    ects: "4",
                    ectsPending: false,
                    hours: "60",
                    hoursPending: false,
                    hourBreakdown: [HourComponent(code: "W", hours: "30"), HourComponent(code: "CL", hours: "30")],
                    costUnits: "4",
                    groups: [CourseGroup(code: "W1", lecturers: ["dr Anna Nowak"])],
                    isExam: true
                )
            ]
        )
    ])
    return GradesView(model: model)
        .environmentObject(VerbisAPI())
}
