import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballRoundProgressTests: XCTestCase {
    /// Subir uma posição, ganhar caixa e estar em 60% da meta: as três frases, nesta ordem (PIL-05).
    func testRoundWithGainsReadsInOrder() {
        let progress = FootballRoundProgress(positionBefore: 5, positionAfter: 4, cashChange: 750_000, objectiveProgress: 0.6)
        XCTAssertEqual(progress.lines, ["subiu uma posição", "caixa +R$ 750 mil", "meta da diretoria em 60%"])
    }

    /// Perder posições e caixa mostra o sinal de menos; mais de uma posição usa o plural.
    func testLossesAndPluralPositions() {
        let progress = FootballRoundProgress(positionBefore: 3, positionAfter: 7, cashChange: -120_000, objectiveProgress: nil)
        XCTAssertEqual(progress.lines, ["caiu 4 posições", "caixa -R$ 120 mil"])
    }

    /// Rodada sem mudança nenhuma não gera faixa; a meta fica entre 0% e 100%.
    func testQuietRoundGivesNoLinesAndTheGoalIsCapped() {
        XCTAssertTrue(FootballRoundProgress(positionBefore: 2, positionAfter: 2, cashChange: 0, objectiveProgress: nil).lines.isEmpty)
        XCTAssertEqual(FootballRoundProgress(positionBefore: 2, positionAfter: 2, cashChange: 0, objectiveProgress: 1.3).lines, ["meta da diretoria em 100%"])
    }

    /// As fotos de antes e de depois montam a faixa na mesma ordem (PIL-05 v2): posição e caixa, sem meta medida.
    func testSnapshotsBuildTheBandInOrder() {
        let before = FootballRoundSnapshot(position: 5, cash: 1_000_000, objectiveProgress: nil)
        let after = FootballRoundSnapshot(position: 4, cash: 1_750_000, objectiveProgress: nil)
        XCTAssertEqual(FootballRoundProgress(before: before, after: after).lines, ["subiu uma posição", "caixa +R$ 750 mil"])
    }

    /// Fotos iguais não geram faixa.
    func testSameSnapshotsGiveNoLines() {
        let snapshot = FootballRoundSnapshot(position: 2, cash: 500_000, objectiveProgress: nil)
        XCTAssertTrue(FootballRoundProgress(before: snapshot, after: snapshot).lines.isEmpty)
    }
}
