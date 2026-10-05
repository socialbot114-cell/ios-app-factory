import SwiftUI

/// Reunião com a diretoria no app Clube: pedido, resposta futura e condição acompanhada (F4-03 / CLB-02 / CLB-03).
struct FootballBoardMeetingPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        FactoryPanel(title: "Reunião com a diretoria", systemImage: "person.3.sequence.fill") {
            if let meeting = career.openBoardMeeting {
                openMeeting(meeting)
            } else {
                ForEach(BoardRequestKind.allCases) { kind in request(kind) }
            }
            let history = career.boardMeetings.filter { !$0.isOpen && $0.clubID == career.selectedClubID }.suffix(3).reversed()
            if !history.isEmpty {
                Divider()
                Text("Últimas reuniões").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(history)) { meeting in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("T\(meeting.season) · \(meeting.kind.title)").font(.caption.weight(.semibold))
                        Text([meeting.answer, meeting.resolution].filter { !$0.isEmpty }.joined(separator: " "))
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("board-meeting")
    }

    private func openMeeting(_ meeting: BoardMeeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(meeting.kind.title, systemImage: "hourglass").font(.subheadline.weight(.semibold))
            switch meeting.status {
            case .awaitingAnswer:
                let days = max(0, meeting.answerWorldDay - career.worldDay)
                Text(days == 0 ? "A resposta sai ao avançar o próximo dia de jogo." : "A diretoria responde em \(days) dia(s) de jogo.")
                    .font(.caption).foregroundStyle(.secondary)
            case .conditionRunning:
                Text(meeting.answer).font(.caption).fixedSize(horizontal: false, vertical: true)
                if let condition = meeting.condition {
                    ProgressView(value: Double(condition.gamesCounted), total: Double(condition.games))
                        .tint(condition.winsCounted >= condition.winsNeeded ? .green : .orange)
                    Text(condition.text).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            default:
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func request(_ kind: BoardRequestKind) -> some View {
        let blocker = career.boardMeetingBlocker(kind)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(kind.title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(career.boardMood(for: kind)).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }
            Text(kind == .budgetBoost ? "\(kind.pitch) Valor em pauta: \(FootballFormat.money(career.boardBoostAmount)); cumprir rende confiança, falhar custa caro."
                                      : kind.pitch)
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let blocker {
                Text(blocker).font(.caption2).foregroundStyle(.orange)
            }
            Button("Marcar reunião") {
                if !career.requestBoardMeeting(kind) { onAlert(blocker ?? "Não foi possível marcar a reunião.") }
            }
            .buttonStyle(.bordered)
            .disabled(blocker != nil)
            .accessibilityIdentifier("board-request-\(kind.rawValue)")
        }
    }
}
