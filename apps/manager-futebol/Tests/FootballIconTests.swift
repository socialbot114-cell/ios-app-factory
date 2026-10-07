import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballIconTests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        return career
    }

    func testCardsHaveUniqueIDsStatsAndAssets() {
        let ids = IconCard.allCases.map(\.playerID)
        XCTAssertEqual(Set(ids).count, IconCard.allCases.count)
        XCTAssertTrue(ids.allSatisfy { $0 > IconCard.playerIDBase })
        XCTAssertEqual(Set(IconCard.allCases.map(\.assetName)).count, IconCard.allCases.count)
        for card in IconCard.allCases {
            XCTAssertEqual(card.stats.count, 6)
            XCTAssertEqual(IconCard.card(forPlayerID: card.playerID), card)
            XCTAssertEqual(card.detail.group, card.position)
            XCTAssertTrue((90...95).contains(card.overall))
        }
        XCTAssertNil(IconCard.card(forPlayerID: 1))
    }

    func testPackBringsTheIconForTheSeasonAndItCannotBeSold() throws {
        var career = career()
        XCTAssertNil(career.openIconPack(), "Sem pacote não há o que abrir")
        career.grantIconPack()
        let card = try XCTUnwrap(career.iconState.pendingPack)
        XCTAssertEqual(career.openIconPack(), card)
        XCTAssertNil(career.iconState.pendingPack)
        XCTAssertEqual(career.iconState.seasonIcon, card)
        XCTAssertTrue(career.iconState.collected.contains(card))

        let icon = try XCTUnwrap(career.players.first { $0.id == card.playerID })
        XCTAssertEqual(icon.teamID, career.selectedClubID)
        XCTAssertEqual(icon.contract.wage, 0)
        XCTAssertTrue(icon.isIcon)
        XCTAssertTrue(career.startingXI.contains(card.playerID), "O craque entra entre os titulares")
        XCTAssertEqual(Set(career.startingXI).count, career.startingXI.count)
        XCTAssertFalse(career.canRelease(playerID: card.playerID))
        XCTAssertFalse(career.sellPlayer(playerID: card.playerID))
    }

    func testSeasonIconLeavesWhenTheSeasonEndsButKeepsItsName() throws {
        var career = career()
        career.grantIconPack()
        let card = try XCTUnwrap(career.openIconPack())
        career.expireSeasonIcon()
        XCTAssertNil(career.iconState.seasonIcon)
        XCTAssertFalse(career.players.contains { $0.id == card.playerID })
        XCTAssertFalse(career.startingXI.contains(card.playerID))
        XCTAssertEqual(career.startingXI.count, 11)
        XCTAssertEqual(career.player(card.playerID)?.name, card.name, "Relatórios antigos ainda mostram o nome")
    }

    func testStartingPackIsGrantedOnlyOnceAtTheBeginning() throws {
        var career = career()
        XCTAssertNil(career.iconState.pendingPack)
        career.grantStartingIconPack()
        let card = try XCTUnwrap(career.iconState.pendingPack)
        XCTAssertTrue(career.iconState.startingPackGranted)
        XCTAssertEqual(career.openIconPack(), card)
        career.grantStartingIconPack()
        XCTAssertNil(career.iconState.pendingPack, "A lenda inicial só vem uma vez por carreira")
        XCTAssertEqual(career.iconState.seasonIcon, card)
    }

    func testAnUnopenedPackIsKeptInsteadOfBeingReplaced() throws {
        var career = career()
        career.grantIconPack()
        let first = try XCTUnwrap(career.iconState.pendingPack)
        career.grantIconPack()
        XCTAssertEqual(career.iconState.pendingPack, first)
    }

    func testOldIconStateDecodesWithDefaultsAndIgnoresTheRemovedGuest() throws {
        let empty = try JSONDecoder().decode(IconState.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, IconState())
        let old = try JSONDecoder().decode(IconState.self, from: Data(#"{"guest":"yashin","collected":["yashin"]}"#.utf8))
        XCTAssertEqual(old.collected, [.yashin])
        XCTAssertNil(old.seasonIcon)
        XCTAssertFalse(old.startingPackGranted)
    }

    func testIconStateSurvivesSaveAndOldSavesHaveNone() throws {
        var career = career()
        career.grantIconPack()
        let card = try XCTUnwrap(career.openIconPack())
        let data = try JSONEncoder().encode(career)
        let loaded = try JSONDecoder().decode(FootballCareer.self, from: data)
        XCTAssertEqual(loaded.iconState, career.iconState)
        XCTAssertTrue(loaded.players.contains { $0.id == card.playerID })

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["iconState"] = nil
        let old = try JSONDecoder().decode(FootballCareer.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(old.iconState, IconState())
    }
}
