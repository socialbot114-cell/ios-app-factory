import SwiftUI

/// Botão secundário do jogo: texto verde sobre um fundo do mesmo verde, com contraste nos dois temas.
/// No tema escuro o texto usa um verde mais claro, porque o verde de destaque quase some sobre o próprio fundo.
struct FootballSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let destructive = configuration.role == .destructive
        let ink: Color = destructive
            ? (scheme == .dark ? Color(red: 1.0, green: 0.55, blue: 0.52) : Color(red: 0.72, green: 0.10, blue: 0.10))
            : (scheme == .dark ? Color(red: 0.55, green: 0.90, blue: 0.70) : FootballTheme.accent)
        let fill: Color = destructive ? .red : (scheme == .dark ? Color(red: 0.30, green: 0.78, blue: 0.55) : FootballTheme.accent)
        configuration.label
            .foregroundStyle(ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(fill.opacity(configuration.isPressed ? 0.30 : 0.16), in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
    }
}
