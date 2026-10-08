import Foundation

// MARK: - Decisões do ritual de virada (PIL-03 v3)

extension OffseasonStep {
    /// As etapas que ainda pedem uma escolha do treinador, a partir da etapa atual, na ordem do ritual.
    /// Função pura: o modo Clássico mostra só essas num painel, em vez de passar por cada etapa.
    static func openDecisions(from step: OffseasonStep, contractsPending: Bool, iconPackPending: Bool,
                              holidayChosen: Bool, sponsorPending: Bool, campChosen: Bool) -> [OffseasonStep] {
        let decisions: [(step: OffseasonStep, pending: Bool)] = [
            (.contracts, contractsPending),
            (.iconPack, iconPackPending),
            (.holiday, !holidayChosen),
            (.sponsor, sponsorPending),
            (.preseason, !campChosen),
        ]
        return decisions.filter { $0.step.rawValue >= step.rawValue && $0.pending }.map { $0.step }
    }
}

extension FootballCareer {
    /// Decisões que ainda travam o ritual de virada, a partir da etapa atual; vazio fora da entressafra.
    var openOffseasonDecisions: [OffseasonStep] {
        guard let offseason else { return [] }
        return OffseasonStep.openDecisions(from: offseason.step,
                                           contractsPending: !expiringContractPlayers.isEmpty,
                                           iconPackPending: iconState.pendingPack != nil,
                                           holidayChosen: offseason.holiday != nil,
                                           sponsorPending: !sponsorOffers.isEmpty,
                                           campChosen: offseason.camp != nil)
    }
}
