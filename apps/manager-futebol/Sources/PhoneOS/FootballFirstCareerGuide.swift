import SwiftUI

/// Dica curta e contextual do roteiro da primeira carreira. Não bloqueia controles nem navegação.
struct FirstCareerGuideCard: View {
    let step: FirstCareerGuideStep
    let onContinue: (() -> Void)?
    let onSkip: () -> Void

    private var position: String {
        switch step {
        case .welcome: return "ROTEIRO · PRIMEIRO JOGO"
        case .manager: return "Passo 1 de 4"
        case .tactics: return "Passo 2 de 4"
        case .match, .liveMatch: return "Passo 3 de 4"
        case .recap: return "Passo 4 de 4"
        case .finished, .skipped: return ""
        }
    }

    private var title: String {
        switch step {
        case .welcome: return "Sua primeira partida, passo a passo"
        case .manager: return "Comece no Gestor"
        case .tactics: return "Confira o time"
        case .match: return "Entre em campo"
        case .liveMatch: return "Você controla o relógio"
        case .recap: return "Veja o resultado e siga"
        case .finished, .skipped: return ""
        }
    }

    private var detail: String {
        switch step {
        case .welcome:
            return "Contrato fechado! Seu primeiro objetivo é chegar ao jogo. O calendário só avança quando você joga ou pede uma simulação."
        case .manager:
            return "O Gestor é o painel do dia. Toque em “Abrir Tática” para conferir titulares e formação antes do jogo."
        case .tactics:
            return "Confira titulares e formação. Depois volte ao Gestor; lá você pode preparar o rival ou ir direto para a partida."
        case .match:
            return "A escalação está pronta. Toque em “Jogar partida ao vivo”; preparar o rival é opcional."
        case .liveMatch:
            return "Começar/Pausar controla o relógio. “Ao final” simula o restante. Se sair, volte pelo Gestor; no apito, “Concluir rodada” avança o dia e mostra o resumo."
        case .recap:
            return "Confira o último resultado. No celular, os números nos apps mostram mensagens novas ou ações que merecem atenção."
        case .finished, .skipped:
            return ""
        }
    }

    private var continueTitle: String? {
        switch step {
        case .welcome: return "Abrir Gestor"
        case .manager: return "Abrir Tática"
        case .tactics: return "Voltar ao Gestor"
        case .match: return "Jogar partida ao vivo"
        case .liveMatch: return "Voltar à partida"
        case .recap: return "Concluir roteiro"
        case .finished, .skipped: return nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step == .liveMatch ? "play.rectangle.fill" : "hand.tap.fill")
                .foregroundStyle(FootballTheme.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(position.uppercased())
                        .font(.caption2.weight(.heavy)).tracking(0.8).foregroundStyle(FootballTheme.accent)
                    Spacer(minLength: 4)
                    Button("Pular") { onSkip() }
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("first-run-guide-skip")
                }
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let continueTitle, let onContinue {
                    Button(continueTitle) { onContinue() }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("first-run-guide-continue")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FootballTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("first-run-guide-\(step.rawValue)")
    }
}

/// Aviso FutOS breve após uma mudança de etapa; o cartão contextual continua disponível abaixo.
struct FirstCareerGuideToast: View {
    let step: FirstCareerGuideStep
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: step == .finished ? "checkmark.circle.fill" : "sparkles")
                .font(.title3).foregroundStyle(FootballTheme.accent)
                .frame(width: 38, height: 38)
                .background(FootballTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(step.toastTitle).font(.subheadline.weight(.bold))
                Text(step.toastDetail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    .frame(width: 30, height: 30).contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar dica do roteiro")
            .accessibilityIdentifier("first-run-toast-dismiss")
        }
        .padding(11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(FootballTheme.accent.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .task(id: step) {
            guard FactoryCapture.screen == nil else { return }
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            onDismiss()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("first-run-toast")
    }
}
