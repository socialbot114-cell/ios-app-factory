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
                        Button("Pular coletiva") { career.skipPress(); dismiss() }
                            .buttonStyle(.bordered)
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
}
