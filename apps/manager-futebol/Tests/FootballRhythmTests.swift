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
}
