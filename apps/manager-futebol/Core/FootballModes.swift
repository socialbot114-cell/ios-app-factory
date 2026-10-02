import Foundation

// MARK: - Dificuldade

enum Difficulty: Int, Codable, CaseIterable, Identifiable {
    case easy = 0, normal, hard

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .easy: return "Fácil"
        case .normal: return "Normal"
        case .hard: return "Difícil"
        }
    }

    var summary: String {
        switch self {
        case .easy: return "Rivais mais fracos, diretoria paciente, receitas e preços de transferência melhores."
        case .normal: return "A experiência padrão do jogo."
        case .hard: return "Rivais mais fortes contra o seu clube, diretoria impaciente, receitas menores e mercado caro."
        }
    }

    /// Pontos de ataque e defesa somados aos rivais do clube do usuário.
    var aiBoost: Double {
        switch self {
        case .easy: return -1.5
        case .normal: return 0
        case .hard: return 1.5
        }
    }

    var incomeFactor: Double {
        switch self {
        case .easy: return 1.1
        case .normal: return 1.0
        case .hard: return 0.9
        }
    }

    var patienceShift: Int {
        switch self {
        case .easy: return -8
        case .normal: return 0
        case .hard: return 6
        }
    }

    var priceFactor: Double {
        switch self {
        case .easy: return 0.9
        case .normal: return 1.0
        case .hard: return 1.15
        }
    }
}

// MARK: - Desafios

enum GoalKind: String, Codable {
    case avoidRelegation, finishTop, winLeague, promotion, winCup, cashAtLeast
}

struct ChallengeGoal: Codable, Equatable {
    let kind: GoalKind
    let value: Int

    var text: String {
        switch kind {
        case .avoidRelegation: return "Evitar o rebaixamento"
        case .finishTop: return "Terminar entre os \(value) primeiros"
        case .winLeague: return "Ser campeão da liga"
        case .promotion: return "Conquistar o acesso"
        case .winCup: return "Vencer a Copa Nacional"
        case .cashAtLeast: return "Fechar a temporada com \(FootballFormat.money(value)) em caixa"
        }
    }
}

enum ChallengeStatus: String, Codable {
    case active, won, failed
}

struct ChallengeState: Codable, Equatable {
    let scenarioID: String
    let startSeason: Int
    let seasonsAllowed: Int
    var status: ChallengeStatus = .active
    var failureReason: String? = nil
    var wonInSeason: Int? = nil
}

struct ChallengeScenario: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let clubID: Int
    let seed: Int
    let startingCash: Int
    /// Soma ao geral de todo o elenco inicial.
    let squadOverallDelta: Int
    /// Idade máxima do elenco inicial (rejuvenesce quem passa).
    let youngSquadMaxAge: Int?
    /// Idade máxima permitida para os titulares durante todo o desafio.
    let maxStarterAge: Int?
    let wageCapFactor: Double?
    let goals: [ChallengeGoal]
    let seasonsAllowed: Int
    let difficulty: Difficulty

    static let all: [ChallengeScenario] = [
        ChallengeScenario(
            id: "capital-norte", title: "Salve o Capital Norte",
            summary: "O clube amazonense perdeu força e dinheiro. Escape do rebaixamento em uma temporada.",
            clubID: 6, seed: 9_101, startingCash: 900_000, squadOverallDelta: -3, youngSquadMaxAge: nil, maxStarterAge: nil,
            wageCapFactor: 1.05, goals: [ChallengeGoal(kind: .avoidRelegation, value: 0)], seasonsAllowed: 1, difficulty: .hard),
        ChallengeScenario(
            id: "so-garotos", title: "Campeão só com garotos",
            summary: "Só atletas de até 23 anos podem começar os jogos. Chegue ao pódio da Série A em duas temporadas.",
            clubID: 3, seed: 9_102, startingCash: 5_000_000, squadOverallDelta: -2, youngSquadMaxAge: 23, maxStarterAge: 23,
            wageCapFactor: nil, goals: [ChallengeGoal(kind: .finishTop, value: 3)], seasonsAllowed: 2, difficulty: .normal),
        ChallengeScenario(
            id: "orcamento-zero", title: "Orçamento zero",
            summary: "Sem dinheiro e com a folha no limite. Suba da Série B em duas temporadas.",
            clubID: 10, seed: 9_103, startingCash: 0, squadOverallDelta: 0, youngSquadMaxAge: nil, maxStarterAge: nil,
            wageCapFactor: 1.02, goals: [ChallengeGoal(kind: .promotion, value: 0)], seasonsAllowed: 2, difficulty: .normal),
        ChallengeScenario(
            id: "reconstrucao", title: "Reconstrução",
            summary: "O Atlético Cerrado está no vermelho. Em três temporadas, feche com caixa positivo e entre os seis primeiros.",
            clubID: 1, seed: 9_104, startingCash: -5_000_000, squadOverallDelta: -1, youngSquadMaxAge: nil, maxStarterAge: nil,
            wageCapFactor: 1.1, goals: [ChallengeGoal(kind: .finishTop, value: 6), ChallengeGoal(kind: .cashAtLeast, value: 1_000_000)],
            seasonsAllowed: 3, difficulty: .normal),
        ChallengeScenario(
            id: "rei-da-copa", title: "Rei da Copa",
            summary: "O Litoral FC sonha com um título. Vença a Copa Nacional em duas temporadas.",
            clubID: 8, seed: 9_105, startingCash: 4_000_000, squadOverallDelta: 1, youngSquadMaxAge: nil, maxStarterAge: nil,
            wageCapFactor: nil, goals: [ChallengeGoal(kind: .winCup, value: 0)], seasonsAllowed: 2, difficulty: .normal)
    ]

    static func scenario(id: String) -> ChallengeScenario? { all.first { $0.id == id } }
}

// MARK: - Conquistas

enum Achievement: String, Codable, CaseIterable, Identifiable {
    case firstWin, winStreak5, unbeaten10, bigWin5, hatTrick, derbyWin, shootoutWin, comeback, giantKiller
    case leagueTitle, promotion, cupTitle, doubleWinner, threePeat, objectiveMet, survivor
    case bestPlayerAward, topScorerAward, coachOfTheYear
    case millionaire, stadiumLevel3, allFacilities4, fullStaff, academyGem, starPlayer, bigSale, bigSigning
    case fiveSeasons, tenSeasons, invitationAccepted, reputation90, legendCreated, veteran, pressMaster, scoutEye
    case youthCup, challengeWon
    case betWinner, accumulatorWin, tipsterKing, fantasyWinner, viralPost, verifiedProfile, proLicense
    case wealthy, bookAuthor, eventsMaster, questsMaster, brandDeal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstWin: return "Primeira vitória"
        case .winStreak5: return "Embalado"
        case .unbeaten10: return "Muralha"
        case .bigWin5: return "Massacre"
        case .hatTrick: return "Show de um homem só"
        case .derbyWin: return "Rei do clássico"
        case .shootoutWin: return "Sangue frio"
        case .comeback: return "Virada épica"
        case .giantKiller: return "Mata-gigantes"
        case .leagueTitle: return "Campeão"
        case .promotion: return "Acesso garantido"
        case .cupTitle: return "Campeão da Copa"
        case .doubleWinner: return "Dobradinha"
        case .threePeat: return "Tricampeão"
        case .objectiveMet: return "Missão cumprida"
        case .survivor: return "Sobrevivente"
        case .bestPlayerAward: return "Craque do campeonato"
        case .topScorerAward: return "Bota de ouro"
        case .coachOfTheYear: return "Treinador do ano"
        case .millionaire: return "Cofre cheio"
        case .stadiumLevel3: return "Casa maior"
        case .allFacilities4: return "Centro de excelência"
        case .fullStaff: return "Comissão completa"
        case .academyGem: return "Joia da base"
        case .starPlayer: return "Estrela no elenco"
        case .bigSale: return "Negócio da China"
        case .bigSigning: return "Contratação de peso"
        case .fiveSeasons: return "Cinco temporadas"
        case .tenSeasons: return "Década no banco"
        case .invitationAccepted: return "Novo desafio"
        case .reputation90: return "Lenda dos treinadores"
        case .legendCreated: return "Lenda do clube"
        case .veteran: return "Veterano"
        case .pressMaster: return "Mestre da coletiva"
        case .scoutEye: return "Olho clínico"
        case .youthCup: return "Campeão da Copinha"
        case .challengeWon: return "Desafio vencido"
        case .betWinner: return "Palpite certeiro"
        case .accumulatorWin: return "Múltipla de ouro"
        case .tipsterKing: return "Rei dos palpiteiros"
        case .fantasyWinner: return "Mestre da Rodada Mágica"
        case .viralPost: return "Viralizou"
        case .verifiedProfile: return "Perfil verificado"
        case .proLicense: return "Licença Pro"
        case .wealthy: return "Patrimônio de peso"
        case .bookAuthor: return "Autor publicado"
        case .eventsMaster: return "Sangue frio nas crises"
        case .questsMaster: return "Caçador de missões"
        case .brandDeal: return "Garoto-propaganda"
        }
    }

    var detail: String {
        switch self {
        case .firstWin: return "Vença sua primeira partida."
        case .winStreak5: return "Vença cinco jogos seguidos."
        case .unbeaten10: return "Fique dez jogos sem perder."
        case .bigWin5: return "Vença por cinco gols de diferença."
        case .hatTrick: return "Tenha um atleta com três gols numa partida."
        case .derbyWin: return "Vença um clássico."
        case .shootoutWin: return "Vença uma disputa de pênaltis."
        case .comeback: return "Vença depois de estar dois gols atrás."
        case .giantKiller: return "Eliminem um clube de divisão superior na copa."
        case .leagueTitle: return "Seja campeão da divisão."
        case .promotion: return "Conquiste o acesso à Série A."
        case .cupTitle: return "Vença a Copa Nacional."
        case .doubleWinner: return "Vença liga e copa na mesma temporada."
        case .threePeat: return "Seja campeão três vezes seguidas."
        case .objectiveMet: return "Cumpra a meta da diretoria."
        case .survivor: return "Evite o rebaixamento numa temporada de luta."
        case .bestPlayerAward: return "Tenha o craque do campeonato."
        case .topScorerAward: return "Tenha o artilheiro da Série A."
        case .coachOfTheYear: return "Seja o treinador do ano."
        case .millionaire: return "Acumule R$ 25 mi em caixa."
        case .stadiumLevel3: return "Amplie o estádio até o nível 3."
        case .allFacilities4: return "Leve toda a estrutura ao nível 4."
        case .fullStaff: return "Contrate os sete profissionais da comissão."
        case .academyGem: return "Tenha um jovem com potencial 90 ou mais."
        case .starPlayer: return "Tenha um atleta com geral 85 ou mais."
        case .bigSale: return "Venda um atleta por R$ 5 mi ou mais."
        case .bigSigning: return "Pague R$ 6 mi ou mais por uma contratação."
        case .fiveSeasons: return "Complete cinco temporadas."
        case .tenSeasons: return "Complete dez temporadas."
        case .invitationAccepted: return "Aceite o convite de outro clube."
        case .reputation90: return "Chegue a 90 de reputação."
        case .legendCreated: return "Veja um atleta virar lenda do clube."
        case .veteran: return "Dispute 100 partidas como treinador."
        case .pressMaster: return "Responda 20 perguntas na coletiva."
        case .scoutEye: return "Receba dez relatórios de observação."
        case .youthCup: return "Seja campeão da Copinha."
        case .challengeWon: return "Vença um desafio."
        case .betWinner: return "Ganhe um bilhete no Palpite+."
        case .accumulatorWin: return "Acerte uma múltipla de 4 jogos ou mais."
        case .tipsterKing: return "Termine uma temporada no topo do ranking de palpiteiros."
        case .fantasyWinner: return "Vença uma rodada da Rodada Mágica."
        case .viralPost: return "Tenha uma publicação viral na Chuteira."
        case .verifiedProfile: return "Chegue a 250 mil seguidores."
        case .proLicense: return "Conquiste a Licença Pro."
        case .wealthy: return "Acumule R$ 2 mi de patrimônio pessoal."
        case .bookAuthor: return "Publique um livro."
        case .eventsMaster: return "Resolva 25 acontecimentos."
        case .questsMaster: return "Conclua 15 missões."
        case .brandDeal: return "Feche um contrato de marca."
        }
    }

    var symbol: String {
        switch self {
        case .firstWin, .winStreak5, .bigWin5: return "flame.fill"
        case .unbeaten10: return "shield.fill"
        case .hatTrick: return "soccerball"
        case .derbyWin: return "bolt.fill"
        case .shootoutWin: return "target"
        case .comeback: return "arrow.uturn.up"
        case .giantKiller: return "figure.fencing"
        case .leagueTitle, .cupTitle, .doubleWinner, .threePeat, .youthCup: return "trophy.fill"
        case .promotion: return "arrow.up.circle.fill"
        case .objectiveMet, .survivor: return "checkmark.seal.fill"
        case .bestPlayerAward, .topScorerAward, .coachOfTheYear: return "star.fill"
        case .millionaire, .bigSale, .bigSigning: return "banknote.fill"
        case .stadiumLevel3, .allFacilities4: return "building.2.fill"
        case .fullStaff: return "person.3.fill"
        case .academyGem, .legendCreated: return "sparkles"
        case .starPlayer: return "person.crop.circle.badge.checkmark"
        case .fiveSeasons, .tenSeasons, .veteran: return "calendar"
        case .invitationAccepted: return "envelope.open.fill"
        case .reputation90: return "crown.fill"
        case .pressMaster: return "mic.fill"
        case .scoutEye: return "binoculars.fill"
        case .challengeWon: return "flag.checkered"
        case .betWinner, .accumulatorWin, .tipsterKing: return "ticket.fill"
        case .fantasyWinner: return "sportscourt.fill"
        case .viralPost, .verifiedProfile, .brandDeal: return "bubble.left.and.bubble.right.fill"
        case .proLicense, .bookAuthor: return "graduationcap.fill"
        case .wealthy: return "banknote.fill"
        case .eventsMaster: return "exclamationmark.bubble.fill"
        case .questsMaster: return "checklist"
        }
    }
}

// MARK: - Tutorial

struct TutorialStep: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let done: Bool
}
