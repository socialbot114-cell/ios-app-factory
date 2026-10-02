import SwiftUI

struct CrimeCrewView: View {
    let store: CrimeGameStore

    private var state: CrimeState { store.state }
    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NoirResourceBar(state: state)
            NoirSectionTitle(eyebrow: "Laços de sangue (falso)", title: "Família",
                             subtitle: "Recrute e promova com respeito. A família continua com você mesmo depois de uma nova identidade.")
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(CrimeCrewMember.catalog) { member in
                    CrimeCrewCard(store: store, member: member)
                }
            }
        }
        .noirPage()
    }
}

struct CrimeCrewCard: View {
    let store: CrimeGameStore
    let member: CrimeCrewMember

    private var state: CrimeState { store.state }
    private var level: Int { state.crewLevels[member.id] }
    private var tint: Color { Noir.districtTints[member.id % Noir.districtTints.count] }

    var body: some View {
        NoirCard(tint: tint, highlighted: level == 0 && state.canUpgradeCrew(member.id)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [tint.opacity(level > 0 ? 0.55 : 0.12), Noir.ink], startPoint: .top, endPoint: .bottom))
                    Image(systemName: level > 0 ? member.symbol : "person.fill.questionmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(level > 0 ? .white : Noir.muted)
                }
                .frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(tint.opacity(level > 0 ? 0.9 : 0.25), lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.role.uppercased()).font(.caption2.weight(.heavy)).tracking(1.4).foregroundStyle(tint)
                    Text(member.name).font(.title3.weight(.heavy))
                    levelPips
                }
            }
            Text("“\(member.quote)”")
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level > 0 ? member.effectDescription(level: level) : "Ainda não está na família")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(level > 0 ? Noir.money : Noir.muted)
                    if level < CrimeCrewMember.maxLevel {
                        Text("Próximo: \(member.effectDescription(level: level + 1))")
                            .font(.caption).foregroundStyle(Noir.muted)
                    }
                }
                Spacer(minLength: 4)
                if let cost = state.crewUpgradeCost(member.id) {
                    Button { store.upgradeCrew(member.id) } label: {
                        VStack(spacing: 1) {
                            Text(level == 0 ? "Recrutar" : "Promover")
                            Text("\(CrimeFormat.short(cost)) ★").font(.caption2.weight(.semibold))
                        }
                    }
                    .buttonStyle(NoirButtonStyle(tint: tint, compact: true))
                    .disabled(!state.canUpgradeCrew(member.id))
                    .accessibilityLabel("\(level == 0 ? "Recrutar" : "Promover") \(member.name)")
                    .accessibilityIdentifier("crew-\(member.id)")
                } else {
                    NoirChip(symbol: "crown.fill", text: "NÍVEL MÁX", tint: Noir.gold)
                }
            }
        }
    }

    private var levelPips: some View {
        HStack(spacing: 3) {
            ForEach(0..<CrimeCrewMember.maxLevel, id: \.self) { pip in
                Capsule()
                    .fill(pip < level ? tint : Color.white.opacity(0.1))
                    .frame(width: 12, height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Nível \(level) de \(CrimeCrewMember.maxLevel)")
    }
}
