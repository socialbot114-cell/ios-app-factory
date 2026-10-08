import SwiftUI

// MARK: - Faixa de desbloqueio (MRC-01)

/// Faixa do topo do celular com a conquista ou meta recém-concluída. Uma por vez, logo abaixo da barra de status.
/// Fica uns 4 segundos e sai sozinha; toque abre o app de destino; arrastar para cima ou fechar descarta.
struct PhoneUnlockBanner: View {
    let notice: UnlockNotice
    let onOpen: () -> Void
    let onDismiss: () -> Void
    /// Puxar a faixa para baixo abre o centro de notificações, como puxar a tela inicial.
    let onPull: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Vira verdadeiro ao aparecer e comanda a entrada da faixa.
    @State private var entered = false

    private var app: PhoneApp? { PhoneApp(rawValue: notice.appID) }
    private var eyebrow: String { notice.appID == PhoneApp.trophies.rawValue ? "CONQUISTA DESBLOQUEADA" : "META CUMPRIDA" }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Image(systemName: notice.symbol)
                        .font(.title3).foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background((app?.tint ?? FootballTheme.accent).gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eyebrow).font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                        Text(notice.title).font(.subheadline.weight(.bold)).lineLimit(1)
                        Text(notice.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(notice.title). \(notice.detail)")
            .accessibilityHint("Abre \(app?.title ?? "o app")")
            .accessibilityIdentifier("unlock-open")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar aviso")
            .accessibilityIdentifier("unlock-dismiss")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        // Confete leve. O componente também traz a vibração de sucesso e some com "reduzir movimento".
        .overlay { FootballCelebrationBurst(count: 24) }
        // Arrastar para cima descarta; puxar para baixo abre a central. Simultâneo: não rouba o toque nem a rolagem.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height < -20 {
                    onDismiss()
                } else if value.translation.height > 70 {
                    onPull()
                }
            }
        )
        .padding(.horizontal, 12)
        // Abaixo da barra de status, que fica nos primeiros pontos da tela.
        .padding(.top, 42)
        .offset(y: entered || reduceMotion ? 0 : -140)
        .opacity(entered || reduceMotion ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { entered = true }
        }
        // Sai da fila sozinha depois de uns 4 segundos. Se o treinador tocar ou fechar antes, a tarefa é cancelada.
        .task(id: notice.id) {
            // Na captura de tela a faixa fica parada, para o print mostrar o aviso.
            guard FactoryCapture.screen == nil else { return }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            onDismiss()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unlock-banner")
    }
}
