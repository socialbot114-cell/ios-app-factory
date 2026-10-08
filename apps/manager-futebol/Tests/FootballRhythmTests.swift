import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballRhythmTests: XCTestCase {
    /// Save antigo, sem a chave "rhythm": o ritmo fica em Imersivo, como sempre foi.
    func testOldSavesWithoutRhythmStayImmersive() throws {
        let data = try JSONEncoder().encode(PhonePreferences())
        let decoded = try JSONDecoder().decode(PhonePreferences.self, from: data)
        XCTAssertNil(decoded.rhythm)
        XCTAssertEqual(decoded.rhythmMode, .immersive)
    }

    /// A escolha de Clássico sobrevive a salvar e carregar.
    func testTheChosenRhythmSurvivesASaveRoundTrip() throws {
        var preferences = PhonePreferences()
        preferences.rhythm = .classic
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(PhonePreferences.self, from: data)
        XCTAssertEqual(decoded.rhythmMode, .classic)
        XCTAssertEqual(decoded, preferences)
    }

    /// O Clássico mostra menos partículas e termina antes na comemoração; o Imersivo mantém o efeito cheio.
    func testClassicCelebrationIsLighterAndShorterButNeverEmpty() {
        XCTAssertEqual(FootballRhythm.immersive.celebrationCount(64), 64)
        XCTAssertEqual(FootballRhythm.immersive.celebrationSeconds(1.6), 1.6, accuracy: 0.0001)
        XCTAssertEqual(FootballRhythm.classic.celebrationCount(64), 32)
        XCTAssertEqual(FootballRhythm.classic.celebrationCount(1), 1)
        XCTAssertLessThan(FootballRhythm.classic.celebrationSeconds(1.6), 1.6)
    }

    /// O Clássico lista menos pendências na tela de bloqueio; o Imersivo mantém as cinco de sempre.
    func testClassicLockScreenListsFewerPendingItems() {
        XCTAssertEqual(FootballRhythm.immersive.lockScreenItemLimit, 5)
        XCTAssertEqual(FootballRhythm.classic.lockScreenItemLimit, 2)
    }
}
