//
//  ParkingModel.swift
//  ANS Calendar
//

import Foundation

private struct MeetingFetchJob: Sendable {
    let groupID: Int
    let request: URLRequest
}

private enum MeetingFetchOutcome: Sendable {
    case meetings([CampusMeeting])
    case failed
}

private func fetchGroupMeetings(_ job: MeetingFetchJob) async -> MeetingFetchOutcome {
    do {
        let (data, response) = try await URLSession.shared.data(for: job.request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return .failed
        }
        let meetings = try parseGroupMeetings(data: data, groupID: job.groupID)
        return .meetings(meetings)
    } catch {
        return .failed
    }
}

@MainActor
final class ParkingModel: ObservableObject {
    @Published private(set) var groups: [DeanGroup] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published private(set) var fetchedGroupCount = 0
    @Published private(set) var expectedGroupCount = 0
    @Published var capacity: Int {
        didSet {
            let clamped = Self.clampCapacity(capacity)
            if clamped != capacity {
                capacity = clamped
                return
            }
            UserDefaults.standard.set(capacity, forKey: ParkingSettings.capacityKey)
        }
    }
    @Published var driverShare: Double {
        didSet {
            let clamped = Self.clampShare(driverShare)
            if clamped != driverShare {
                driverShare = clamped
                return
            }
            UserDefaults.standard.set(driverShare, forKey: ParkingSettings.driverShareKey)
        }
    }
    @Published var lecturerCapacity: Int {
        didSet {
            let clamped = Self.clampLecturerCapacity(lecturerCapacity)
            if clamped != lecturerCapacity {
                lecturerCapacity = clamped
                return
            }
            UserDefaults.standard.set(lecturerCapacity, forKey: ParkingSettings.lecturerCapacityKey)
        }
    }

    private var meetingsByWeek: [Date: [CampusMeeting]] = [:]
    private var failedByWeek: [Date: Int] = [:]
    private var loadedWeeks = Set<Date>()
    private var groupsSemester: Int?
    private var loadsInFlight = 0
    private var loadGeneration = 0

    init() {
        let storedCapacity = UserDefaults.standard.object(forKey: ParkingSettings.capacityKey) as? Int
        let storedShare = UserDefaults.standard.object(forKey: ParkingSettings.driverShareKey) as? Double
        let storedStaff = UserDefaults.standard.object(forKey: ParkingSettings.lecturerCapacityKey) as? Int
        capacity = Self.clampCapacity(storedCapacity ?? ParkingDefaults.capacity)
        driverShare = Self.clampShare(storedShare ?? ParkingDefaults.driverShare)
        lecturerCapacity = Self.clampLecturerCapacity(storedStaff ?? ParkingDefaults.lecturerCapacity)
    }

    func forecast(on day: Date, now: Date = Date()) -> ParkingForecast? {
        let week = day.startOfWeek()
        guard loadedWeeks.contains(week) else { return nil }
        return makeParkingForecast(
            day: day,
            groups: groups,
            meetings: meetingsByWeek[week] ?? [],
            assumptions: ParkingAssumptions(
                capacity: capacity,
                driverShare: driverShare,
                lecturerCapacity: lecturerCapacity
            ),
            now: now,
            failedGroupFetches: failedByWeek[week] ?? 0
        )
    }

    func load(week: Date, api: VerbisAPI, force: Bool = false) async {
        if api.SemesterID == 0 {
            await api.GetSemesterID()
        }
        let weekStart = week.startOfWeek()
        if !force, api.SemesterID != 0, groupsSemester == api.SemesterID, loadedWeeks.contains(weekStart) {
            return
        }

        loadsInFlight += 1
        isLoading = true
        defer {
            loadsInFlight = max(0, loadsInFlight - 1)
            isLoading = loadsInFlight > 0
        }

        loadGeneration += 1
        let generation = loadGeneration
        loadError = nil
        fetchedGroupCount = 0
        expectedGroupCount = 0

        do {
            if await !api.CheckAuthority() {
                try await api.LoginExistingUser()
            }
            guard api.IsLoggedIn else { return }
            if api.SemesterID == 0 {
                await api.GetSemesterID()
            }
            let semesterID = api.SemesterID
            guard semesterID != 0 else {
                loadError = "Couldn't estimate parking."
                return
            }
            guard generation == loadGeneration else { return }

            if force || groupsSemester != semesterID || groups.isEmpty {
                let loaded = try await fetchDeanGroups(semesterID: semesterID, api: api)
                guard generation == loadGeneration else { return }
                groups = loaded
                groupsSemester = semesterID
            }

            let jobs = groups.map { group in
                MeetingFetchJob(
                    groupID: group.id,
                    request: api.InitAJAXRequest(
                        Service: planowanieService,
                        Method: groupMeetingsMethod,
                        JSONParams: groupMeetingsParams(groupID: group.id, weekStart: weekStart)
                    )
                )
            }
            expectedGroupCount = jobs.count
            fetchedGroupCount = 0
            let collected = await collectMeetings(jobs: jobs, generation: generation)
            guard generation == loadGeneration else { return }

            if !jobs.isEmpty, collected.failed == jobs.count {
                loadError = "Couldn't estimate parking."
                print("Parking: all \(jobs.count) group schedules failed")
                return
            }

            meetingsByWeek[weekStart] = collected.meetings
            failedByWeek[weekStart] = collected.failed
            loadedWeeks.insert(weekStart)
            loadError = nil
            print("Parking: \(jobs.count - collected.failed) of \(jobs.count) groups, \(collected.meetings.count) meetings")
        } catch {
            guard generation == loadGeneration else { return }
            loadError = "Couldn't estimate parking."
            print("Failed to estimate parking: \(error.localizedDescription)")
        }
    }

    /// The portal lists dean groups in two steps: the faculty units under the root,
    /// then the full tree for those units. Each dean group then has its own week of meetings.
    private func fetchDeanGroups(semesterID: Int, api: VerbisAPI) async throws -> [DeanGroup] {
        let rootData = try await post(
            api: api,
            method: semesterGroupsMethod,
            params: rootGroupTreeParams(semesterID: semesterID)
        )
        let unitIDs = try parseOrganizationalUnitIDs(data: rootData)
        guard !unitIDs.isEmpty else { return [] }
        let treeData = try await post(
            api: api,
            method: semesterGroupsMethod,
            params: semesterGroupTreeParams(semesterID: semesterID, unitIDs: unitIDs)
        )
        return try parseDeanGroups(data: treeData)
    }

    private func post(api: VerbisAPI, method: String, params: [String: Any]) async throws -> Data {
        let request = api.InitAJAXRequest(Service: planowanieService, Method: method, JSONParams: params)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ParkingError.badResponse
        }
        return data
    }

    private func collectMeetings(jobs: [MeetingFetchJob], generation: Int) async -> (meetings: [CampusMeeting], failed: Int) {
        var meetings: [CampusMeeting] = []
        var failed = 0
        let limit = 6
        await withTaskGroup(of: MeetingFetchOutcome.self) { group in
            var next = 0
            for _ in 0..<min(limit, jobs.count) {
                let job = jobs[next]
                next += 1
                group.addTask { await fetchGroupMeetings(job) }
            }
            for await outcome in group {
                if generation == loadGeneration {
                    fetchedGroupCount += 1
                    switch outcome {
                    case .meetings(let items):
                        meetings.append(contentsOf: items)
                    case .failed:
                        failed += 1
                    }
                }
                if next < jobs.count {
                    let job = jobs[next]
                    next += 1
                    group.addTask { await fetchGroupMeetings(job) }
                }
            }
        }
        return (meetings, failed)
    }

    private static func clampCapacity(_ value: Int) -> Int {
        min(ParkingDefaults.maximumCapacity, max(ParkingDefaults.minimumCapacity, value))
    }

    private static func clampShare(_ value: Double) -> Double {
        min(1, max(0, value.isFinite ? value : ParkingDefaults.driverShare))
    }

    private static func clampLecturerCapacity(_ value: Int) -> Int {
        min(ParkingDefaults.maximumLecturerCapacity, max(ParkingDefaults.minimumLecturerCapacity, value))
    }
}
