import SwiftUI

// MARK: - Coletiva de imprensa

struct FootballPressView: View {
    @Binding var career: FootballCareer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let press = career.pendingPress {
                        Text("Os jornalistas esperam suas respostas. O tom que você escolhe mexe com o vestiário, a torcida e o rival.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(press.questions) { question in
                            FactoryPanel(title: question.prompt, systemImage: "mic.fill") {
                                if let answered = question.answered {
                                    Label("Você respondeu: \(answered.title)", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.subheadline)
                                } else {
                                    ForEach(PressTone.allCases) { tone in
                                        Button { career.answerPress(questionID: question.id, tone: tone) } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(tone.title).font(.subheadline.weight(.bold))
                                                Text(question.topic?.hint(for: tone) ?? tone.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                                effectChips(tone.baseEffects(result: press.result ?? .draw, isDerby: press.isDerby))
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(12)
                                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("press-\(question.id)-\(tone.rawValue)")
                                    }
                                }
                            }
                        }
                        let pending = press.questions.filter { $0.answered == nil }
                        if pending.count >= 2 {
                            Button {
                                for question in pending { career.answerPress(questionID: question.id, tone: .calm) }
                            } label: {
                                Label("Responder todas com o tom Calmo", systemImage: "text.bubble.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("press-answer-all")
                        }
                        Button("Pular coletiva") { career.skipPress(); dismiss() }
                            .buttonStyle(FootballSecondaryButtonStyle())
                            .accessibilityIdentifier("press-skip")
                    }
                }
                .padding(20)
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Coletiva")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: career.pendingPress == nil) { _, isGone in if isGone { dismiss() } }
        }
        .tint(FootballTheme.accent)
    }

    /// O que o tom faz sozinho: variação de torcida, diretoria e moral, e o rival quando o tom o provoca.
    /// O tema da pergunta pode somar ou tirar um pouco.
    private func effectChips(_ effects: [PressEffectPreview]) -> some View {
        HStack(spacing: 6) {
            ForEach(effects) { effect in
                HStack(spacing: 4) {
                    Text(effect.label).font(.caption2.weight(.semibold))
                    if let delta = effect.delta {
                        Text(delta > 0 ? "+\(delta)" : "\(delta)")
                            .font(.caption2.weight(.heavy).monospacedDigit())
                            .foregroundStyle(delta > 0 ? Color.green : Color.red)
                    } else if let note = effect.note {
                        Text(note).font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.primary.opacity(0.08), in: Capsule())
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Efeito: " + effects.map { effect in
            effect.label + " " + (effect.delta.map { $0 > 0 ? "mais \($0)" : "menos \(-$0)" } ?? (effect.note ?? ""))
        }.joined(separator: ", "))
    }
}
