import AVFoundation
import UIKit
import UserNotifications

/// Efeitos sonoros curtos. Usa a categoria ambient: respeita o modo silencioso e não corta a música do jogador.
@MainActor
enum CrimeSound: String, CaseIterable {
    case tap, crit, buy, click, success, fail, levelup

    static let preferenceKey = "crime.sound.enabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: preferenceKey) }
    }

    private static var players: [CrimeSound: [AVAudioPlayer]] = [:]
    private static var configured = false

    private static func configure() {
        guard !configured else { return }
        configured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for sound in allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { continue }
            // Alguns sons tocam em rajada (toques rápidos); um pequeno pool evita cortar o anterior.
            let copies = sound == .tap || sound == .buy || sound == .click ? 4 : 1
            players[sound] = (0..<copies).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play() {
        guard Self.isEnabled, !FactoryCapture.isUITesting else { return }
        Self.configure()
        guard let pool = Self.players[self], !pool.isEmpty else { return }
        let player = pool.first { !$0.isPlaying } ?? pool[0]
        player.currentTime = 0
        player.volume = self == .tap ? 0.6 : 0.9
        player.play()
    }
}

/// Lembretes locais: golpe pronto, cofre cheio e envelope diário.
enum CrimeNotifications {
    private static let ids = ["crime.heist", "crime.vault", "crime.daily"]

    static func requestPermission() {
        guard !FactoryCapture.isUITesting, FactoryCapture.screen == nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func clear() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.setBadgeCount(0)
    }

    /// Agenda os lembretes a partir do estado no momento em que o jogador sai do app.
    static func schedule(for state: CrimeState, now: Date = Date()) {
        guard !FactoryCapture.isUITesting, FactoryCapture.screen == nil else { return }
        clear()
        if let heist = state.activeHeist, heist.remaining > 5 {
            add(id: "crime.heist", title: "A equipe voltou",
                body: "\(CrimeHeist.catalog[heist.heistID].name) terminou. Deu certo? Venha revelar.", after: heist.remaining)
        }
        if state.incomePerSecond > 0 {
            add(id: "crime.vault", title: "Os cofres estão cheios",
                body: "Seus gerentes não têm mais onde guardar dinheiro. Passe para recolher.", after: state.offlineCapSeconds)
        }
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: tomorrow) {
            add(id: "crime.daily", title: "O Padrinho deixou um envelope",
                body: "Seu bônus diário está esperando. Não quebre a sequência!", after: evening.timeIntervalSince(now))
        }
    }

    private static func add(id: String, title: String, body: String, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 5), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
