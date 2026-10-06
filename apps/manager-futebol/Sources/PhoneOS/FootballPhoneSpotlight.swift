import SwiftUI

// MARK: - Busca (Spotlight)

struct PhoneSpotlight: View {
    let career: FootballCareer
    let initialQuery: String
    let onApp: (PhoneApp) -> Void
    let onPlayer: (Int) -> Void
    var onContact: (Int) -> Void = { _ in }
    var onLeagueSection: (FootballTableView.LeagueSection) -> Void = { _ in }
    @State private var query = ""
    @State private var selectedClub: LeagueTeam?
    @Environment(\.dismiss) private var dismiss

    private func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private var term: String { normalized(query) }
    private func matches(_ text: String) -> Bool {
        let value = normalized(text)
        return term.split(separator: " ").allSatisfy { value.contains($0) }
    }

    /// Seções exatas da Liga (OS-03): abrem direto na aba pedida.
    private var leagueSections: [FootballTableView.LeagueSection] {
        term.count >= 2 ? FootballTableView.LeagueSection.allCases.filter { matches("Liga \($0.rawValue)") } : []
    }

    private var apps: [PhoneApp] { term.isEmpty ? [] : PhoneApp.allCases.filter { matches($0.title) } }

    private var players: [FootballPlayer] {
        guard term.count >= 2 else { return [] }
        return Array(career.players.filter { !$0.isYouth || $0.teamID == career.selectedClubID }
            .filter { matches($0.name) }.sorted { $0.overall == $1.overall ? $0.id < $1.id : $0.overall > $1.overall }.prefix(8))
    }

    private var clubs: [LeagueTeam] {
        guard term.count >= 2 else { return [] }
        return FootballSeason.teams.filter { matches("\($0.name) \($0.city)") }
    }

    private var contacts: [Contact] {
        guard term.count >= 2 else { return [] }
        return career.world.contacts.contacts.filter { matches("\($0.name) \($0.role.title)") }
    }

    var body: some View {
        NavigationStack {
            List {
                if term.isEmpty {
                    Text("Digite um nome: atleta, clube, contato ou app. Tudo no celular se encontra aqui.").font(.subheadline).foregroundStyle(.secondary)
                } else if term.count < 2 {
                    Text("Digite pelo menos dois caracteres para buscar atletas, clubes e contatos.").font(.subheadline).foregroundStyle(.secondary)
                }
                if !apps.isEmpty {
                    Section("Apps") {
                        ForEach(apps) { app in
                            Button { dismiss(); onApp(app) } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Label(app.title, systemImage: app.symbol)
                                    Text(app.purpose).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if !leagueSections.isEmpty {
                    Section("Seções") {
                        ForEach(leagueSections) { section in
                            Button { dismiss(); onLeagueSection(section) } label: { Label("Liga · \(section.rawValue)", systemImage: "list.number") }
                                .accessibilityIdentifier("search-league-\(section.id)")
                        }
                    }
                }
                if !players.isEmpty {
                    Section("Atletas") {
                        ForEach(players) { player in
                            Button { dismiss(); onPlayer(player.id) } label: {
                                HStack {
                                    RatingBadge(value: player.overall, size: 28)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(player.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        Text("\(player.position.title) · \(player.teamID.flatMap { FootballSeason.team($0)?.name } ?? "Livre")")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityIdentifier("search-player-\(player.id)")
                        }
                    }
                }
                if !clubs.isEmpty {
                    Section("Clubes") {
                        ForEach(clubs) { team in
                            Button { selectedClub = team } label: {
                                HStack { ClubCrest(team: team, size: 22); Text(team.name); Spacer(); Text(team.city).font(.caption).foregroundStyle(.secondary) }
                            }
                            .accessibilityIdentifier("search-club-\(team.id)")
                        }
                    }
                }
                if !contacts.isEmpty {
                    Section("Contatos") {
                        ForEach(contacts) { contact in
                             Button { dismiss(); onContact(contact.id) } label: { Label("\(contact.name) · \(contact.role.title)", systemImage: contact.role.symbol) }
                                .accessibilityIdentifier("search-contact-\(contact.id)")
                        }
                    }
                }
                if term.count >= 2 && apps.isEmpty && leagueSections.isEmpty && players.isEmpty && clubs.isEmpty && contacts.isEmpty {
                    Text("Nada encontrado para \"\(query)\". Tente parte do nome, a cidade do clube ou o papel do contato; acentos são opcionais.").foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar no celular")
            .navigationTitle("Busca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
            .onAppear { if query.isEmpty { query = initialQuery } }
        }
        .tint(FootballTheme.accent)
        .sheet(item: $selectedClub) { team in
            PhoneClubProfile(career: career, team: team)
        }
    }
}

/// Consulta pública do clube encontrado; não altera a carreira.
private struct PhoneClubProfile: View {
    let career: FootballCareer
    let team: LeagueTeam
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        ClubCrest(team: team, size: 48)
                        VStack(alignment: .leading) {
                            Text(team.name).font(.headline)
                            Text(team.city).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Divisão", value: career.division(of: team.id).name)
                    LabeledContent("Estádio", value: team.stadium)
                    LabeledContent("Força de referência", value: "\(team.strength)")
                }
                Section("Elenco da carreira") {
                    let players = career.players.filter { $0.teamID == team.id && !$0.isYouth }
                        .sorted { $0.overall == $1.overall ? $0.id < $1.id : $0.overall > $1.overall }
                    if players.isEmpty { Text("Nenhum atleta registrado neste elenco.").foregroundStyle(.secondary) }
                    ForEach(players) { player in
                        HStack {
                            Text(player.name)
                            Spacer()
                            Text(player.position.title).font(.caption).foregroundStyle(.secondary)
                            RatingBadge(value: player.overall, size: 28)
                        }
                    }
                }
            }
            .navigationTitle("Ficha do clube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
        .tint(FootballTheme.accent)
        .accessibilityIdentifier("club-profile-\(team.id)")
    }
}
