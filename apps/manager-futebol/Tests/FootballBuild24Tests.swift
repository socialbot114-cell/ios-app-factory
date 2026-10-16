import Foundation
import XCTest
@testable import ManagerFutebol

/// Build 24: parcelamento e bônus iguais nos dois caminhos de compra, preço de veterano e rodízio dos titulares.
final class FootballBuild24Tests: XCTestCase {
    private func career(club: Int = 0, seed: Int = 7) -> FootballCareer {
        var career = FootballCareer(seed: seed)
        XCTAssertTrue(career.chooseClub(club))
        career.transferBudget = 60_000_000
        career.wageCap = career.wageBill * 3
        return career
    }

    /// Um atacante de outro clube que o vendedor aceita vender.
    private func forward(in career: FootballCareer) throws -> FootballPlayer {
        try XCTUnwrap(career.players.first {
            $0.teamID == 3 && $0.position == .forward && career.sellerCanSell($0) && career.squadRank(of: $0) >= 4
        })
    }

    // MARK: - Parcelamento

    func testInstallmentsCostTheSameInTheDirectBidAndInTheStagedTalk() throws {
        var career = career()
        let player = try forward(in: career)
        let ask = career.askingPrice(for: player)
        let wage = career.joiningAsk(for: player).wage
        let adjusted = career.installmentAdjustedAsk(ask, installments: 4)
        XCTAssertGreaterThan(adjusted, ask, "Parcelar em 4 vezes custa mais")
        XCTAssertEqual(career.installmentAdjustedAsk(ask, installments: 1), ask, "À vista não tem acréscimo")

        // Proposta direta: a taxa à vista não basta para 4 parcelas.
        let cheap = TransferBid(playerID: player.id, fee: ask, installments: 4, wage: wage, years: 3)
        XCTAssertNotEqual(career.evaluateBid(cheap), .accepted, "4x pela taxa à vista era aceito de graça")
        let full = TransferBid(playerID: player.id, fee: adjusted, installments: 4, wage: wage, years: 3)
        XCTAssertEqual(career.evaluateBid(full), .accepted)

        // Negociação por etapas: o clube pede exatamente o mesmo valor.
        let talk = try XCTUnwrap(career.startTransferTalk(playerID: player.id))
        guard case .counter = career.proposeFee(talkID: talk.id, fee: ask, installments: 4) else {
            return XCTFail("A negociação por etapas também pede mais para parcelar")
        }
        XCTAssertEqual(career.transferTalks.first { $0.id == talk.id }?.clubCounterFee, adjusted)
    }

    // MARK: - Bônus de gols

    func testGoalBonusOnlyCountsForThosePositionsThatScore() throws {
        let career = career()
        let striker = try XCTUnwrap(career.players.first { $0.position == .forward && $0.teamID == 3 })
        let midfielder = try XCTUnwrap(career.players.first { $0.position == .midfielder && $0.teamID == 3 })
        let defender = try XCTUnwrap(career.players.first { $0.position == .defender && $0.teamID == 3 })
        let keeper = try XCTUnwrap(career.players.first { $0.position == .goalkeeper && $0.teamID == 3 })
        let bonus = 2_000_000
        XCTAssertEqual(career.goalBonusCredit(bonus, for: striker), 1_000_000, "Atacante mantém metade do valor")
        XCTAssertLessThan(career.goalBonusCredit(bonus, for: midfielder), career.goalBonusCredit(bonus, for: striker))
        XCTAssertLessThan(career.goalBonusCredit(bonus, for: defender), career.goalBonusCredit(bonus, for: midfielder))
        XCTAssertEqual(career.goalBonusCredit(bonus, for: keeper), 0, "Goleiro nunca faz 10 gols")
    }

    func testGoalBonusNoLongerBuysAGoalkeeperForLess() throws {
        let career = career()
        let keeper = try XCTUnwrap(career.players.first {
            $0.teamID == 3 && $0.position == .goalkeeper && career.sellerCanSell($0)
        })
        let wage = career.joiningAsk(for: keeper).wage
        let ask = career.askingPrice(for: keeper)
        let withBonus = TransferBid(playerID: keeper.id, fee: Int(Double(ask) * 0.7), goalBonus: 3_000_000, wage: wage, years: 3)
        let withoutBonus = TransferBid(playerID: keeper.id, fee: Int(Double(ask) * 0.7), wage: wage, years: 3)
        XCTAssertEqual(career.evaluateBid(withBonus), career.evaluateBid(withoutBonus), "O bônus não muda a resposta para um goleiro")
    }

    // MARK: - Veteranos

    func testVeteranAskIsNotADoubleDiscount() throws {
        let career = career()
        var prime = try XCTUnwrap(career.players.first { $0.teamID == 3 })
        prime.age = 27
        prime.overall = 82
        prime.potential = 82
        prime.marketValue = FootballSeason.marketValue(overall: 82, age: 27, potential: 82)
        var veteran = prime
        veteran.age = 34
        veteran.marketValue = FootballSeason.marketValue(overall: 82, age: 34, potential: 82)
        let primeBase = career.askingBaseValue(for: prime)
        let veteranBase = career.askingBaseValue(for: veteran)
        XCTAssertGreaterThanOrEqual(Double(veteranBase), Double(primeBase) * 0.5, "Veterano de geral alto não pode custar menos da metade")
        XCTAssertLessThan(veteranBase, primeBase, "Mas continua mais barato que um atleta no auge")
        XCTAssertEqual(career.askingBaseValue(for: prime), prime.marketValue, "Quem está no auge paga o valor de mercado")
    }

    // MARK: - Rodízio

    func testRotationSwapsReplaceATiredStarterWithARestedReserveOfTheSamePosition() throws {
        var career = career(club: 10, seed: 21)
        for index in career.players.indices where career.players[index].teamID == 10 { career.players[index].condition = 100 }
        let starterID = try XCTUnwrap(career.startingXI.first { id in
            guard let player = career.player(id), player.position != .goalkeeper else { return false }
            return career.clubRoster.contains { !career.startingXI.contains($0.id) && $0.position == player.position }
        })
        let index = try XCTUnwrap(career.players.firstIndex { $0.id == starterID })
        career.players[index].condition = 35
        // Um reserva da mesma posição com o mesmo geral do titular, descansado.
        let reserveIndex = try XCTUnwrap(career.players.firstIndex {
            $0.teamID == 10 && !$0.isYouth && !career.startingXI.contains($0.id) && $0.position == career.players[index].position
        })
        career.players[reserveIndex].overall = career.players[index].overall
        let swaps = career.rotationSwaps(for: career.startingXI)
        let swap = try XCTUnwrap(swaps.first { $0.outgoingID == starterID }, "O titular cansado tem troca sugerida")
        XCTAssertFalse(career.startingXI.contains(swap.incomingID))
        XCTAssertEqual(career.player(swap.incomingID)?.position, career.player(starterID)?.position)
        var lineup = career.startingXI
        for item in swaps { if let at = lineup.firstIndex(of: item.outgoingID) { lineup[at] = item.incomingID } }
        XCTAssertNil(career.lineupProblem(lineup), "Aplicar o rodízio mantém a escalação válida")
    }

    func testNoRotationIsSuggestedWhenEveryoneIsRested() {
        var career = career(club: 10, seed: 21)
        for index in career.players.indices where career.players[index].teamID == 10 { career.players[index].condition = 100 }
        XCTAssertTrue(career.rotationSwaps(for: career.startingXI).isEmpty)
    }
}
