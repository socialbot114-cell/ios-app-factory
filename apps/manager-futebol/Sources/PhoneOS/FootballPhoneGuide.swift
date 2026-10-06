import SwiftUI

/// Notificação que desce do topo com a próxima coisa a fazer e leva o treinador direto ao app certo.
struct PhoneGuideBanner: View {
    let suggestion: FootballSuggestion
    let onGo: () -> Void
    let onDismiss: () -> Void

    private var app: PhoneApp? { PhoneApp(rawValue: suggestion.appID) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.symbol)
                .font(.title3).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background((app?.tint ?? FootballTheme.accent).gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("O QUE FAZER AGORA\(app.map { " · " + $0.title.uppercased() } ?? "")")
                    .font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                Text(suggestion.title).font(.subheadline.weight(.bold)).lineLimit(1)
                Text(suggestion.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            VStack(spacing: 6) {
                Button(suggestion.actionTitle, action: onGo)
                    .buttonStyle(.borderedProminent)
                    .tint(FootballTheme.accent)
                    .font(.caption.weight(.bold))
                    .accessibilityIdentifier("guide-go")
                Button("Depois", action: onDismiss)
                    .font(.caption2.weight(.semibold))
                    .accessibilityIdentifier("guide-dismiss")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-banner")
    }
}
