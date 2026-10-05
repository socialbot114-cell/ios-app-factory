import Foundation

// MARK: - Compromissos e ações agendadas (F1-03/F1-04)

enum CommitmentKind: String, Codable, Equatable {
    case playerMinutes, negotiationCounter, followUp, boardRequest, transferRace, transferTalk
}

enum CommitmentState: String, Codable, Equatable {
    case open, fulfilled, broken, expired, cancelled
}

struct Commitment: Codable, Equatable, Identifiable {
    let id: Int
    let kind: CommitmentKind
    var playerID: Int?
    var factID: String?
    let createdWorldDay: Int
    let deadlineWorldDay: Int
    var state: CommitmentState = .open
    var resolvedWorldDay: Int? = nil
    var title: String
    var detail: String
}

/// Ordem explícita de processamento ao avançar o calendário (F1-04).
enum CalendarStep: Int, CaseIterable, Equatable {
    case events, offers, promises, commitments, negotiations, contracts
}

extension FootballCareer {
    static let calendarProcessingOrder = CalendarStep.allCases

    var openCommitments: [Commitment] { commitments.filter { $0.state == .open } }

    @discardableResult
    mutating func openCommitment(kind: CommitmentKind, playerID: Int? = nil, factID: String? = nil, days: Int, title: String, detail: String) -> Commitment {
        let commitment = Commitment(id: nextCommitmentID, kind: kind, playerID: playerID, factID: factID, createdWorldDay: worldDay,
                                    deadlineWorldDay: worldDay + max(1, days), title: title, detail: detail)
        nextCommitmentID += 1
        commitments.append(commitment)
        if commitments.count > Self.commitmentLimit {
            // Retenção: os já concluídos mais antigos saem primeiro.
            if let index = commitments.firstIndex(where: { $0.state != .open }) { commitments.remove(at: index) }
        }
        return commitment
    }

    /// Conclui um compromisso uma única vez; depois de concluído, nenhum outro desfecho vale.
    @discardableResult
    mutating func resolveCommitment(id: Int, as state: CommitmentState) -> Bool {
        guard state != .open, let index = commitments.firstIndex(where: { $0.id == id }), commitments[index].state == .open else { return false }
        commitments[index].state = state
        commitments[index].resolvedWorldDay = worldDay
        return true
    }

    /// Vence os compromissos abertos cujo prazo passou, em ordem de prazo e depois de ID. Devolve o que venceu.
    @discardableResult
    mutating func expireDueCommitments() -> [Commitment] {
        let due = commitments.filter { $0.state == .open && $0.deadlineWorldDay <= worldDay }
            .sorted { $0.deadlineWorldDay != $1.deadlineWorldDay ? $0.deadlineWorldDay < $1.deadlineWorldDay : $0.id < $1.id }
        var expired: [Commitment] = []
        for item in due where resolveCommitment(id: item.id, as: .expired) {
            expired.append(item)
            handleExpired(item)
        }
        return expired
    }

    private mutating func handleExpired(_ commitment: Commitment) {
        switch commitment.kind {
        case .negotiationCounter:
            expireTalks(forCommitment: commitment.id)
        case .followUp:
            handleFollowUpExpired(commitment)
        default:
            break
        }
    }
}
