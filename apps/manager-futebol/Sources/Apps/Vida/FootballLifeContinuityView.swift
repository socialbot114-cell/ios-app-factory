import SwiftUI

/// Vida: projetos pessoais em andamento, custo dos bens e histórico de bem-estar (VID-02…06).
struct FootballLifeContinuityPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            projects
            if !career.world.coach.assets.isEmpty { assets }
            history
        }
    }

    private var projects: some View {
        FactoryPanel(title: "Projetos pessoais", systemImage: "books.vertical.fill") {
            let lines = career.personalProjectsSummary
            if lines.isEmpty {
                Text("Curso, livro e contratos de mídia aparecem aqui com o que falta e os prazos.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(lines, id: \.self) { Text($0).font(.subheadline) }
            if let offer = career.mediaContractOffer {
                let seasonStart = (career.season - 1) * FootballSeason.matchDaysPerSeason
                VStack(alignment: .leading, spacing: 6) {
                    Text("Proposta de comentarista").font(.subheadline.weight(.semibold))
                    Text("3 programas nos dias \(offer.appearanceDays.map { "\($0 - seasonStart + 1)" }.joined(separator: ", ")), bônus de \(FootballFormat.money(offer.bonusPerAppearance)) por programa além do cachê. Entram na sua agenda; faltar custa reputação, e duas faltas encerram o contrato.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Assinar contrato") {
                        if !career.acceptMediaContract() { onAlert("A proposta não está mais disponível.") }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("media-contract-accept")
                }
            }
        }
        .accessibilityIdentifier("life-projects")
    }

    private var assets: some View {
        FactoryPanel(title: "Bens · \(FootballFormat.money(career.assetUpkeepPerSeason))/temporada", systemImage: "house.lodge.fill") {
            ForEach(career.assetNotes()) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: item.asset.kind.symbol).frame(width: 22).foregroundStyle(FootballTheme.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.asset.kind.title).font(.subheadline.weight(.semibold))
                        Text(item.note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("life-assets")
    }

    private var history: some View {
        FactoryPanel(title: "Bem-estar e decisões", systemImage: "waveform.path.ecg") {
            let points = career.life.wellbeing
            if points.count >= 2 {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(points) { point in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.7))
                                .frame(height: max(2, 40 * Double(point.energy) / 100))
                            RoundedRectangle(cornerRadius: 2).fill(Color.red.opacity(0.6))
                                .frame(height: max(2, 40 * Double(point.stress) / 100))
                        }
                    }
                }
                .frame(height: 86, alignment: .bottom)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Energia e estresse nos últimos \(points.count) dias de jogo: energia \(points.last?.energy ?? 0), estresse \(points.last?.stress ?? 0).")
                Text("Verde: energia · vermelho: estresse, um par por dia de jogo.").font(.caption2).foregroundStyle(.secondary)
            }
            let log = career.life.log.suffix(6).reversed()
            if log.isEmpty { Text("As suas decisões pessoais ficam registradas aqui.").font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(log)) { entry in
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title).font(.caption.weight(.semibold))
                    Text(entry.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
        .accessibilityIdentifier("life-history")
    }
}
