import AVFoundation
import SwiftUI

// MARK: - Sons

/// Efeitos sonoros do jogo. Cada efeito é um arquivo `sfx-<nome>` (m4a, mp3 ou wav) dentro do app; sem o arquivo, não toca nada.
/// O jogador liga e desliga em Ajustes e na central de controle. Toca junto com a música do aparelho, sem pará-la.
enum FootballSoundCue: String, CaseIterable {
    case whistle, whistleFinal, goal, crowd, kickoff, nearMiss, kick, post

    var resourceName: String { "sfx-\(rawValue)" }
}

@MainActor
enum FootballSounds {
    /// Espelha a opção "Sons" da carreira; o `FootballHome` atualiza a cada mudança.
    static var enabled = true
    private static var players: [FootballSoundCue: AVAudioPlayer] = [:]
    private static var sessionReady = false
    private static var ambience: AVAudioPlayer?
    private static var lastPlay = Date.distantPast

    /// Lances pequenos não se atropelam: com o jogo acelerado só toca o efeito se o anterior já passou de um segundo.
    /// Gol e apitos tocam sempre.
    private static func isPriority(_ cue: FootballSoundCue) -> Bool {
        switch cue {
        case .goal, .whistle, .whistleFinal, .kickoff: return true
        default: return false
        }
    }

    /// Há arquivo de som no app para este efeito?
    static func hasFile(_ cue: FootballSoundCue) -> Bool {
        url(for: cue) != nil
    }

    private static func url(for cue: FootballSoundCue) -> URL? {
        for ext in ["m4a", "mp3", "wav", "caf"] {
            if let url = Bundle.main.url(forResource: cue.resourceName, withExtension: ext) { return url }
        }
        return nil
    }

    static func play(_ cue: FootballSoundCue) {
        guard enabled, !FactoryCapture.isUITesting, FactoryCapture.screen == nil, let url = url(for: cue) else { return }
        if !isPriority(cue), Date().timeIntervalSince(lastPlay) < 1 { return }
        prepareSession()
        lastPlay = Date()
        if players[cue] == nil { players[cue] = try? AVAudioPlayer(contentsOf: url) }
        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.volume = 0.8
        player.play()
    }

    private static func prepareSession() {
        guard !sessionReady else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        sessionReady = true
    }

    /// Torcida de fundo, baixinha e em repetição, enquanto a bola rola.
    static func startAmbience() {
        guard enabled, !FactoryCapture.isUITesting, FactoryCapture.screen == nil, let url = url(for: .crowd) else { return }
        prepareSession()
        if ambience == nil { ambience = try? AVAudioPlayer(contentsOf: url) }
        guard let ambience, !ambience.isPlaying else { return }
        ambience.numberOfLoops = -1
        ambience.volume = 0.22
        ambience.play()
    }

    static func stopAmbience() {
        ambience?.stop()
        ambience?.currentTime = 0
    }
}
