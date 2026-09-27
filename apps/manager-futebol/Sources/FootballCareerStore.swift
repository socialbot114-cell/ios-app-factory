import Foundation

enum FootballCareerStore {
    static let saveKey = "football.career.v2"
    private static let legacySeedKey = "football.seed"
    private static let legacyRoundKey = "football.currentRound"

    static func load(defaults: UserDefaults = .standard) -> FootballCareer {
        if let data = defaults.data(forKey: saveKey),
           let career = try? JSONDecoder().decode(FootballCareer.self, from: data),
           isUsable(career) {
            return career
        }

        let seed = defaults.object(forKey: legacySeedKey) as? Int ?? 26
        let legacyCompletedRounds = defaults.object(forKey: legacyRoundKey) as? Int ?? 0
        let completedRounds = min(FootballGame.numberOfRounds, max(0, legacyCompletedRounds))
        var career = FootballGame.newCareer(seed: seed)
        for _ in 0..<completedRounds {
            guard FootballGame.simulateNextRound(career: &career) != nil else { break }
        }
        return career
    }

    static func save(_ career: FootballCareer, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(career) else { return }
        defaults.set(data, forKey: saveKey)
    }

    static func isUsable(_ career: FootballCareer) -> Bool {
        guard career.saveVersion == FootballCareer.currentSaveVersion,
              (1...1_000_000).contains(career.seasonNumber),
              (0...FootballGame.numberOfRounds).contains(career.completedRounds),
              (0...40_000_000).contains(career.budget),
              career.teams.count == 8,
              Set(career.teams.map(\.id)) == Set(0..<8),
              career.teams.allSatisfy({ team in
                  (team.id == career.userTeamID ? (16...18).contains(team.players.count) : team.players.count == 16)
                      && Set(team.players.map(\.id)).count == team.players.count
                      && FootballPosition.allCases.allSatisfy { position in
                          let minimum = position == .goalkeeper ? 1 : (position == .defender ? 4 : (position == .midfielder ? 5 : 3))
                          return team.players.filter { $0.position == position }.count >= minimum
                      }
                      && team.players.allSatisfy { player in
                          (18...120).contains(player.age)
                              && (35...95).contains(player.attack)
                              && (35...95).contains(player.defense)
                              && (35...95).contains(player.passing)
                              && (35...95).contains(player.stamina)
                              && (0...100).contains(player.condition)
                      }
              }),
              Set(career.teams.flatMap { $0.players.map(\.id) }).count == career.teams.reduce(0, { $0 + $1.players.count }),
              career.marketPlayers.count <= 8,
              Set(career.marketPlayers.map(\.id)).count == career.marketPlayers.count,
              Set(career.teams.flatMap { $0.players.map(\.id) }).isDisjoint(with: Set(career.marketPlayers.map(\.id))),
              career.marketPlayers.allSatisfy({ player in
                  player.id.hasPrefix("FA-")
                      && (18...120).contains(player.age)
                      && (35...95).contains(player.attack)
                      && (35...95).contains(player.defense)
                      && (35...95).contains(player.passing)
                      && (35...95).contains(player.stamina)
                      && (0...100).contains(player.condition)
              }),
              career.fixtures.count == FootballGame.numberOfRounds * FootballGame.matchesPerRound,
              Set(career.fixtures.map(\.id)) == Set(0..<(FootballGame.numberOfRounds * FootballGame.matchesPerRound)),
              career.fixtures.allSatisfy({ fixture in
                  (1...FootballGame.numberOfRounds).contains(fixture.round)
                      && fixture.homeTeamID != fixture.awayTeamID
                      && (0..<8).contains(fixture.homeTeamID)
                      && (0..<8).contains(fixture.awayTeamID)
                      && ((fixture.result != nil) == (fixture.round <= career.completedRounds))
                      && (fixture.result.map { result in
                          guard (0...8).contains(result.homeGoals),
                                (0...8).contains(result.awayGoals),
                                (0...30).contains(result.homeShots),
                                (0...30).contains(result.awayShots),
                                (20...80).contains(result.homePossession),
                                result.goalEvents.count == result.homeGoals + result.awayGoals else { return false }
                          return result.goalEvents.allSatisfy { event in
                              guard event.minute > 0 && event.minute <= 90,
                                    event.teamID == fixture.homeTeamID || event.teamID == fixture.awayTeamID,
                                    let team = career.teams.first(where: { $0.id == event.teamID }) else { return false }
                              return team.players.contains(where: { $0.id == event.playerID })
                          }
                      } ?? true)
              }),
              career.teams.contains(where: { $0.id == career.userTeamID }),
              let userTeam = career.teams.first(where: { $0.id == career.userTeamID }),
              FootballGame.isValidLineup(career.startingLineup, team: userTeam, formation: career.formation) else { return false }

        return true
    }
}
