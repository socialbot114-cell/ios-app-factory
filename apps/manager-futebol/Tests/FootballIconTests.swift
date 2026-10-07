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

    func testGuestIsOnlyAvailableInEasyMode() throws {
        var career = career()
        career.difficulty = .normal
        XCTAssertFalse(career.canPickGuest)
        XCTAssertFalse(career.selectGuest(.yashin))
        career.difficulty = .easy
        XCTAssertTrue(career.canPickGuest)
        XCTAssertTrue(career.selectGuest(.yashin))
        XCTAssertEqual(career.iconState.guest, .yashin)
        XCTAssertTrue(career.startingXI.contains(IconCard.yashin.playerID))

        XCTAssertTrue(career.selectGuest(.eusebio), "Trocar de convidado remove o anterior")
        XCTAssertEqual(career.iconState.guest, .eusebio)
        XCTAssertFalse(career.players.contains { $0.id == IconCard.yashin.playerID })

        XCTAssertTrue(career.selectGuest(nil))
        XCTAssertNil(career.iconState.guest)
        XCTAssertFalse(career.players.contains { $0.id == IconCard.eusebio.playerID })
        XCTAssertEqual(career.startingXI.count, 11)
    }

    func testGuestCannotDuplicateTheSeasonIcon() throws {
        var career = career()
        career.difficulty = .easy
        career.grantIconPack()
        let card = try XCTUnwrap(career.openIconPack())
        XCTAssertFalse(career.guestChoices.contains(card))
        XCTAssertFalse(career.selectGuest(card))
    }

    func testGuestPlaysOneMatchAndThenLeaves() throws {
        var career = career()
        career.difficulty = .easy
        XCTAssertTrue(career.selectGuest(.garrincha))
        XCTAssertTrue(career.beginMatchDay())
        XCTAssertFalse(career.canPickGuest, "Durante a partida não dá para trocar o convidado")
        XCTAssertTrue(career.finishMatchDay())
        XCTAssertNil(career.iconState.guest)
        XCTAssertFalse(career.players.contains { $0.id == IconCard.garrincha.playerID })
        XCTAssertEqual(career.startingXI.count, 11)
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
