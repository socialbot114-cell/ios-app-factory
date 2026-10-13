import SwiftUI

@main
struct ManagerFutebolApp: App {
    init() {
        // Nos UI tests o guia de primeira carreira fica desligado; só o teste do guia o pede, com --first-run-guide.
        FootballCareer.firstRunGuideEnabled = !FactoryCapture.isUITesting || FactoryCapture.screen != nil
            || ProcessInfo.processInfo.arguments.contains("--first-run-guide")
    }

    var body: some Scene { WindowGroup { FootballHome() } }
}
