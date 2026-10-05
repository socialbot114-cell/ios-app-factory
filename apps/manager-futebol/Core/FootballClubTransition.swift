import Foundation

// MARK: - Troca de clube e projetos da F4 (F4-07)

extension FootballCareer {
    /// Encerra o que pertencia ao clube anterior: loja, naming rights, programas, coleção, gerente e reuniões.
    /// A vida pessoal (agenda, bens, investimentos) acompanha o treinador.
    mutating func resetClubProjects(using random: inout FootballRandom) {
        let history = world.business.friendlies
        let nextID = world.business.nextID
        world.business = BusinessState()
        world.business.friendlies = history
        world.business.nextID = nextID
        refreshNamingOffers(using: &random)

        for index in world.commercial.collections.indices where world.commercial.collections[index].isActive {
            world.commercial.collections[index].verdict = .below
        }
        world.commercial.delegation = nil
        settleCoachLoansOnDeparture()
        cancelTransferRaces()
        cancelTransferTalks()
        transitionContactsToNewClub()
        for index in world.commercial.ledger.indices { world.commercial.ledger[index].closed = true }

        for index in world.projects.meetings.indices where world.projects.meetings[index].isOpen {
            world.projects.meetings[index].status = .closed
            world.projects.meetings[index].resolution = "Encerrado com a saída do clube."
        }
    }
}
