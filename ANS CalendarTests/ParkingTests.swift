//
//  ParkingTests.swift
//  ANS CalendarTests
//

import Foundation
import Testing
@testable import ANS_Calendar

struct ParkingTests {
    private let calendar = Calendar.ans

    @Test func rootCallReadsFacultyUnitIdsInOrder() throws {
        let ids = try parseOrganizationalUnitIDs(data: Data(rootGroupsJSON.utf8))
        #expect(ids == [8, 6, 5, 9, 53, 10, 7, 4])
    }

    @Test func facultyTreeReadsDeanGroupSizes() throws {
        let groups = try parseDeanGroups(data: Data(facultyGroupsJSON.utf8))
        #expect(groups.map(\.id) == [1772, 1773, 1774, 1775, 1776, 1777, 1778, 1779, 1800])
        #expect(groups.map(\.headcount) == [20, 12, 18, 10, 25, 25, 14, 14, 30])
        #expect(groups.map(\.name) == ["IE1.1", "IE3.1", "IE5.1", "IE7.1", "RA1.1", "RA1.2", "RA3.1", "RA3.2", "IF1.1"])
        #expect(groups.first?.unit == "IEZI")
        #expect(groups.first?.program == "Informatyka ekonomiczna")
        #expect(groups.last?.unit == "IF")
        #expect(groups.filter { $0.unit == "IEZI" }.count == 8)
    }

    @Test func groupWithoutASizeCountsAsZero() throws {
        let json = """
        {"returnedValue":{"items":[{"id":{"_class":"pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO","idJednostki":1},"label":"TEST","type":"jednostka","children":[{"id":42,"label":"X1","tooltip":null,"type":"grupadziekanska","children":null}]}]},"exceptionClass":null}
        """
        let groups = try parseDeanGroups(data: Data(json.utf8))
        #expect(groups == [DeanGroup(id: 42, name: "X1", headcount: 0, program: nil, unit: "TEST")])
    }

    @Test func duplicateUnitReferencesAreIgnored() throws {
        let json = """
        {"returnedValue":{"items":[{"id":"r0","type":"root","children":[{"_reference":{"_class":"pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO","idJednostki":8}},{"_reference":{"_class":"pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO","idJednostki":8}},{"_reference":{"_class":"pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO","idJednostki":6}}]}]},"exceptionClass":null}
        """
        #expect(try parseOrganizationalUnitIDs(data: Data(json.utf8)) == [8, 6])
    }

    @Test func planningErrorSurfacesTheServerMessage() {
        let json = """
        {"returnedValue":null,"exceptionClass":"org.objectledge.web.mvc.security.LoginRequiredException","exceptionMessage":"login required"}
        """
        expectParkingError(.unavailable("login required")) {
            _ = try parseOrganizationalUnitIDs(data: Data(json.utf8))
        }
        let nameless = """
        {"returnedValue":null,"exceptionClass":"LoginRequired","exceptionMessage":null}
        """
        expectParkingError(.unavailable("LoginRequired")) {
            _ = try parseDeanGroups(data: Data(nameless.utf8))
        }
    }

    @Test func groupLabelSplitsTheHeadcount() {
        #expect(parseDeanGroupLabel("IE7.1: 10").name == "IE7.1")
        #expect(parseDeanGroupLabel("IE7.1: 10").headcount == 10)
        #expect(parseDeanGroupLabel("  RA1.1:25 ").name == "RA1.1")
        #expect(parseDeanGroupLabel("  RA1.1:25 ").headcount == 25)
        #expect(parseDeanGroupLabel("X1").name == "X1")
        #expect(parseDeanGroupLabel("X1").headcount == nil)
    }

    @Test func remoteRoomsStayOffTheLot() {
        #expect(roomIsRemote("Zajęcia zdalne"))
        #expect(roomIsRemote("MS Teams"))
        #expect(roomIsRemote("Zoom"))
        #expect(!roomIsRemote("BT T.0.01"))
    }

    @Test func groupMeetingsKeepCampusClassesAndSkipBrokenRows() throws {
        let start = date(year: 2026, month: 10, day: 1, hour: 9)
        let end = date(year: 2026, month: 10, day: 1, hour: 10, minute: 30)
        let startMs = Int(start.timeIntervalSince1970 * 1000)
        let endMs = Int(end.timeIntervalSince1970 * 1000)
        let json = """
        {"exceptionClass":null,"returnedValue":{"items":[
          {"nazwa":"not a meeting"},
          {"dataRozpoczecia":\(startMs),"dataZakonczenia":\(endMs),"nazwaPelnaPrzedmiotu":"Math","sale":[{"idSali":1,"nazwaSkrocona":"BT T.0.01"}],"wykladowcy":[{"idProwadzacego":7,"stopienImieNazwisko":"mgr A"}]},
          {"dataRozpoczecia":\(startMs),"dataZakonczenia":\(endMs),"nazwaPelnaPrzedmiotu":"Online","sale":[{"idSali":2,"nazwaSkrocona":"Zajęcia zdalne"}],"wykladowcy":[{"idProwadzacego":9,"stopienImieNazwisko":"mgr B"}]},
          {"dataRozpoczecia":\(startMs),"dataZakonczenia":\(endMs),"nazwaPelnaPrzedmiotu":"Unassigned","sale":null,"wykladowcy":null}
        ]}}
        """
        let meetings = try parseGroupMeetings(data: Data(json.utf8), groupID: 1775)
        #expect(meetings.count == 3)
        #expect(meetings[0].onCampus)
        #expect(meetings[0].lecturerIDs == [7])
        #expect(meetings[0].subject == "Math")
        #expect(meetings[0].room == "BT T.0.01")
        #expect(!meetings[1].onCampus)
        #expect(meetings[2].onCampus)
        #expect(meetings[2].lecturerIDs.isEmpty)
        #expect(abs(meetings[0].start.timeIntervalSince1970 - start.timeIntervalSince1970) < 0.001)

        let empty = """
        {"exceptionClass":null,"returnedValue":{"items":[]}}
        """
        #expect(try parseGroupMeetings(data: Data(empty.utf8), groupID: 1775).isEmpty)

        expectParkingError(.badResponse) {
            _ = try parseGroupMeetings(
                data: Data("{\"exceptionClass\":null,\"returnedValue\":{\"items\":[{\"nazwa\":\"not a meeting\"}]}}".utf8),
                groupID: 1
            )
        }
    }

    @Test func requestsMatchThePlanningCalls() throws {
        let root = ajaxRequestBody(
            service: planowanieService,
            method: semesterGroupsMethod,
            params: rootGroupTreeParams(semesterID: 92)
        )
        let rootJSON = try JSONSerialization.jsonObject(with: root) as? [String: Any]
        #expect(rootJSON?["service"] as? String == "Planowanie")
        #expect(rootJSON?["method"] as? String == "getGrupySemestralneSemestru")
        let rootParams = rootJSON?["params"] as? [String: Any]
        #expect(rootParams?["idSemestru"] as? Int == 92)
        #expect((rootParams?["cyklRoczny"] as? Bool) == false)
        let rootItems = rootParams?["itemIdList"] as? [Any]
        #expect(rootItems?.first as? String == "r0")

        let units = [8, 6, 5, 9, 53, 10, 7, 4]
        let tree = ajaxRequestBody(
            service: planowanieService,
            method: semesterGroupsMethod,
            params: semesterGroupTreeParams(semesterID: 92, unitIDs: units)
        )
        let treeJSON = try JSONSerialization.jsonObject(with: tree) as? [String: Any]
        let treeParams = treeJSON?["params"] as? [String: Any]
        let treeItems = treeParams?["itemIdList"] as? [Any]
        #expect(treeItems?.count == 8)
        let firstUnit = treeItems?.first as? [String: Any]
        let lastUnit = treeItems?.last as? [String: Any]
        #expect(firstUnit?["_class"] as? String == organizationalUnitClassName)
        #expect(firstUnit?["idJednostki"] as? Int == 8)
        #expect(lastUnit?["idJednostki"] as? Int == 4)

        let week = date(year: 2026, month: 9, day: 28)
        let meetingParams = groupMeetingsParams(groupID: 1775, weekStart: week)
        #expect(meetingParams["idGrupyDziekanskiej"] as? Int == 1775)
        #expect(meetingParams["poczatekTygodnia"] as? Int == 1_790_546_400_000)
        #expect(weekStartMilliseconds(date(year: 2026, month: 10, day: 5)) == 1_791_151_200_000)
        #expect(weekStartMilliseconds(date(year: 2026, month: 10, day: 7)) == 1_791_151_200_000)
    }

    @Test func peopleStayParkedBetweenClasses() {
        let day = date(year: 2026, month: 10, day: 1)
        let assumptions = ParkingAssumptions(capacity: 40, driverShare: 1, lecturerCapacity: 2, arrivalLead: 20 * 60, departureLag: 15 * 60)
        let forecast = makeParkingForecast(
            day: day,
            groups: [group(1775, "IE7.1", 10)],
            meetings: [
                meeting(1775, from: (9, 0), to: (10, 30), lecturer: 3),
                meeting(1775, from: (13, 0), to: (14, 30), lecturer: 3)
            ],
            assumptions: assumptions,
            now: date(year: 2026, month: 10, day: 1, hour: 12)
        )

        let midday = forecast.current
        #expect(midday?.studentHeadcount == 10)
        #expect(midday?.lecturerCars == 1)
        #expect(midday?.lecturerPublicCars == 0)
        #expect(midday?.cars == 10)
        #expect(midday?.freeSpots == 30)
        #expect(midday?.groups.map(\.name) == ["IE7.1"])
        #expect(midday?.groups.first?.activeClass == nil)
        #expect(forecast.groupsWithClasses == 1)

        let beforeArrival = snapshot(on: day, atHour: 8, minute: 30, groups: [group(1775, "IE7.1", 10)], meetings: [
            meeting(1775, from: (9, 0), to: (10, 30), lecturer: 3)
        ], assumptions: assumptions)
        let justAfterArrival = snapshot(on: day, atHour: 8, minute: 45, groups: [group(1775, "IE7.1", 10)], meetings: [
            meeting(1775, from: (9, 0), to: (10, 30), lecturer: 3)
        ], assumptions: assumptions)
        let stillLeaving = snapshot(on: day, atHour: 10, minute: 44, groups: [group(1775, "IE7.1", 10)], meetings: [
            meeting(1775, from: (9, 0), to: (10, 30), lecturer: 3)
        ], assumptions: assumptions)
        let gone = snapshot(on: day, atHour: 10, minute: 45, groups: [group(1775, "IE7.1", 10)], meetings: [
            meeting(1775, from: (9, 0), to: (10, 30), lecturer: 3)
        ], assumptions: assumptions)
        #expect(beforeArrival.cars == 0)
        #expect(justAfterArrival.cars == 10)
        #expect(stillLeaving.cars == 10)
        #expect(gone.cars == 0)
    }

    @Test func overlappingGroupsShareALecturerAndSkipOnlineClasses() {
        let assumptions = ParkingAssumptions(capacity: 100, driverShare: 0.5, lecturerCapacity: 4)
        let groups = [group(1, "A", 20), group(2, "B", 10), group(3, "Remote", 100)]
        let meetings = [
            meeting(1, from: (10, 0), to: (12, 0), lecturer: 7, subject: "Algorithms", room: "BT T.0.01"),
            meeting(2, from: (10, 0), to: (11, 0), lecturer: 7, subject: "Lab", room: "BG 314"),
            meeting(3, from: (10, 0), to: (12, 0), lecturer: 9, onCampus: false, subject: "Remote class")
        ]
        let during = snapshot(on: date(year: 2026, month: 10, day: 1), atHour: 10, minute: 30, groups: groups, meetings: meetings, assumptions: assumptions)
        let later = snapshot(on: date(year: 2026, month: 10, day: 1), atHour: 11, minute: 30, groups: groups, meetings: meetings, assumptions: assumptions)

        #expect(during.studentHeadcount == 30)
        #expect(during.studentCars == 15)
        #expect(during.lecturerCars == 1)
        #expect(during.lecturerPublicCars == 0)
        #expect(during.cars == 15)
        #expect(during.groups.map(\.name) == ["A", "B"])
        #expect(during.groups.first { $0.name == "A" }?.activeClass?.title == "Algorithms")
        #expect(during.groups.first { $0.name == "B" }?.activeClass?.room == "BG 314")
        #expect(later.studentHeadcount == 20)
        #expect(later.lecturerCars == 1)
        #expect(later.cars == 10)
        #expect(later.freeSpots == 90)
    }

    @Test func driverShareRoundsToWholeCars() {
        let assumptions = ParkingAssumptions(capacity: 10, driverShare: 0.4)
        let three = snapshot(
            on: date(year: 2026, month: 10, day: 1),
            atHour: 10, minute: 0,
            groups: [group(1, "A", 3)],
            meetings: [meeting(1, from: (10, 0), to: (11, 0), lecturer: 0)],
            assumptions: assumptions
        )
        let one = snapshot(
            on: date(year: 2026, month: 10, day: 1),
            atHour: 10, minute: 0,
            groups: [group(1, "A", 1)],
            meetings: [meeting(1, from: (10, 0), to: (11, 0), lecturer: 0)],
            assumptions: assumptions
        )
        let half = snapshot(
            on: date(year: 2026, month: 10, day: 1),
            atHour: 10, minute: 0,
            groups: [group(1, "A", 1)],
            meetings: [meeting(1, from: (10, 0), to: (11, 0), lecturer: 0)],
            assumptions: ParkingAssumptions(capacity: 10, driverShare: 0.5)
        )
        #expect(three.studentCars == 1)
        #expect(three.best.studentCars == 0)
        #expect(three.lecturerCars == 0)
        #expect(one.studentCars == 0)
        #expect(half.studentCars == 1)
        #expect(half.best.studentCars == 0)
    }

    @Test func sharingACarFreesMoreSpacesThanDrivingAlone() {
        let now = date(year: 2026, month: 10, day: 1, hour: 10)
        let forecast = makeParkingForecast(
            day: date(year: 2026, month: 10, day: 1),
            groups: [group(1, "IE7.1", 30)],
            meetings: [meeting(1, from: (10, 0), to: (11, 0), lecturer: 0)],
            assumptions: ParkingAssumptions(capacity: 20, driverShare: 1),
            now: now
        )
        let moment = forecast.current
        #expect(moment?.worst == ParkingCase(peoplePerCar: 1, studentCars: 30, cars: 30, freeSpots: 0))
        #expect(moment?.best == ParkingCase(peoplePerCar: 3, studentCars: 10, cars: 10, freeSpots: 10))
        #expect(moment?.cars == 30)
        #expect(moment?.freeSpots == 0)

        let copy = parkingBannerCopy(forecast: forecast, now: now)
        #expect(copy.title == "Full if one per car · 10 free if 3 share")
        #expect(copy.pressure == .full)
        #expect(parkingAssumptionsText(ParkingAssumptions(capacity: 20, driverShare: 1)).contains("Worst case is one student per car"))
        #expect(parkingAssumptionsText(ParkingAssumptions(capacity: 20, driverShare: 1)).contains("Best case is 3 students sharing a car"))
        #expect(parkingAssumptionsText(ParkingAssumptions(capacity: 20, driverShare: 1, lecturerCapacity: 2)).contains("staff lot of 2 spaces"))
    }

    @Test func lecturersSpillIntoThePublicLotWhenTheStaffLotIsFull() {
        let now = date(year: 2026, month: 10, day: 1, hour: 10)
        let meetings = (1...4).map { meeting(1, from: (10, 0), to: (11, 0), lecturer: $0) }
        let forecast = makeParkingForecast(
            day: date(year: 2026, month: 10, day: 1),
            groups: [group(1, "IE7.1", 10)],
            meetings: meetings,
            assumptions: ParkingAssumptions(capacity: 20, driverShare: 1, lecturerCapacity: 2),
            now: now
        )
        let moment = forecast.current
        #expect(moment?.lecturerCars == 4)
        #expect(moment?.lecturerPublicCars == 2)
        #expect(moment?.studentCars == 10)
        #expect(moment?.cars == 12)
        #expect(moment?.freeSpots == 8)
        #expect(moment?.best.cars == 5)
        #expect(moment?.best.freeSpots == 15)
        #expect(lecturerParkingText(moment!) == ", 2 lecturers in the public lot")

        let covered = makeParkingForecast(
            day: date(year: 2026, month: 10, day: 1),
            groups: [group(1, "IE7.1", 10)],
            meetings: meetings,
            assumptions: ParkingAssumptions(capacity: 20, driverShare: 1, lecturerCapacity: 4),
            now: now
        )
        #expect(covered.current?.lecturerPublicCars == 0)
        #expect(covered.current?.cars == 10)
        #expect(lecturerParkingText(covered.current!) == " · lecturers in the staff lot")
    }

    @Test func bannerDescribesFreeSpacesNowAndAtThePeak() {
        let day = date(year: 2026, month: 10, day: 1)
        let assumptions = ParkingAssumptions(capacity: 50, driverShare: 0.5, lecturerCapacity: 30)
        let groups = [group(1, "IE7.1", 20)]
        let meetings = [meeting(1, from: (10, 0), to: (11, 0), lecturer: 4)]

        let early = makeParkingForecast(day: day, groups: groups, meetings: meetings, assumptions: assumptions, now: date(year: 2026, month: 10, day: 1, hour: 8))
        let earlyCopy = parkingBannerCopy(forecast: early, now: date(year: 2026, month: 10, day: 1, hour: 8))
        #expect(earlyCopy.title == "Parking looks open now")
        #expect(earlyCopy.subtitle == "Busiest around 09:40 · 40–47 of 50 free")
        #expect(earlyCopy.pressure == .open)

        let duringNow = date(year: 2026, month: 10, day: 1, hour: 10)
        let during = makeParkingForecast(day: day, groups: groups, meetings: meetings, assumptions: assumptions, now: duringNow)
        let duringCopy = parkingBannerCopy(forecast: during, now: duringNow)
        #expect(during.current?.worst.freeSpots == 40)
        #expect(during.current?.best.freeSpots == 47)
        #expect(during.current?.lecturerPublicCars == 0)
        #expect(duringCopy.title == "About 40–47 of 50 free now")
        #expect(duringCopy.subtitle == "Worst 10 cars · best 3 · 20 students · lecturers in the staff lot")
        #expect(duringCopy.pressure == .open)

        let otherDay = makeParkingForecast(day: day, groups: groups, meetings: meetings, assumptions: assumptions, now: date(year: 2026, month: 10, day: 2, hour: 10))
        let otherCopy = parkingBannerCopy(forecast: otherDay, now: date(year: 2026, month: 10, day: 2, hour: 10))
        #expect(otherCopy.title == "About 40–47 of 50 free around 09:40")

        let overflow = makeParkingForecast(
            day: day,
            groups: [group(1, "IE7.1", 20)],
            meetings: [meeting(1, from: (10, 0), to: (11, 0), lecturer: 0)],
            assumptions: ParkingAssumptions(capacity: 5, driverShare: 1),
            now: duringNow
        )
        let overflowCopy = parkingBannerCopy(forecast: overflow, now: duringNow)
        #expect(overflowCopy.title == "Full now · 2–15 over capacity")
        #expect(overflowCopy.pressure == .full)
        #expect(overflow.current?.freeSpots == 0)

        let missing = makeParkingForecast(
            day: day,
            groups: groups,
            meetings: meetings,
            assumptions: assumptions,
            now: duringNow,
            failedGroupFetches: 2
        )
        #expect(parkingBannerCopy(forecast: missing, now: duringNow).subtitle.contains("2 groups missing"))

        let empty = makeParkingForecast(day: day, groups: [], meetings: [], assumptions: assumptions, now: duringNow)
        #expect(parkingBannerCopy(forecast: empty, now: duringNow).title == "No parking estimate")

        let quiet = makeParkingForecast(day: day, groups: groups, meetings: [], assumptions: assumptions, now: duringNow)
        #expect(parkingBannerCopy(forecast: quiet, now: duringNow).subtitle == "No on-campus classes that day")
    }

    @Test func pressureFollowsHowMuchOfTheLotIsLeft() {
        #expect(parkingPressure(freeSpots: 50, capacity: 100) == .open)
        #expect(parkingPressure(freeSpots: 40, capacity: 100) == .open)
        #expect(parkingPressure(freeSpots: 39, capacity: 100) == .limited)
        #expect(parkingPressure(freeSpots: 15, capacity: 100) == .limited)
        #expect(parkingPressure(freeSpots: 14, capacity: 100) == .full)
        #expect(parkingPressure(freeSpots: 0, capacity: 100) == .full)
    }

    private func snapshot(
        on day: Date,
        atHour hour: Int,
        minute: Int,
        groups: [DeanGroup],
        meetings: [CampusMeeting],
        assumptions: ParkingAssumptions
    ) -> ParkingMoment {
        let now = date(year: 2026, month: 10, day: 1, hour: hour, minute: minute)
        let forecast = makeParkingForecast(day: day, groups: groups, meetings: meetings, assumptions: assumptions, now: now)
        return forecast.current!
    }

    private func group(_ id: Int, _ name: String, _ headcount: Int) -> DeanGroup {
        DeanGroup(id: id, name: name, headcount: headcount, program: nil, unit: nil)
    }

    private func meeting(
        _ groupID: Int,
        from start: (Int, Int),
        to end: (Int, Int),
        lecturer: Int,
        onCampus: Bool = true,
        subject: String = "",
        room: String = ""
    ) -> CampusMeeting {
        CampusMeeting(
            groupID: groupID,
            start: date(year: 2026, month: 10, day: 1, hour: start.0, minute: start.1),
            end: date(year: 2026, month: 10, day: 1, hour: end.0, minute: end.1),
            onCampus: onCampus,
            lecturerIDs: lecturer == 0 ? [] : [lecturer],
            subject: subject,
            room: room
        )
    }

    @Test func classDetailCountsTheMatchingLectureAndTheLot() {
        let day = date(year: 2026, month: 10, day: 1)
        let start = date(year: 2026, month: 10, day: 1, hour: 10)
        let end = date(year: 2026, month: 10, day: 1, hour: 11, minute: 30)
        let assumptions = ParkingAssumptions(capacity: 40, driverShare: 1, lecturerCapacity: 1)
        let groups = [
            DeanGroup(id: 1, name: "IE7.1", headcount: 10, program: "Informatyka ekonomiczna", unit: "IEZI"),
            DeanGroup(id: 2, name: "RA1.1", headcount: 20, program: nil, unit: "IEZI")
        ]
        let meetings = [
            meeting(1, from: (10, 0), to: (11, 30), lecturer: 4, subject: "Podstawy matematyki", room: "BT T.0.01"),
            meeting(2, from: (10, 0), to: (11, 30), lecturer: 8, subject: "Podstawy matematyki", room: "BT T.0.01")
        ]
        let schedule = ScheduleInfo(
            dataRozpoczecia: Int(start.timeIntervalSince1970 * 1000),
            dataZakonczenia: Int(end.timeIntervalSince1970 * 1000),
            nazwaPelnaPrzedmiotu: "Podstawy matematyki",
            grupyZajeciowe: [],
            grupySprawdzianu: [],
            listaIdZajecInstancji: [],
            sale: [RoomInfo(idSali: 1, nazwaSkrocona: "BT T.0.01")],
            wykladowcy: []
        )
        let info = classParkingInfo(for: schedule, day: day, groups: groups, meetings: meetings, assumptions: assumptions)
        #expect(info.crowd?.students == 30)
        #expect(info.crowd?.groups.map(\.name) == ["RA1.1", "IE7.1"])
        #expect(info.moment.studentHeadcount == 30)
        #expect(info.moment.freeSpots == 9)
        #expect(info.moment.groups.first?.activeClass?.title == "Podstawy matematyki")

        let otherRoom = ScheduleInfo(
            dataRozpoczecia: Int(start.timeIntervalSince1970 * 1000),
            dataZakonczenia: Int(end.timeIntervalSince1970 * 1000),
            nazwaPelnaPrzedmiotu: "Inny przedmiot",
            grupyZajeciowe: [],
            grupySprawdzianu: [],
            listaIdZajecInstancji: [],
            sale: [RoomInfo(idSali: 1, nazwaSkrocona: "BT T.0.01")],
            wykladowcy: []
        )
        let byRoom = classParkingInfo(for: otherRoom, day: day, groups: groups, meetings: meetings, assumptions: assumptions)
        #expect(byRoom.crowd?.students == 30)

        let parallel = [
            meeting(1, from: (10, 0), to: (11, 30), lecturer: 4, subject: "Podstawy matematyki", room: "BT T.0.01"),
            meeting(2, from: (10, 0), to: (11, 30), lecturer: 8, subject: "Podstawy matematyki", room: "BG 200")
        ]
        let oneSection = classParkingInfo(for: schedule, day: day, groups: groups, meetings: parallel, assumptions: assumptions)
        #expect(oneSection.crowd?.groups.map(\.name) == ["IE7.1"])
        #expect(oneSection.crowd?.students == 10)

        let unmatched = ScheduleInfo(
            dataRozpoczecia: Int(start.timeIntervalSince1970 * 1000),
            dataZakonczenia: Int(end.timeIntervalSince1970 * 1000),
            nazwaPelnaPrzedmiotu: "Inny przedmiot",
            grupyZajeciowe: [],
            grupySprawdzianu: [],
            listaIdZajecInstancji: [],
            sale: [RoomInfo(idSali: 9, nazwaSkrocona: "BG 100")],
            wykladowcy: []
        )
        #expect(classParkingInfo(for: unmatched, day: day, groups: groups, meetings: meetings, assumptions: assumptions).crowd == nil)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func expectParkingError(_ expected: ParkingError, _ body: () throws -> Void) {
        do {
            try body()
            Issue.record("Expected \(expected)")
        } catch let error as ParkingError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
}

private let rootGroupsJSON = """
{
    "returnedValue": {
        "numRows": 1,
        "identifier": "id",
        "label": "label",
        "items": [
            {
                "id": "r0",
                "label": "Grupy dziekańskie",
                "tooltip": null,
                "type": "root",
                "labelClass": null,
                "hasHiddenChildren": false,
                "children": [
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 8}},
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 6}},
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 5}},
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 9}},
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 53}},
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 10}},
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 7}},
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 4}}
                ]
            }
        ]
    },
    "exceptionClass": null,
    "exceptionMessage": null
}
"""

private let facultyGroupsJSON = """
{
    "returnedValue": {
        "numRows": 2,
        "identifier": "id",
        "label": "label",
        "items": [
            {
                "id": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 9},
                "label": "IEZI",
                "tooltip": null,
                "type": "jednostka",
                "children": [
                    {"_reference": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 99}},
                    {
                        "id": "9_I,D,PL",
                        "label": "I,D,PL",
                        "type": "rodzajetapu",
                        "children": [
                            {
                                "id": "9_I,D,PL_semestr 1",
                                "label": "semestr 1",
                                "type": "cykl",
                                "children": [
                                    {"id": 1772, "label": "IE1.1: 20", "tooltip": "Informatyka ekonomiczna", "type": "grupadziekanska", "children": null}
                                ]
                            },
                            {
                                "id": "9_I,D,PL_semestr 3",
                                "label": "semestr 3",
                                "type": "cykl",
                                "children": [
                                    {"id": 1773, "label": "IE3.1: 12", "tooltip": "Informatyka ekonomiczna", "type": "grupadziekanska", "children": null}
                                ]
                            },
                            {
                                "id": "9_I,D,PL_semestr 5",
                                "label": "semestr 5",
                                "type": "cykl",
                                "children": [
                                    {"id": 1774, "label": "IE5.1: 18", "tooltip": "Informatyka ekonomiczna", "type": "grupadziekanska", "children": null}
                                ]
                            },
                            {
                                "id": "9_I,D,PL_semestr 7",
                                "label": "semestr 7",
                                "type": "cykl",
                                "children": [
                                    {"id": 1775, "label": "IE7.1: 10", "tooltip": "Informatyka ekonomiczna", "type": "grupadziekanska", "children": null}
                                ]
                            }
                        ]
                    },
                    {
                        "id": "9_M,D,PL",
                        "label": "M,D,PL",
                        "type": "rodzajetapu",
                        "children": [
                            {
                                "id": "9_M,D,PL_semestr 1",
                                "label": "semestr 1",
                                "type": "cykl",
                                "children": [
                                    {"id": 1776, "label": "RA1.1: 25", "tooltip": "rachunkowość  i analityka", "type": "grupadziekanska", "children": null},
                                    {"id": 1777, "label": "RA1.2: 25", "tooltip": "rachunkowość  i analityka", "type": "grupadziekanska", "children": null}
                                ]
                            },
                            {
                                "id": "9_M,D,PL_semestr 3",
                                "label": "semestr 3",
                                "type": "cykl",
                                "children": [
                                    {"id": 1778, "label": "RA3.1: 14", "tooltip": "rachunkowość  i analityka", "type": "grupadziekanska", "children": null},
                                    {"id": 1779, "label": "RA3.2: 14", "tooltip": "rachunkowość  i analityka", "type": "grupadziekanska", "children": null}
                                ]
                            }
                        ]
                    }
                ]
            },
            {
                "id": {"_class": "pl.edu.pw.mel.pojo.id.JednostkaOrganizacyjnaIdPOJO", "idJednostki": 10},
                "label": "IF",
                "type": "jednostka",
                "children": [
                    {
                        "id": "10_L,D,PL",
                        "label": "L,D,PL",
                        "type": "rodzajetapu",
                        "children": [
                            {
                                "id": "10_L,D,PL_semestr 1",
                                "label": "semestr 1",
                                "type": "cykl",
                                "children": [
                                    {"id": 1800, "label": "IF1.1: 30", "tooltip": "Finanse", "type": "grupadziekanska", "children": null}
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    },
    "exceptionClass": null,
    "exceptionMessage": null
}
"""
