//
//  Parking.swift
//  ANS Calendar
//

import Foundation

let organizationalUnitClassName = "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO"
let planowanieService = "Planowanie"
let semesterGroupsMethod = "getGrupySemestralneSemestru"
let groupMeetingsMethod = "getOpublikowaneSpotkaniaGrupy"

enum ParkingDefaults {
    static let capacity = 120
    static let driverShare = 0.4
    static let minimumCapacity = 20
    static let maximumCapacity = 400
    static let arrivalLead: TimeInterval = 20 * 60
    static let departureLag: TimeInterval = 15 * 60
    /// One student per car: the fullest the lot gets for this many drivers.
    static let worstPeoplePerCar = 1
    /// Three students sharing a car: the most space that carpooling would free.
    static let bestPeoplePerCar = 3
    /// Staff lot. Lecturers park here first; overflow uses the public lot.
    static let lecturerCapacity = 30
    static let minimumLecturerCapacity = 0
    static let maximumLecturerCapacity = 200
}

enum ParkingSettings {
    static let enabledKey = "ParkingEstimateEnabled"
    static let capacityKey = "ParkingCapacity"
    static let driverShareKey = "ParkingDriverShare"
    static let lecturerCapacityKey = "ParkingLecturerCapacity"
}

enum ParkingError: Error, Equatable, LocalizedError {
    case badResponse
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "The planning service returned an unexpected response."
        case .unavailable(let message):
            return message
        }
    }
}

enum ParkingPressure: Equatable {
    case open
    case limited
    case full
}

struct ParkingAssumptions: Equatable {
    var capacity: Int
    var driverShare: Double
    var lecturerCapacity: Int = ParkingDefaults.lecturerCapacity
    var arrivalLead: TimeInterval = ParkingDefaults.arrivalLead
    var departureLag: TimeInterval = ParkingDefaults.departureLag
}

struct DeanGroup: Identifiable, Equatable {
    let id: Int
    let name: String
    let headcount: Int
    let program: String?
    let unit: String?
}

struct CampusMeeting: Equatable, Sendable {
    let groupID: Int
    let start: Date
    let end: Date
    let onCampus: Bool
    let lecturerIDs: [Int]
    let subject: String
    let room: String
}

struct ActiveClass: Equatable {
    let title: String
    let room: String
    let start: Date
    let end: Date
}

struct PresentGroup: Identifiable, Equatable {
    let id: Int
    let name: String
    let unit: String?
    let program: String?
    let headcount: Int
    let activeClass: ActiveClass?
}

struct LectureCrowd: Equatable {
    let students: Int
    let groups: [DeanGroup]
}

struct ClassParkingInfo: Equatable {
    let moment: ParkingMoment
    let crowd: LectureCrowd?
}

struct ParkingCase: Equatable {
    let peoplePerCar: Int
    let studentCars: Int
    let cars: Int
    let freeSpots: Int
}

struct ParkingMoment: Equatable {
    let time: Date
    /// Worst case for the public lot: one student per car, plus lecturers who did not fit in the staff lot.
    let cars: Int
    let freeSpots: Int
    let studentHeadcount: Int
    let studentCars: Int
    /// Lecturers teaching on campus.
    let lecturerCars: Int
    /// Lecturers parked in the public lot after the staff lot filled up.
    let lecturerPublicCars: Int
    let groups: [PresentGroup]
    let worst: ParkingCase
    let best: ParkingCase
}

struct ParkingHour: Identifiable, Equatable {
    let hour: Int
    let moment: ParkingMoment

    var id: Int { hour }
}

struct ParkingForecast: Equatable {
    let day: Date
    let assumptions: ParkingAssumptions
    let hours: [ParkingHour]
    let peak: ParkingMoment
    let current: ParkingMoment?
    let groupsWithClasses: Int
    let consideredGroupCount: Int
    let failedGroupFetches: Int
}

struct ParkingBannerCopy: Equatable {
    let title: String
    let subtitle: String
    let pressure: ParkingPressure
}

func ajaxRequestBody(service: String, method: String, params: [String: Any]) -> Data {
    let body: [String: Any] = [
        "service": service,
        "method": method,
        "params": params
    ]
    return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
}

func rootGroupTreeParams(semesterID: Int) -> [String: Any] {
    [
        "idSemestru": semesterID,
        "cyklRoczny": false,
        "itemIdList": ["r0"]
    ]
}

func organizationalUnitItem(id: Int) -> [String: Any] {
    [
        "_class": organizationalUnitClassName,
        "idJednostki": id
    ]
}

func semesterGroupTreeParams(semesterID: Int, unitIDs: [Int]) -> [String: Any] {
    [
        "idSemestru": semesterID,
        "cyklRoczny": false,
        "itemIdList": unitIDs.map { organizationalUnitItem(id: $0) }
    ]
}

func groupMeetingsParams(groupID: Int, weekStart: Date) -> [String: Any] {
    [
        "idGrupyDziekanskiej": groupID,
        "poczatekTygodnia": weekStartMilliseconds(weekStart)
    ]
}

func weekStartMilliseconds(_ date: Date) -> Int {
    Int((date.startOfWeek().timeIntervalSince1970 * 1000).rounded())
}

func parseDeanGroupLabel(_ label: String) -> (name: String, headcount: Int?) {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let match = trimmed.firstMatch(of: /^(.+?):\s*(\d+)\s*$/),
          let count = Int(match.2) else {
        return (trimmed, nil)
    }
    let name = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
    return (name.isEmpty ? trimmed : name, count)
}

func roomIsRemote(_ name: String) -> Bool {
    let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
    let markers = ["zdaln", "online", "e-learning", "elearning", "teams", "zoom", "remote", "wirtual"]
    return markers.contains { folded.contains($0) }
}

func meetingIsOnCampus(_ schedule: ScheduleInfo) -> Bool {
    if schedule.sale.isEmpty { return true }
    return schedule.sale.contains { !roomIsRemote($0.nazwaSkrocona) }
}

func parseOrganizationalUnitIDs(data: Data) throws -> [Int] {
    let json = try jsonDictionary(from: data)
    if let error = planowanieError(in: json) {
        throw error
    }
    var ids: [Int] = []
    var seen = Set<Int>()
    for item in returnedItems(in: json) {
        collectOrganizationalUnitIDs(item, into: &ids, seen: &seen)
    }
    return ids
}

func parseDeanGroups(data: Data) throws -> [DeanGroup] {
    let json = try jsonDictionary(from: data)
    if let error = planowanieError(in: json) {
        throw error
    }
    var groups: [DeanGroup] = []
    var seen = Set<Int>()
    for item in returnedItems(in: json) {
        collectDeanGroups(item, unit: nil, into: &groups, seen: &seen)
    }
    return groups
}

func parseGroupMeetings(data: Data, groupID: Int) throws -> [CampusMeeting] {
    let json = try jsonDictionary(from: data)
    if let error = planowanieError(in: json) {
        throw error
    }
    let items = returnedItems(in: json)
    var meetings: [CampusMeeting] = []
    for item in items {
        guard let dictionary = item as? [String: Any],
              JSONSerialization.isValidJSONObject(dictionary),
              let itemData = try? JSONSerialization.data(withJSONObject: dictionary),
              let schedule = try? JSONDecoder().decode(ScheduleInfo.self, from: itemData) else {
            continue
        }
        meetings.append(CampusMeeting(
            groupID: groupID,
            start: schedule.startDate,
            end: schedule.endDate,
            onCampus: meetingIsOnCampus(schedule),
            lecturerIDs: schedule.wykladowcy.map(\.idProwadzacego),
            subject: schedule.nazwaPelnaPrzedmiotu,
            room: schedule.roomLabel
        ))
    }
    if !items.isEmpty, meetings.isEmpty {
        throw ParkingError.badResponse
    }
    return meetings
}

func parkingPressure(freeSpots: Int, capacity: Int) -> ParkingPressure {
    guard capacity > 0, freeSpots > 0 else { return .full }
    let remaining = Double(freeSpots) / Double(capacity)
    if remaining >= 0.4 { return .open }
    if remaining >= 0.15 { return .limited }
    return .full
}

func parkingTimeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.calendar = .ans
    formatter.timeZone = Calendar.ans.timeZone
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

func parkingFocusMoment(forecast: ParkingForecast, now: Date) -> ParkingMoment {
    if forecast.day.IsSameDay(date: now), let current = forecast.current {
        return current
    }
    return forecast.peak
}

func parkingBannerCopy(forecast: ParkingForecast, now: Date) -> ParkingBannerCopy {
    if forecast.consideredGroupCount == 0 {
        return ParkingBannerCopy(
            title: "No parking estimate",
            subtitle: "No dean groups for this semester.",
            pressure: .open
        )
    }
    if forecast.groupsWithClasses == 0 {
        var subtitle = "No on-campus classes that day"
        if forecast.failedGroupFetches > 0 {
            subtitle += " · \(forecast.failedGroupFetches) groups missing"
        }
        return ParkingBannerCopy(
            title: "Parking looks open",
            subtitle: subtitle,
            pressure: .open
        )
    }

    let moment = parkingFocusMoment(forecast: forecast, now: now)
    let today = forecast.day.IsSameDay(date: now)
    var subtitle: String
    if today, forecast.peak.cars > moment.cars {
        let time = parkingTimeText(forecast.peak.time)
        subtitle = "Busiest around \(time) · \(parkingFreeText(forecast.peak, capacity: forecast.assumptions.capacity))"
    } else {
        subtitle = parkingCarText(moment)
    }
    if forecast.failedGroupFetches > 0 {
        subtitle += " · \(forecast.failedGroupFetches) groups missing"
    }

    return ParkingBannerCopy(
        title: parkingBannerTitle(moment: moment, capacity: forecast.assumptions.capacity, today: today),
        subtitle: subtitle,
        pressure: parkingPressure(freeSpots: moment.freeSpots, capacity: forecast.assumptions.capacity)
    )
}

func parkingAssumptionsText(_ assumptions: ParkingAssumptions) -> String {
    let percent = Int((min(1, max(0, assumptions.driverShare)) * 100).rounded())
    let arrive = Int((assumptions.arrivalLead / 60).rounded())
    let leave = Int((assumptions.departureLag / 60).rounded())
    let staff = assumptions.lecturerCapacity
    let staffSentence = staff == 0
        ? "There is no staff lot, so lecturers park in the public lot."
        : "Lecturers park in a staff lot of \(staff) spaces first. When that lot is full, extra lecturers use the public lot."
    return "People in a dean's group are counted from \(arrive) minutes before their first class until \(leave) minutes after their last class, including the gap between classes. The group size is the number after the group name. \(percent)% of those students are assumed to come by car. Worst case is one student per car. Best case is \(ParkingDefaults.bestPeoplePerCar) students sharing a car. \(staffSentence) Online classes are left out. The public lot has \(assumptions.capacity) spaces, which you can change in Settings."
}

func parkingFreeText(_ moment: ParkingMoment, capacity: Int) -> String {
    if moment.worst.freeSpots == 0, moment.best.freeSpots == 0 {
        return "full"
    }
    if moment.worst.freeSpots == moment.best.freeSpots {
        return "\(moment.freeSpots) of \(capacity) free"
    }
    return "\(moment.worst.freeSpots)–\(moment.best.freeSpots) of \(capacity) free"
}

func parkingCarText(_ moment: ParkingMoment) -> String {
    let people = "\(moment.studentHeadcount) students"
    let lecturers = lecturerParkingText(moment)
    if moment.worst.cars == moment.best.cars {
        return "\(moment.cars) cars · \(people)\(lecturers)"
    }
    return "Worst \(moment.worst.cars) cars · best \(moment.best.cars) · \(people)\(lecturers)"
}

func lecturerParkingText(_ moment: ParkingMoment) -> String {
    if moment.lecturerCars == 0 { return "" }
    if moment.lecturerPublicCars == 0 {
        return " · lecturers in the staff lot"
    }
    let noun = moment.lecturerPublicCars == 1 ? "lecturer" : "lecturers"
    return ", \(moment.lecturerPublicCars) \(noun) in the public lot"
}

func lecturerPublicCars(onCampus: Int, privateSpaces: Int) -> Int {
    max(0, onCampus - max(0, privateSpaces))
}

func makeParkingForecast(
    day: Date,
    groups: [DeanGroup],
    meetings: [CampusMeeting],
    assumptions: ParkingAssumptions,
    now: Date,
    failedGroupFetches: Int = 0,
    fromHour: Int = dayStartHour,
    toHour: Int = dayEndHour,
    includeAttendance: Bool = true
) -> ParkingForecast {
    let stays = campusStays(on: day, groups: groups, meetings: meetings, assumptions: assumptions)
    let points = occupancyPoints(from: stays)
    let meetingsByGroup = includeAttendance ? indexMeetings(meetings) : [:]

    var hours: [ParkingHour] = []
    for hour in fromHour..<toHour {
        guard let time = busiestTime(on: day, hour: hour, points: points, assumptions: assumptions) else { continue }
        hours.append(ParkingHour(
            hour: hour,
            moment: moment(
                at: time,
                stays: stays,
                points: points,
                meetingsByGroup: meetingsByGroup,
                assumptions: assumptions,
                includeAttendance: includeAttendance
            )
        ))
    }

    let peak = hours.max(by: { $0.moment.cars < $1.moment.cars })?.moment
        ?? moment(
            at: day.startOfDay,
            stays: stays,
            points: points,
            meetingsByGroup: meetingsByGroup,
            assumptions: assumptions,
            includeAttendance: includeAttendance
        )
    let current = now.IsSameDay(date: day)
        ? moment(
            at: now,
            stays: stays,
            points: points,
            meetingsByGroup: meetingsByGroup,
            assumptions: assumptions,
            includeAttendance: includeAttendance
        )
        : nil

    return ParkingForecast(
        day: day.startOfDay,
        assumptions: assumptions,
        hours: hours,
        peak: peak,
        current: current,
        groupsWithClasses: stays.filter { $0.group != nil }.count,
        consideredGroupCount: groups.count,
        failedGroupFetches: failedGroupFetches
    )
}

private struct CampusStay {
    let start: Date
    let end: Date
    let headcount: Int
    let group: DeanGroup?
    let lecturerID: Int?

    func contains(_ time: Date) -> Bool {
        start <= time && time < end
    }
}

private func campusStays(
    on day: Date,
    groups: [DeanGroup],
    meetings: [CampusMeeting],
    assumptions: ParkingAssumptions
) -> [CampusStay] {
    let onCampus = meetings.filter { meeting in
        meeting.onCampus && meeting.end > meeting.start && meeting.start.IsSameDay(date: day)
    }
    var groupsByID: [Int: DeanGroup] = [:]
    for group in groups {
        groupsByID[group.id] = group
    }

    var stays: [CampusStay] = []
    for (groupID, groupMeetings) in Dictionary(grouping: onCampus, by: \.groupID) {
        guard let first = groupMeetings.map(\.start).min(),
              let last = groupMeetings.map(\.end).max() else { continue }
        let group = groupsByID[groupID] ?? DeanGroup(
            id: groupID,
            name: "Group \(groupID)",
            headcount: 0,
            program: nil,
            unit: nil
        )
        stays.append(CampusStay(
            start: first.addingTimeInterval(-assumptions.arrivalLead),
            end: last.addingTimeInterval(assumptions.departureLag),
            headcount: max(0, group.headcount),
            group: group,
            lecturerID: nil
        ))
    }

    var byLecturer: [Int: [CampusMeeting]] = [:]
    for meeting in onCampus {
        for lecturerID in Set(meeting.lecturerIDs) where lecturerID != 0 {
            byLecturer[lecturerID, default: []].append(meeting)
        }
    }
    for (lecturerID, lecturerMeetings) in byLecturer {
        guard let first = lecturerMeetings.map(\.start).min(),
              let last = lecturerMeetings.map(\.end).max() else { continue }
        stays.append(CampusStay(
            start: first.addingTimeInterval(-assumptions.arrivalLead),
            end: last.addingTimeInterval(assumptions.departureLag),
            headcount: 0,
            group: nil,
            lecturerID: lecturerID
        ))
    }
    return stays
}

private struct OccupancyPoint {
    let time: Date
    let headcount: Int
    let lecturerCars: Int
}

private struct OccupancyEvent {
    let time: Date
    let headcountDelta: Int
    let lecturerDelta: Int
    let closesStay: Bool
}

/// Occupancy only changes when someone arrives or leaves, so the day is a sorted list of those instants.
private func occupancyPoints(from stays: [CampusStay]) -> [OccupancyPoint] {
    var events: [OccupancyEvent] = []
    events.reserveCapacity(stays.count * 2)
    for stay in stays {
        let lecturerDelta = stay.lecturerID == nil ? 0 : 1
        let headcountDelta = stay.group == nil ? 0 : stay.headcount
        events.append(OccupancyEvent(time: stay.start, headcountDelta: headcountDelta, lecturerDelta: lecturerDelta, closesStay: false))
        events.append(OccupancyEvent(time: stay.end, headcountDelta: -headcountDelta, lecturerDelta: -lecturerDelta, closesStay: true))
    }
    events.sort { lhs, rhs in
        if lhs.time != rhs.time { return lhs.time < rhs.time }
        if lhs.closesStay != rhs.closesStay { return lhs.closesStay }
        return false
    }

    var points: [OccupancyPoint] = []
    points.reserveCapacity(events.count)
    var headcount = 0
    var lecturerCars = 0
    var index = 0
    while index < events.count {
        let time = events[index].time
        while index < events.count, events[index].time == time {
            headcount += events[index].headcountDelta
            lecturerCars += events[index].lecturerDelta
            index += 1
        }
        points.append(OccupancyPoint(time: time, headcount: headcount, lecturerCars: lecturerCars))
    }
    return points
}

private func occupancy(at time: Date, points: [OccupancyPoint]) -> (headcount: Int, lecturerCars: Int) {
    var headcount = 0
    var lecturerCars = 0
    for point in points {
        if point.time > time { break }
        headcount = point.headcount
        lecturerCars = point.lecturerCars
    }
    return (headcount, lecturerCars)
}

private func worstCars(headcount: Int, lecturerCars: Int, assumptions: ParkingAssumptions) -> Int {
    parkingCase(
        headcount: headcount,
        lecturerPublicCars: lecturerPublicCars(onCampus: lecturerCars, privateSpaces: assumptions.lecturerCapacity),
        capacity: max(0, assumptions.capacity),
        driverShare: assumptions.driverShare,
        peoplePerCar: ParkingDefaults.worstPeoplePerCar
    ).cars
}

private func indexMeetings(_ meetings: [CampusMeeting]) -> [Int: [CampusMeeting]] {
    var indexed: [Int: [CampusMeeting]] = [:]
    for meeting in meetings where meeting.onCampus {
        indexed[meeting.groupID, default: []].append(meeting)
    }
    return indexed
}

private func moment(
    at time: Date,
    stays: [CampusStay],
    points: [OccupancyPoint],
    meetingsByGroup: [Int: [CampusMeeting]],
    assumptions: ParkingAssumptions,
    includeAttendance: Bool
) -> ParkingMoment {
    if includeAttendance {
        return parkingSnapshot(at: time, stays: stays, meetingsByGroup: meetingsByGroup, assumptions: assumptions)
    }
    let present = occupancy(at: time, points: points)
    return makeMoment(
        at: time,
        headcount: present.headcount,
        lecturerCars: present.lecturerCars,
        groups: [],
        assumptions: assumptions
    )
}

private func parkingSnapshot(
    at time: Date,
    stays: [CampusStay],
    meetingsByGroup: [Int: [CampusMeeting]],
    assumptions: ParkingAssumptions
) -> ParkingMoment {
    var headcount = 0
    var groups: [PresentGroup] = []
    var lecturers = Set<Int>()
    for stay in stays where stay.contains(time) {
        if let group = stay.group {
            headcount += stay.headcount
            if stay.headcount > 0 {
                groups.append(PresentGroup(
                    id: group.id,
                    name: group.name,
                    unit: group.unit,
                    program: group.program,
                    headcount: stay.headcount,
                    activeClass: activeClass(for: group.id, at: time, meetingsByGroup: meetingsByGroup)
                ))
            }
        }
        if let lecturerID = stay.lecturerID {
            lecturers.insert(lecturerID)
        }
    }
    groups.sort { lhs, rhs in
        if lhs.headcount == rhs.headcount { return lhs.name < rhs.name }
        return lhs.headcount > rhs.headcount
    }
    return makeMoment(
        at: time,
        headcount: headcount,
        lecturerCars: lecturers.count,
        groups: groups,
        assumptions: assumptions
    )
}

private func makeMoment(
    at time: Date,
    headcount: Int,
    lecturerCars: Int,
    groups: [PresentGroup],
    assumptions: ParkingAssumptions
) -> ParkingMoment {
    let capacity = max(0, assumptions.capacity)
    let publicLecturers = lecturerPublicCars(onCampus: lecturerCars, privateSpaces: assumptions.lecturerCapacity)
    let worst = parkingCase(
        headcount: headcount,
        lecturerPublicCars: publicLecturers,
        capacity: capacity,
        driverShare: assumptions.driverShare,
        peoplePerCar: ParkingDefaults.worstPeoplePerCar
    )
    let best = parkingCase(
        headcount: headcount,
        lecturerPublicCars: publicLecturers,
        capacity: capacity,
        driverShare: assumptions.driverShare,
        peoplePerCar: ParkingDefaults.bestPeoplePerCar
    )
    return ParkingMoment(
        time: time,
        cars: worst.cars,
        freeSpots: worst.freeSpots,
        studentHeadcount: headcount,
        studentCars: worst.studentCars,
        lecturerCars: lecturerCars,
        lecturerPublicCars: publicLecturers,
        groups: groups,
        worst: worst,
        best: best
    )
}

func parkingCase(
    headcount: Int,
    lecturerPublicCars: Int,
    capacity: Int,
    driverShare: Double,
    peoplePerCar: Int
) -> ParkingCase {
    let riders = Double(max(0, headcount)) * min(1, max(0, driverShare))
    let perCar = Double(max(peoplePerCar, 1))
    let studentCars = Int((riders / perCar).rounded(.toNearestOrAwayFromZero))
    let cars = studentCars + max(0, lecturerPublicCars)
    return ParkingCase(
        peoplePerCar: max(peoplePerCar, 1),
        studentCars: studentCars,
        cars: cars,
        freeSpots: max(0, max(0, capacity) - cars)
    )
}

private func busiestTime(
    on day: Date,
    hour: Int,
    points: [OccupancyPoint],
    assumptions: ParkingAssumptions
) -> Date? {
    guard let hourStart = dateOn(day, hour: hour, minute: 0),
          let hourEnd = dateOn(day, hour: hour + 1, minute: 0) else { return nil }
    let opening = occupancy(at: hourStart, points: points)
    var bestTime = hourStart
    var bestCars = worstCars(headcount: opening.headcount, lecturerCars: opening.lecturerCars, assumptions: assumptions)
    for point in points where point.time >= hourStart && point.time < hourEnd {
        let count = worstCars(headcount: point.headcount, lecturerCars: point.lecturerCars, assumptions: assumptions)
        if count > bestCars {
            bestCars = count
            bestTime = point.time
        }
    }
    return bestTime
}

private func activeClass(for groupID: Int, at time: Date, meetingsByGroup: [Int: [CampusMeeting]]) -> ActiveClass? {
    guard let meetings = meetingsByGroup[groupID] else { return nil }
    let current = meetings
        .filter { $0.start <= time && time < $0.end }
        .max { $0.start < $1.start }
    guard let current else { return nil }
    return ActiveClass(title: current.subject, room: current.room, start: current.start, end: current.end)
}

func classParkingInfo(
    for schedule: ScheduleInfo,
    day: Date,
    groups: [DeanGroup],
    meetings: [CampusMeeting],
    assumptions: ParkingAssumptions
) -> ClassParkingInfo {
    let stays = campusStays(on: day, groups: groups, meetings: meetings, assumptions: assumptions)
    let points = occupancyPoints(from: stays)
    let meetingsByGroup = indexMeetings(meetings)
    let start = schedule.startDate
    let windowEnd = max(schedule.endDate, start.addingTimeInterval(60))
    let opening = occupancy(at: start, points: points)
    var bestTime = start
    var bestCars = worstCars(headcount: opening.headcount, lecturerCars: opening.lecturerCars, assumptions: assumptions)
    for point in points where point.time >= start && point.time < windowEnd {
        let count = worstCars(headcount: point.headcount, lecturerCars: point.lecturerCars, assumptions: assumptions)
        if count > bestCars {
            bestCars = count
            bestTime = point.time
        }
    }
    return ClassParkingInfo(
        moment: parkingSnapshot(at: bestTime, stays: stays, meetingsByGroup: meetingsByGroup, assumptions: assumptions),
        crowd: lectureCrowd(for: schedule, groups: groups, meetings: meetings)
    )
}

func lectureCrowd(for schedule: ScheduleInfo, groups: [DeanGroup], meetings: [CampusMeeting]) -> LectureCrowd? {
    let windowStart = schedule.startDate
    let windowEnd = schedule.endDate
    let overlapping = meetings.filter { meeting in
        meeting.onCampus && meeting.end > windowStart && meeting.start < windowEnd
    }
    let subject = normalizedLabel(schedule.nazwaPelnaPrzedmiotu)
    let room = normalizedRoom(schedule.roomLabel)
    let subjectMatches = overlapping.filter { subjectsMatch($0.subject, subject) }
    let roomMatches = room.isEmpty ? [] : overlapping.filter { normalizedRoom($0.room) == room }
    let subjectAndRoom = subjectMatches.filter { normalizedRoom($0.room) == room && !room.isEmpty }
    let matchedIDs: Set<Int>
    if !subjectAndRoom.isEmpty {
        matchedIDs = Set(subjectAndRoom.map(\.groupID))
    } else if room.isEmpty, !subjectMatches.isEmpty {
        matchedIDs = Set(subjectMatches.map(\.groupID))
    } else if !roomMatches.isEmpty {
        matchedIDs = Set(roomMatches.map(\.groupID))
    } else if subjectMatches.count == 1 {
        matchedIDs = Set(subjectMatches.map(\.groupID))
    } else {
        matchedIDs = []
    }
    let matched = groups.filter { matchedIDs.contains($0.id) && $0.headcount > 0 }
    guard !matched.isEmpty else { return nil }
    let ordered = matched.sorted { lhs, rhs in
        if lhs.headcount == rhs.headcount { return lhs.name < rhs.name }
        return lhs.headcount > rhs.headcount
    }
    return LectureCrowd(students: ordered.reduce(0) { $0 + $1.headcount }, groups: ordered)
}

private func subjectsMatch(_ subject: String, _ target: String) -> Bool {
    let lhs = normalizedLabel(subject)
    let rhs = normalizedLabel(target)
    guard lhs.count >= 4, rhs.count >= 4 else { return false }
    return lhs == rhs
}

private func normalizedLabel(_ value: String) -> String {
    value.folding(options: .diacriticInsensitive, locale: .current)
        .lowercased()
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

private func normalizedRoom(_ value: String) -> String {
    let room = normalizedLabel(value)
    if room.isEmpty || room == "no room" { return "" }
    return room
}

private func dateOn(_ day: Date, hour: Int, minute: Int) -> Date? {
    var components = Calendar.ans.dateComponents([.year, .month, .day], from: day)
    components.hour = hour
    components.minute = minute
    components.second = 0
    return Calendar.ans.date(from: components)
}

func parkingBannerTitle(moment: ParkingMoment, capacity: Int, today: Bool) -> String {
    if moment.worst.cars == 0 {
        return today ? "Parking looks open now" : "Parking looks open"
    }
    let time = parkingTimeText(moment.time)
    if moment.worst.freeSpots == 0, moment.best.freeSpots == 0 {
        let worstOver = moment.worst.cars - max(capacity, 0)
        let bestOver = moment.best.cars - max(capacity, 0)
        if worstOver > 0 {
            let overflow = worstOver == bestOver ? "\(worstOver)" : "\(min(bestOver, worstOver))–\(max(bestOver, worstOver))"
            return today ? "Full now · \(overflow) over capacity" : "Full around \(time) · \(overflow) over capacity"
        }
        return today ? "Parking looks full now" : "Parking looks full around \(time)"
    }
    if moment.worst.freeSpots == 0 {
        if today {
            return "Full if one per car · \(moment.best.freeSpots) free if \(moment.best.peoplePerCar) share"
        }
        return "Full around \(time) if one per car · \(moment.best.freeSpots) free if cars are shared"
    }
    if moment.worst.freeSpots == moment.best.freeSpots {
        if today {
            return "About \(moment.freeSpots) of \(capacity) free now"
        }
        return "About \(moment.freeSpots) of \(capacity) free around \(time)"
    }
    if today {
        return "About \(moment.worst.freeSpots)–\(moment.best.freeSpots) of \(capacity) free now"
    }
    return "About \(moment.worst.freeSpots)–\(moment.best.freeSpots) of \(capacity) free around \(time)"
}

private func jsonDictionary(from data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw ParkingError.badResponse
    }
    return object
}

private func planowanieError(in json: [String: Any]) -> ParkingError? {
    guard let exception = json["exceptionClass"] as? String, !exception.isEmpty else { return nil }
    if let message = json["exceptionMessage"] as? String, !message.isEmpty {
        return .unavailable(message)
    }
    return .unavailable(exception)
}

private func returnedItems(in json: [String: Any]) -> [Any] {
    guard let returned = json["returnedValue"] as? [String: Any] else { return [] }
    return returned["items"] as? [Any] ?? []
}

private func collectOrganizationalUnitIDs(_ node: Any, into ids: inout [Int], seen: inout Set<Int>) {
    guard let dictionary = node as? [String: Any] else { return }
    if let reference = dictionary["_reference"] as? [String: Any] {
        if let id = intValue(reference["idJednostki"]) {
            appendUnique(id, into: &ids, seen: &seen)
        }
        return
    }
    if dictionary["type"] as? String == "jednostka",
       let idObject = dictionary["id"] as? [String: Any],
       let id = intValue(idObject["idJednostki"]) {
        appendUnique(id, into: &ids, seen: &seen)
    }
    if let children = dictionary["children"] as? [Any] {
        for child in children {
            collectOrganizationalUnitIDs(child, into: &ids, seen: &seen)
        }
    }
}

private func collectDeanGroups(_ node: Any, unit: String?, into groups: inout [DeanGroup], seen: inout Set<Int>) {
    guard let dictionary = node as? [String: Any], dictionary["_reference"] == nil else { return }
    let type = dictionary["type"] as? String
    let label = stringValue(dictionary["label"])
    let nextUnit = type == "jednostka" ? (label ?? unit) : unit
    if type == "grupadziekanska", let id = intValue(dictionary["id"]), seen.insert(id).inserted {
        let parsed = parseDeanGroupLabel(label ?? "")
        groups.append(DeanGroup(
            id: id,
            name: parsed.name,
            headcount: parsed.headcount ?? 0,
            program: stringValue(dictionary["tooltip"]),
            unit: nextUnit
        ))
    }
    if let children = dictionary["children"] as? [Any] {
        for child in children {
            collectDeanGroups(child, unit: nextUnit, into: &groups, seen: &seen)
        }
    }
}

private func appendUnique(_ id: Int, into ids: inout [Int], seen: inout Set<Int>) {
    if seen.insert(id).inserted {
        ids.append(id)
    }
}

private func stringValue(_ value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func intValue(_ value: Any?) -> Int? {
    guard let value else { return nil }
    if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return nil
        }
        return number.intValue
    }
    if let string = value as? String {
        return Int(string)
    }
    return nil
}
