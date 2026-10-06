import SwiftUI

// MARK: - Patrocínio

struct FootballSponsorView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryPanel(title: "Patrocinador master", systemImage: "megaphone.fill") {
                if let deal = career.sponsorDeal {
                    Text(deal.sponsor).font(.title3.bold())
                    Text("\(FootballFormat.money(deal.fixedPerSeason)) fixos · \(FootballFormat.money(deal.bonusPerWin)) por vitória · \(FootballFormat.money(deal.titleBonus)) pelo título · até a T\(deal.endSeason)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Sem contrato. Escolha uma proposta abaixo.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            FactoryPanel(title: "Propostas", systemImage: "envelope.fill") {
                if career.sponsorOffers.isEmpty { Text("Novas propostas chegam no fim da temporada.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(career.sponsorOffers) { offer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(offer.sponsor).font(.subheadline.weight(.bold))
                            Spacer()
                            PillLabel(text: offer.profile, tint: .indigo)
                        }
                        Text("\(FootballFormat.money(offer.fixedPerSeason)) fixos · \(FootballFormat.money(offer.bonusPerWin))/vitória · \(FootballFormat.money(offer.titleBonus)) pelo título · \(offer.seasons) temp.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Assinar") {
                            if !career.acceptSponsorOffer(offer.id) { onAlert("Não foi possível assinar esta proposta agora.") }
                        }
                        .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                    }
                    if offer.id != career.sponsorOffers.last?.id { Divider() }
                }
            }
        }
        .factoryPage()
        .navigationTitle("Patrocínio")
    }
}
