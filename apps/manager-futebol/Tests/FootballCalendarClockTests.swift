import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballCalendarClockTests: XCTestCase {
    func testFirstRoundIsASundayInJanuary() {
        let first = FootballCalendarClock.day(season: 1, matchDay: 0)
        XCTAssertEqual(FootballCalendarClock.weekdayName(first), "domingo")
        XCTAssertEqual(FootballCalendarClock.calendar.component(.month, from: first), 1)
        XCTAssertEqual(FootballCalendarClock.calendar.component(.year, from: first), FootballCalendarClock.firstSeasonYear)
    }

    func testEveryMatchDayIsAfterThePreviousOneAndKeepsItsWeekday() {
        var previous = FootballCalendarClock.day(season: 1, matchDay: 0)
        for (offset, slot) in FootballSeason.calendar.enumerated().dropFirst() {
            let day = FootballCalendarClock.day(season: 1, matchDay: offset)
            XCTAssertGreaterThan(day, previous, "Dia de jogo \(offset) deve vir depois do anterior")
            XCTAssertEqual(FootballCalendarClock.weekdayName(day), slot.isMidweek ? "quarta-feira" : "domingo")
            previous = day
        }
    }

    func testSeasonEndsBeforeNextSeasonStarts() {
        let lastDay = FootballCalendarClock.day(season: 1, matchDay: FootballSeason.matchDaysPerSeason - 1)
        let nextStart = FootballCalendarClock.day(season: 2, matchDay: 0)
        XCTAssertLessThan(lastDay, nextStart)
        XCTAssertGreaterThan(FootballCalendarClock.daysBetween(lastDay, nextStart), 30)
    }

    func testDaysBetweenCupMidweekAndNextSunday() {
        guard let cup = FootballSeason.calendar.first(where: { $0.isMidweek }) else { return XCTFail("sem copa") }
        let sunday = FootballCalendarClock.day(season: 1, matchDay: cup.index - 1)
        let wednesday = FootballCalendarClock.day(season: 1, matchDay: cup.index)
        let nextSunday = FootballCalendarClock.day(season: 1, matchDay: cup.index + 1)
        XCTAssertEqual(FootballCalendarClock.daysBetween(sunday, wednesday), 3)
        XCTAssertEqual(FootballCalendarClock.daysBetween(wednesday, nextSunday), 4)
    }

    func testTextIsDeterministicPortuguese() {
        let day = FootballCalendarClock.day(season: 1, matchDay: 0)
        XCTAssertTrue(FootballCalendarClock.longDate(day).hasPrefix("domingo, "))
        XCTAssertTrue(FootballCalendarClock.longDate(day).contains("janeiro"))
        XCTAssertEqual(FootballCalendarClock.clock(FootballCalendarClock.moment(season: 1, matchDay: 0)), "07:30")
        XCTAssertEqual(FootballCalendarClock.clock(FootballCalendarClock.kickoff(season: 1, matchDay: 0)), "16:00")
        XCTAssertTrue(FootballCalendarClock.shortDate(day).hasPrefix("Dom, "))
    }

    func testCareerReportsItsOwnDateAndAdvancesWithTheCalendar() {
        var career = FootballCareer(seed: 7)
        XCTAssertTrue(career.chooseClub(0))
        let before = career.gameDay
        XCTAssertTrue(career.simulateNextMatchDay())
        XCTAssertGreaterThan(career.gameDay, before)
    }
}
