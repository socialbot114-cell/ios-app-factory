import SwiftUI

extension FootballCareer {
    /// Linha de contexto no topo de cada app: onde a carreira está no calendário.
    var screenContext: String {
        if isSeasonComplete { return "Temporada \(season) · fim de campanha" }
        if let slot = currentSlot {
            if let round = slot.leagueRound { return "Temporada \(season) · rodada \(round)" }
            if let cup = slot.cupRound { return "Temporada \(season) · \(cup.name.lowercased())" }
        }
        return "Temporada \(season)"
    }
}

/// Cabeçalho padrão dos apps: contexto do calendário, título e uma frase de apoio.
struct FootballScreenHeader: View {
    let career: FootballCareer
    let title: String
    let subtitle: String

    var body: some View {
        FactoryHeader(eyebrow: career.screenContext, title: title, subtitle: subtitle, accent: FootballTheme.accent)
    }
}
