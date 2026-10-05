import Foundation
import XCTest
@testable import ManagerFutebol

/// F6: carreiras longas com os sistemas novos (fatos, compromissos, memória, negociação, projetos) sem consequência duplicada,
/// compromisso órfão ou crescimento sem limite do save.
final class FootballLongCareerTests: XCTestCase {
    private struct Report {
        var seasons = 0
        var fired = 0
        var maxFacts = 0
        var maxInbox = 0
        var maxSaveBytes = 0
    }

    /// Joga `seasons` temporadas fazendo escolhas variadas: promessas, conversas de renovação, respostas a pedidos e sacadas.
    private func play(seed: Int, club: Int, seasons: Int, difficulty: Difficulty) throws -> (FootballCareer, Report) {
        var career = FootballCareer(seed: seed)
        career.difficulty = difficulty
        XCTAssertTrue(career.chooseClub(club))
        var report = Report()
        var choice = FootballRandom(seed: UInt64(seed) &* 7_919 &+ 13)
        for _ in 0..<seasons {
            var guardDays = 0
            while !career.isSeasonComplete && guardDays < FootballSeason.matchDaysPerSeason + 5 {
                guardDays += 1
                if career.isFired {
                    report.fired += 1
                    if let job = career.jobOffers.first { _ = career.acceptJob(job.id) } else { break }
                }
                try playDecisions(&career, using: &choice)
                if career.canPlay || career.canAdvanceWithoutPlaying {
                    XCTAssertTrue(career.simulateNextMatchDay(), "Dia \(career.matchDayIndex) da temporada \(career.season)")
                    career.skipPress()
                } else { break }
                report.maxFacts = max(report.maxFacts, career.factStore.facts.count)
                report.maxInbox = max(report.maxInbox, career.inbox.count)
            }
            guard career.isSeasonComplete else { break }
            XCTAssertNotNil(career.startNextSeason())
            report.seasons += 1
            report.maxSaveBytes = max(report.maxSaveBytes, try JSONEncoder().encode(career).count)
            try assertInvariants(career)
        }
        return (career, report)
    }

    private func playDecisions(_ career: inout FootballCareer, using random: inout FootballRandom) throws {
        guard career.selectedClubID != nil, !career.isFired, career.liveMatch == nil else { return }
        // Responde pedidos de minutos: ora promete, ora recusa, ora ignora.
        for message in career.inbox where message.kind == .playerPlayingTime && !message.isResolved {
            guard let id = message.playerID else { continue }
            switch random.int(in: 0...2) {
            case 0: _ = career.promiseStarts(playerID: id, starts: 2)
            case 1: career.dismissRequest(playerID: id)
            default: break
            }
        }
        // Abre conversas de renovação para quem tem contrato acabando e responde às contrapropostas.
        for athlete in career.clubRoster where athlete.contract.endSeason <= career.season && career.openTalk(for: athlete.id) == nil && random.chance(0.5) {
            guard let talk = career.startRenewalTalk(playerID: athlete.id) else { continue }
            let wage = Int(Double(talk.askWage) * (random.chance(0.5) ? 0.95 : 1.02) / 5_000) * 5_000
            _ = career.proposeInTalk(talkID: talk.id, wage: wage, years: talk.askYears, status: talk.askStatus)
        }
        for talk in career.talks where talk.stage == .counter && random.chance(0.6) { _ = career.acceptCounter(talkID: talk.id) }
        // Conversa com quem ficou ressentido.
        for commitment in career.openCommitments where commitment.kind == .followUp && random.chance(0.5) { _ = career.holdMeeting(commitmentID: commitment.id) }
        // Dispensa avisos já lidos.
        for message in career.inbox.prefix(5) where !message.kind.needsResponse { _ = career.dismissMessage(id: message.id) }
    }

    private func assertInvariants(_ career: FootballCareer, file: StaticString = #filePath, line: UInt = #line) throws {
        guard let clubID = career.selectedClubID else { return }
        // Retenção
        XCTAssertLessThanOrEqual(career.factStore.facts.count, FactStore.limit, file: file, line: line)
        XCTAssertLessThanOrEqual(career.inbox.count, 80, file: file, line: line)
        XCTAssertLessThanOrEqual(career.commitments.count, FootballCareer.commitmentLimit + career.openCommitments.count, file: file, line: line)
        for (_, group) in Dictionary(grouping: career.playerMemories, by: \.playerID) {
            XCTAssertLessThanOrEqual(group.count, FootballCareer.memoryPerPlayerLimit, file: file, line: line)
        }
        // Sem duplicidade
        XCTAssertEqual(Set(career.factStore.facts.map(\.id)).count, career.factStore.facts.count, "Fatos duplicados", file: file, line: line)
        XCTAssertEqual(Set(career.playerMemories.map(\.id)).count, career.playerMemories.count, "Memórias duplicadas", file: file, line: line)
        XCTAssertEqual(Set(career.commitments.map(\.id)).count, career.commitments.count, "Compromissos duplicados", file: file, line: line)
        XCTAssertEqual(Set(career.talks.map(\.id)).count, career.talks.count, file: file, line: line)
        // Sem compromisso órfão: abertos têm prazo no futuro (ou no dia) e o atleta ainda é do clube.
        for item in career.openCommitments {
            XCTAssertGreaterThan(item.deadlineWorldDay, career.worldDay - 1, "Compromisso vencido ainda aberto: \(item.title)", file: file, line: line)
            if let id = item.playerID, item.kind == .followUp || item.kind == .negotiationCounter {
                XCTAssertEqual(career.player(id)?.teamID, clubID, "Compromisso aberto de atleta que saiu: \(item.title)", file: file, line: line)
            }
        }
        for talk in career.talks where talk.stage.isOpen {
            XCTAssertEqual(career.player(talk.playerID)?.teamID, clubID, "Conversa aberta de atleta que saiu", file: file, line: line)
            XCTAssertGreaterThanOrEqual(talk.expiresWorldDay, career.worldDay - 1, "Conversa vencida ainda aberta", file: file, line: line)
        }
        for promise in career.promises {
            XCTAssertEqual(career.player(promise.playerID)?.teamID, clubID, "Promessa de atleta que saiu", file: file, line: line)
        }
        XCTAssertTrue((0...100).contains(career.clubHype) && (0...100).contains(career.fanMood) && (0...100).contains(career.boardConfidence), file: file, line: line)
    }

    func testTenSeasonsAcrossSeedsAndDifficultiesKeepTheWorldCoherent() throws {
        var summaries: [String] = []
        for (seed, club, difficulty) in [(11, 0, Difficulty.normal), (23, 12, .hard), (37, 5, .easy)] {
            let (career, report) = try play(seed: seed, club: club, seasons: 10, difficulty: difficulty)
            XCTAssertEqual(report.seasons, 10, "Seed \(seed): terminou todas as temporadas")
            XCTAssertLessThan(report.maxSaveBytes, 6_000_000, "Seed \(seed): save de \(report.maxSaveBytes) bytes")
            XCTAssertLessThanOrEqual(report.maxFacts, FactStore.limit)
            let reopened = try JSONDecoder().decode(FootballCareer.self, from: JSONEncoder().encode(career))
            XCTAssertEqual(reopened.factStore, career.factStore)
            XCTAssertEqual(reopened.commitments, career.commitments)
            XCTAssertEqual(reopened.talks, career.talks)
            XCTAssertEqual(reopened.playerMemories, career.playerMemories)
            try assertInvariants(reopened)
            summaries.append("seed \(seed): temporada \(career.season), save \(report.maxSaveBytes / 1024) KB, fatos \(career.factStore.facts.count), demissões \(report.fired)")
        }
        print("F6-01/04: " + summaries.joined(separator: " | "))
    }

    func testSameChoicesGiveTheSameCareer() throws {
        let first = try play(seed: 19, club: 3, seasons: 3, difficulty: .normal).0
        let second = try play(seed: 19, club: 3, seasons: 3, difficulty: .normal).0
        XCTAssertEqual(first.factStore, second.factStore)
        XCTAssertEqual(first.commitments, second.commitments)
        XCTAssertEqual(first.playerMemories, second.playerMemories)
        XCTAssertEqual(first.talks, second.talks)
        XCTAssertEqual(first.reputation, second.reputation)
    }
}
