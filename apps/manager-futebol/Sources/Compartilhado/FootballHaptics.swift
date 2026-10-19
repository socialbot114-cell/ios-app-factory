import SwiftUI

// MARK: - Vibração com ajuste

/// A vibração do jogo respeita a escolha do jogador em Ajustes. O padrão é ligada.
private struct FootballHapticsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var footballHapticsEnabled: Bool {
        get { self[FootballHapticsEnabledKey.self] }
        set { self[FootballHapticsEnabledKey.self] = newValue }
    }
}

private struct FootballHapticModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.footballHapticsEnabled) private var enabled
    let feedback: SensoryFeedback
    let trigger: Trigger

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { _, _ in enabled ? feedback : nil }
    }
}

extension View {
    /// Igual a `sensoryFeedback`, mas desliga com a opção "Vibração" de Ajustes.
    func footballHaptic<Trigger: Equatable>(_ feedback: SensoryFeedback, trigger: Trigger) -> some View {
        modifier(FootballHapticModifier(feedback: feedback, trigger: trigger))
    }
}
