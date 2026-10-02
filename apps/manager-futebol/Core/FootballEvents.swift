import Foundation

enum EventEffect {
    case playerMorale(Int)
    case squadMorale(Int)
    case fanMood(Int)
    case board(Int)
    case reputation(Int)
    case clubCash(Int)
    case personalCash(Int)
    case energy(Int)
    case stress(Int)
    case followers(Int)
    case controversy(Int)
    case fichas(Int)
    case conditionAll(Int)
    case injury(Int)
    case discoverYouth
    case observeStar
    case bookProgress(Int)
    /// Aposta de dinheiro pessoal: ganha `winAmount` com a chance informada, senão perde `lossAmount`.
    case gamble(chance: Double, winAmount: Int, lossAmount: Int)
}

struct EventOption {
    let label: String
    let hint: String
    let effects: [EventEffect]
    let result: String
}

struct EventTemplate {
    let id: String
    let category: EventCategory
    let weight: Int
    let isEligible: (FootballCareer) -> Bool
    let build: (FootballCareer, inout FootballRandom) -> (title: String, body: String, playerID: Int?)
    let options: [EventOption]
    let defaultChoice: Int
}

extension FootballCareer {
    private static func starter(_ career: FootballCareer, _ random: inout FootballRandom) -> FootballPlayer? {
        random.pick(career.starters)
    }

    static let eventTemplates: [EventTemplate] = {
        func fixed(_ title: String, _ body: String) -> (FootballCareer, inout FootballRandom) -> (title: String, body: String, playerID: Int?) {
            { _, _ in (title, body, nil) }
        }
        func withStarter(_ title: @escaping (String) -> String, _ body: @escaping (String) -> String) -> (FootballCareer, inout FootballRandom) -> (title: String, body: String, playerID: Int?) {
            { career, random in
                let athlete = FootballCareer.starter(career, &random)
                let name = athlete?.name ?? "Um atleta"
                return (title(name), body(name), athlete?.id)
            }
        }
        let anyone: (FootballCareer) -> Bool = { $0.selectedClubID != nil && !$0.isFired }
        return [
            // Vestiário
            EventTemplate(id: "briga-treino", category: .dressingRoom, weight: 10, isEligible: { $0.starters.count >= 2 },
                          build: withStarter({ "Confusão no treino: \($0)" }, { "\($0) se desentendeu com um companheiro durante o coletivo e a discussão esquentou." }),
                          options: [
                            EventOption(label: "Punir os dois", hint: "Mostra autoridade, mas esfria o clima.", effects: [.squadMorale(-1), .board(1), .playerMorale(-6)], result: "A punição foi cumprida e o recado dado."),
                            EventOption(label: "Mediar a conversa", hint: "Resolve o problema e fortalece o grupo.", effects: [.squadMorale(1), .stress(4), .playerMorale(3)], result: "A conversa no vestiário deixou tudo em paz."),
                            EventOption(label: "Ignorar", hint: "Pode virar um problema maior.", effects: [.squadMorale(-3)], result: "O clima ficou pesado no restante da semana.")
                          ], defaultChoice: 2),
            EventTemplate(id: "lider-folga", category: .dressingRoom, weight: 8, isEligible: { $0.matchDayIndex >= 3 },
                          build: fixed("O capitão pede uma folga", "O capitão pediu um dia extra de folga para o elenco depois da maratona de jogos."),
                          options: [
                            EventOption(label: "Conceder a folga", hint: "Elenco descansado e feliz.", effects: [.squadMorale(2), .conditionAll(6)], result: "O grupo voltou renovado."),
                            EventOption(label: "Negar", hint: "A diretoria aprova, o elenco nem tanto.", effects: [.squadMorale(-2), .board(1)], result: "O pedido foi negado e alguns resmungaram.")
                          ], defaultChoice: 1),
            EventTemplate(id: "churrasco", category: .dressingRoom, weight: 6, isEligible: anyone,
                          build: fixed("Churrasco de integração", "Os atletas propuseram um churrasco no centro de treinamento para estreitar laços."),
                          options: [
                            EventOption(label: "Aceitar", hint: "Sobe o moral, cansa um pouco.", effects: [.squadMorale(3), .conditionAll(-3)], result: "A resenha uniu o elenco."),
                            EventOption(label: "Adiar", hint: "Foco no jogo.", effects: [.squadMorale(-1)], result: "O elenco entendeu, mas ficou frustrado.")
                          ], defaultChoice: 1),
            EventTemplate(id: "virose", category: .dressingRoom, weight: 5, isEligible: { $0.matchDayIndex >= 2 },
                          build: fixed("Virose no elenco", "Alguns atletas apareceram com febre e mal-estar no centro de treinamento."),
                          options: [
                            EventOption(label: "Isolar e poupar", hint: "Controla o surto.", effects: [.conditionAll(-6), .stress(2)], result: "O surto foi contido com poucos casos."),
                            EventOption(label: "Manter a rotina", hint: "Risco de espalhar.", effects: [.conditionAll(-12), .injury(1)], result: "A virose se espalhou e derrubou vários atletas.")
                          ], defaultChoice: 1),
            EventTemplate(id: "jovem-quer-chance", category: .dressingRoom, weight: 6, isEligible: { !$0.youthRoster.isEmpty },
                          build: { career, random in
                              let kid = random.pick(career.youthRoster)
                              return ("\(kid?.name ?? "Um garoto da base") pede uma chance", "O jovem treinou com o elenco principal e quer saber quando vai estrear.", kid?.id)
                          },
                          options: [
                            EventOption(label: "Prometer minutos", hint: "Motiva o garoto e a base.", effects: [.playerMorale(15), .followers(500)], result: "O garoto vibrou e promete retribuir em campo."),
                            EventOption(label: "Pedir paciência", hint: "Sem compromisso.", effects: [.playerMorale(-4)], result: "Ele entendeu, mas saiu desanimado.")
                          ], defaultChoice: 1),
            EventTemplate(id: "reserva-reclama", category: .dressingRoom, weight: 7, isEligible: { $0.clubRoster.contains { !$0.isInjured && $0.benchStreak >= 2 } },
                          build: { career, random in
                              let benched = career.clubRoster.filter { $0.benchStreak >= 2 }
                              let athlete = random.pick(benched)
                              return ("\(athlete?.name ?? "Um reserva") reclama na imprensa", "O atleta disse em uma entrevista que merece mais minutos e a frase repercutiu.", athlete?.id)
                          },
                          options: [
                            EventOption(label: "Multar e dar o recado", hint: "Autoridade, mas o atleta fica magoado.", effects: [.playerMorale(-10), .board(1), .squadMorale(-1)], result: "A multa foi aplicada e o assunto morreu."),
                            EventOption(label: "Conversar a sós", hint: "Constrói confiança.", effects: [.playerMorale(8), .stress(3)], result: "A conversa acalmou o atleta."),
                            EventOption(label: "Deixar passar", hint: "Pode contaminar o grupo.", effects: [.squadMorale(-2)], result: "O assunto continuou rendendo nos corredores.")
                          ], defaultChoice: 2),
            EventTemplate(id: "lesao-treino", category: .dressingRoom, weight: 4, isEligible: { $0.starters.count >= 2 && !$0.starters.contains(where: \.isInjured) },
                          build: withStarter({ "\($0) se machuca no treino" }, { "\($0) sentiu a coxa em uma bola dividida e saiu de campo." }),
                          options: [
                            EventOption(label: "Poupar com cuidado", hint: "Fica fora poucos jogos.", effects: [.injury(1), .stress(2)], result: "O atleta fica um jogo de fora, sem sequelas."),
                            EventOption(label: "Forçar o retorno", hint: "Risco de agravar.", effects: [.injury(3)], result: "A lesão se agravou e vai tirá-lo por mais tempo.")
                          ], defaultChoice: 0),
            // Torcida
            EventTemplate(id: "organizada-treino", category: .fans, weight: 9, isEligible: { $0.fanMood < 55 },
                          build: fixed("Organizada no treino", "Torcedores organizados foram ao centro de treinamento cobrar resultados."),
                          options: [
                            EventOption(label: "Conversar com os líderes", hint: "Acalma a torcida.", effects: [.fanMood(3), .stress(5)], result: "A conversa foi tensa, mas respeitosa."),
                            EventOption(label: "Chamar os atletas para falar", hint: "O grupo se une.", effects: [.fanMood(1), .squadMorale(1)], result: "Os atletas prometeram entrega total."),
                            EventOption(label: "Ignorar", hint: "Irrita a arquibancada.", effects: [.fanMood(-3), .squadMorale(-1)], result: "Os cantos de protesto aumentaram.")
                          ], defaultChoice: 2),
            EventTemplate(id: "homenagem-torcida", category: .fans, weight: 5, isEligible: { $0.fanMood >= 70 },
                          build: fixed("Torcida prepara homenagem", "Os torcedores querem fazer uma homenagem ao treinador antes do próximo jogo."),
                          options: [
                            EventOption(label: "Aceitar com humildade", hint: "Emocionante e bom para a imagem.", effects: [.fanMood(2), .energy(5), .followers(2000)], result: "A homenagem emocionou o estádio."),
                            EventOption(label: "Dividir com o elenco", hint: "Une o grupo.", effects: [.squadMorale(3), .fanMood(1)], result: "O elenco adorou o gesto.")
                          ], defaultChoice: 0),
            EventTemplate(id: "ingressos-criancas", category: .fans, weight: 6, isEligible: { $0.transferBudget > 400_000 },
                          build: fixed("Promoção de ingressos infantis", "O marketing sugere liberar ingressos gratuitos para crianças no próximo jogo em casa."),
                          options: [
                            EventOption(label: "Liberar", hint: "Custa R$ 40 mil e conquista novos torcedores.", effects: [.clubCash(-40_000), .fanMood(4), .followers(5000)], result: "O estádio ficou cheio de camisas do clube."),
                            EventOption(label: "Recusar", hint: "Sem custo.", effects: [], result: "A ideia ficou na gaveta.")
                          ], defaultChoice: 1),
            EventTemplate(id: "crianca-fa", category: .fans, weight: 4, isEligible: anyone,
                          build: fixed("Um fã especial quer conhecer o time", "Um garoto torcedor, em tratamento no hospital, sonha em visitar o vestiário."),
                          options: [
                            EventOption(label: "Receber no vestiário", hint: "Gesto marcante para todos.", effects: [.fanMood(4), .squadMorale(2), .followers(8000)], result: "Foi o dia mais bonito da temporada."),
                            EventOption(label: "Agendar para depois", hint: "Agenda cheia.", effects: [.fanMood(-1)], result: "Ficou para uma próxima oportunidade.")
                          ], defaultChoice: 1),
            // Imprensa
            EventTemplate(id: "entrevista-exclusiva", category: .media, weight: 7, isEligible: anyone,
                          build: fixed("Entrevista exclusiva na TV", "Uma emissora convida você para uma entrevista de uma hora sobre a sua filosofia de jogo."),
                          options: [
                            EventOption(label: "Aceitar e ser sincero", hint: "Mais seguidores e prestígio.", effects: [.followers(10000), .reputation(1), .energy(-8)], result: "A entrevista foi elogiada."),
                            EventOption(label: "Aceitar e provocar", hint: "Alcance enorme e risco de polêmica.", effects: [.followers(25000), .controversy(14), .fanMood(1)], result: "O programa bombou, e a polêmica também."),
                            EventOption(label: "Recusar", hint: "Poupa energia.", effects: [.energy(3)], result: "Você preferiu focar no trabalho.")
                          ], defaultChoice: 2),
            EventTemplate(id: "documentario", category: .media, weight: 4, isEligible: { $0.reputation >= 40 },
                          build: fixed("Documentário sobre o clube", "Uma produtora quer gravar os bastidores do clube durante algumas semanas."),
                          options: [
                            EventOption(label: "Liberar as câmeras", hint: "Dinheiro e seguidores, mas atrapalha o foco.", effects: [.personalCash(30_000), .followers(15000), .stress(5), .squadMorale(-1)], result: "As câmeras renderam boas imagens e um pouco de distração."),
                            EventOption(label: "Recusar", hint: "Preserva a privacidade.", effects: [.squadMorale(1)], result: "O vestiário agradeceu a privacidade.")
                          ], defaultChoice: 1),
            EventTemplate(id: "pergunta-rival", category: .media, weight: 6, isEligible: anyone,
                          build: fixed("Jornalista cutuca o rival", "Na coletiva, um repórter pede para você comparar o seu time ao maior rival."),
                          options: [
                            EventOption(label: "Elogiar o rival", hint: "Imagem elegante.", effects: [.reputation(1), .fanMood(-1)], result: "A fala foi vista como elegante."),
                            EventOption(label: "Provocar", hint: "A torcida adora; a diretoria nem tanto.", effects: [.fanMood(3), .controversy(8), .board(-1)], result: "A frase virou manchete."),
                            EventOption(label: "Desconversar", hint: "Sem risco.", effects: [], result: "Você driblou a pergunta com classe.")
                          ], defaultChoice: 2),
            // Diretoria
            EventTemplate(id: "presidente-quer-contratar", category: .board, weight: 7, isEligible: { $0.isTransferWindowOpen || $0.matchDayIndex < 14 },
                          build: fixed("O presidente quer um reforço", "O presidente se encantou com um atleta que viu num jantar e quer contratá-lo para o time."),
                          options: [
                            EventOption(label: "Concordar", hint: "Agrada a diretoria, mas pode pesar na folha.", effects: [.board(4), .clubCash(-120_000)], result: "O presidente ficou radiante com a sua abertura."),
                            EventOption(label: "Negociar a escolha", hint: "Um meio-termo.", effects: [.board(1)], result: "Vocês chegaram a um acordo sobre o perfil."),
                            EventOption(label: "Recusar", hint: "Preserva o seu plano.", effects: [.board(-3)], result: "O presidente não gostou da recusa.")
                          ], defaultChoice: 1),
            EventTemplate(id: "orcamento-extra", category: .board, weight: 5, isEligible: { $0.boardConfidence >= 55 },
                          build: fixed("Diretoria oferece orçamento extra", "Os conselheiros oferecem R$ 300 mil extras, mas esperam um resultado melhor em troca."),
                          options: [
                            EventOption(label: "Aceitar", hint: "Dinheiro agora, mais cobrança depois.", effects: [.clubCash(300_000), .board(-4)], result: "O dinheiro entrou e a cobrança aumentou."),
                            EventOption(label: "Recusar", hint: "Autonomia total.", effects: [.board(2)], result: "A diretoria respeitou a sua independência.")
                          ], defaultChoice: 1),
            // Finanças
            EventTemplate(id: "amistoso-exterior", category: .finance, weight: 5, isEligible: { $0.matchDayIndex >= 3 },
                          build: fixed("Convite para amistoso no exterior", "Um empresário oferece uma bolada por um amistoso comemorativo no meio da temporada."),
                          options: [
                            EventOption(label: "Aceitar", hint: "R$ 250 mil, mas o elenco chega cansado.", effects: [.clubCash(250_000), .conditionAll(-10), .squadMorale(-1), .followers(6000)], result: "O clube faturou, e o elenco voltou exausto."),
                            EventOption(label: "Recusar", hint: "Elenco poupado.", effects: [.squadMorale(1)], result: "O elenco agradeceu a folga.")
                          ], defaultChoice: 1),
            EventTemplate(id: "patrocinador-atrasa", category: .finance, weight: 5, isEligible: { $0.sponsorDeal != nil },
                          build: fixed("Patrocinador atrasa o pagamento", "O financeiro avisa que uma parcela do patrocínio está atrasada."),
                          options: [
                            EventOption(label: "Negociar prazo", hint: "Preserva a parceria.", effects: [.board(1), .clubCash(-10_000)], result: "Um novo prazo foi combinado."),
                            EventOption(label: "Cobrar com firmeza", hint: "Recebe, mas estremece a relação.", effects: [.clubCash(60_000), .reputation(-1)], result: "O dinheiro entrou e a relação esfriou.")
                          ], defaultChoice: 0),
            EventTemplate(id: "campanha-socios", category: .finance, weight: 4, isEligible: { $0.fanMood >= 55 },
                          build: fixed("Campanha dos sócios arrecada fundos", "Os sócios-torcedores organizaram uma vaquinha para ajudar nos reforços."),
                          options: [
                            EventOption(label: "Agradecer publicamente", hint: "R$ 80 mil e mais carinho.", effects: [.clubCash(80_000), .fanMood(3)], result: "A campanha emocionou o clube."),
                            EventOption(label: "Direcionar à base", hint: "Dinheiro para as categorias de base.", effects: [.clubCash(60_000), .followers(2000)], result: "A base recebeu o investimento.")
                          ], defaultChoice: 0),
            EventTemplate(id: "multa-fiscal", category: .finance, weight: 3, isEligible: anyone,
                          build: fixed("Multa por atraso de documentos", "O jurídico avisa de uma multa por atraso na entrega de documentos do clube."),
                          options: [
                            EventOption(label: "Pagar agora", hint: "R$ 60 mil, assunto encerrado.", effects: [.clubCash(-60_000)], result: "A multa foi paga."),
                            EventOption(label: "Recorrer", hint: "Chance de reduzir, com risco.", effects: [.clubCash(-30_000), .board(-1)], result: "O recurso reduziu o valor, mas gerou desgaste.")
                          ], defaultChoice: 0),
            // Vida pessoal
            EventTemplate(id: "palestra-fds", category: .personal, weight: 6, isEligible: { $0.world.coach.energy >= 25 },
                          build: fixed("Convite para palestra no fim de semana", "Uma empresa quer você como palestrante em um congresso."),
                          options: [
                            EventOption(label: "Aceitar", hint: "R$ 40 mil, mas cansa.", effects: [.personalCash(40_000), .energy(-15), .stress(5)], result: "A palestra foi um sucesso."),
                            EventOption(label: "Recusar", hint: "Descanso garantido.", effects: [.energy(5)], result: "Você aproveitou o fim de semana.")
                          ], defaultChoice: 1),
            EventTemplate(id: "familia-pede", category: .personal, weight: 5, isEligible: { $0.world.coach.stress >= 40 },
                          build: fixed("A família pede a sua presença", "Faz tempo que você não passa um dia inteiro com a família."),
                          options: [
                            EventOption(label: "Tirar o dia", hint: "Recupera energia e alivia o estresse.", effects: [.stress(-12), .energy(10), .board(-1)], result: "Foi um dia de renovar as forças."),
                            EventOption(label: "Manter o trabalho", hint: "Foco total no clube.", effects: [.stress(6)], result: "A família entendeu, mas ficou chateada.")
                          ], defaultChoice: 1),
            EventTemplate(id: "reality-show", category: .personal, weight: 3, isEligible: { $0.reputation >= 45 },
                          build: fixed("Convite para um reality show", "Uma emissora quer você como jurado de um reality show esportivo."),
                          options: [
                            EventOption(label: "Aceitar", hint: "Seguidores e dinheiro, mas imagem arriscada.", effects: [.followers(40000), .personalCash(60_000), .controversy(10), .reputation(-1)], result: "O programa bombou, e a imagem também sofreu."),
                            EventOption(label: "Recusar", hint: "Imagem preservada.", effects: [.reputation(1)], result: "A recusa foi bem vista no meio.")
                          ], defaultChoice: 1),
            EventTemplate(id: "editora-livro", category: .personal, weight: 3, isEligible: { $0.reputation >= 35 },
                          build: fixed("Editora propõe um livro", "Uma editora quer lançar a sua biografia e adianta o material de pesquisa."),
                          options: [
                            EventOption(label: "Aceitar", hint: "Três capítulos já escritos.", effects: [.bookProgress(3), .energy(-5)], result: "O projeto do livro andou bastante."),
                            EventOption(label: "Recusar", hint: "Sem compromisso.", effects: [], result: "A proposta ficou para depois.")
                          ], defaultChoice: 1),
            EventTemplate(id: "bolao", category: .personal, weight: 3, isEligible: { $0.world.coach.personalCash >= 20_000 },
                          build: fixed("Bolão entre os funcionários", "A comissão técnica monta um bolão da rodada. Quer entrar?"),
                          options: [
                            EventOption(label: "Entrar com R$ 5 mil", hint: "Aposta de risco.", effects: [.gamble(chance: 0.35, winAmount: 18_000, lossAmount: 5_000),], result: "O bolão foi resolvido."),
                            EventOption(label: "Ficar de fora", hint: "Sem risco.", effects: [], result: "Você acompanhou de longe.")
                          ], defaultChoice: 1),
            // Comunidade
            EventTemplate(id: "projeto-social-pede", category: .community, weight: 6, isEligible: { $0.transferBudget > 300_000 },
                          build: fixed("Comunidade pede apoio a um projeto", "Uma associação de bairro precisa de ajuda para manter um projeto esportivo de crianças."),
                          options: [
                            EventOption(label: "Apoiar com R$ 50 mil", hint: "Boa imagem e reputação.", effects: [.clubCash(-50_000), .fanMood(3), .reputation(1)], result: "O clube virou referência no bairro."),
                            EventOption(label: "Enviar atletas ao projeto", hint: "Grátis e muito simpático.", effects: [.fanMood(2), .energy(-4), .squadMorale(1)], result: "Os atletas se divertiram e a comunidade amou."),
                            EventOption(label: "Declinar", hint: "Sem custo.", effects: [.fanMood(-1)], result: "O pedido foi educadamente recusado.")
                          ], defaultChoice: 2),
            EventTemplate(id: "visita-hospital", category: .community, weight: 4, isEligible: anyone,
                          build: fixed("Visita ao hospital infantil", "O hospital convida o clube para uma tarde de visita aos pequenos pacientes."),
                          options: [
                            EventOption(label: "Ir com o elenco", hint: "Gesto bonito, cansa um pouco.", effects: [.fanMood(3), .squadMorale(2), .conditionAll(-2), .followers(6000)], result: "Foi uma tarde inesquecível."),
                            EventOption(label: "Enviar só uma comitiva", hint: "Compromisso cumprido.", effects: [.fanMood(1)], result: "Uma comitiva representou o clube.")
                          ], defaultChoice: 1),
            // Sorte
            EventTemplate(id: "pelada-talento", category: .luck, weight: 3, isEligible: { $0.youthRoster.count < FootballCareer.youthRosterLimit },
                          build: fixed("Talento descoberto numa pelada", "Num campo de várzea perto do hotel, você viu um garoto que jogava diferente dos outros."),
                          options: [
                            EventOption(label: "Levar para a base", hint: "Pode ser uma joia.", effects: [.discoverYouth], result: "O garoto foi levado para a categoria de base."),
                            EventOption(label: "Deixar passar", hint: "Sem compromisso.", effects: [], result: "Você seguiu o caminho.")
                          ], defaultChoice: 1),
            EventTemplate(id: "ex-jogador-doa", category: .luck, weight: 2, isEligible: { $0.reputation >= 30 },
                          build: fixed("Ex-jogador faz uma doação", "Um ídolo aposentado do clube decidiu doar parte de um prêmio às categorias de base."),
                          options: [
                            EventOption(label: "Receber com festa", hint: "R$ 120 mil e clima de gratidão.", effects: [.clubCash(120_000), .fanMood(3)], result: "A doação virou uma linda festa."),
                            EventOption(label: "Agradecer discretamente", hint: "Menos exposição.", effects: [.clubCash(120_000)], result: "A doação foi acolhida sem alarde.")
                          ], defaultChoice: 1),
            EventTemplate(id: "olheiro-dica", category: .luck, weight: 4, isEligible: { $0.transferWindow != nil || $0.matchDayIndex > 3 },
                          build: fixed("Dica de um olheiro amigo", "Um olheiro de outro estado liga com uma indicação quente de um atleta."),
                          options: [
                            EventOption(label: "Pedir um relatório", hint: "Você conhece melhor o atleta.", effects: [.observeStar, .stress(1)], result: "O relatório chegou detalhado."),
                            EventOption(label: "Agradecer e seguir", hint: "Sem tempo.", effects: [], result: "A dica ficou guardada.")
                          ], defaultChoice: 1),
            EventTemplate(id: "chuva-forte", category: .luck, weight: 4, isEligible: anyone,
                          build: fixed("Chuva forte atrapalha o treino", "Uma tempestade alagou o campo principal do centro de treinamento."),
                          options: [
                            EventOption(label: "Treinar na academia", hint: "Mantém o ritmo, com menos precisão.", effects: [.conditionAll(-2)], result: "O treino físico foi mantido no ginásio."),
                            EventOption(label: "Dar folga", hint: "O elenco descansa.", effects: [.conditionAll(4), .squadMorale(1)], result: "Dia de descanso para todos.")
                          ], defaultChoice: 0)
        ]
    }()

    // MARK: - Geração e resolução

    var pendingEvents: [WorldEvent] { world.events.pending }

    mutating func generateWorldEvent(using random: inout FootballRandom) {
        guard selectedClubID != nil, !isFired, world.events.pending.count < 2, random.chance(0.3) else { return }
        let recent = Set(world.events.recentTemplates.suffix(12))
        let pool = Self.eventTemplates.filter { !recent.contains($0.id) && $0.isEligible(self) }
        guard let index = random.weightedIndex(pool.map(\.weight)) else { return }
        let template = pool[index]
        let built = template.build(self, &random)
        let event = WorldEvent(id: world.events.nextEventID, templateID: template.id, category: template.category, season: season, matchDay: matchDayIndex,
                               title: built.title, body: built.body,
                               choices: template.options.map { EventChoice(label: $0.label, hint: $0.hint) },
                               expiresWorldDay: worldDay + 3, defaultChoice: template.defaultChoice, playerID: built.playerID)
        world.events.nextEventID += 1
        world.events.pending.append(event)
        world.events.recentTemplates.append(template.id)
        if world.events.recentTemplates.count > 30 { world.events.recentTemplates.removeFirst(10) }
        addInbox(.event, title: event.title, body: event.body, playerID: event.playerID, offerID: event.id)
    }

    @discardableResult
    mutating func resolveEvent(id: Int, choice: Int) -> String? {
        guard let index = world.events.pending.firstIndex(where: { $0.id == id }),
              let template = Self.eventTemplates.first(where: { $0.id == world.events.pending[index].templateID }),
              template.options.indices.contains(choice) else { return nil }
        var event = world.events.pending.remove(at: index)
        let option = template.options[choice]
        var random = FootballRandom(seed: matchSeed(stream: .events, id: event.id + worldDay * 31))
        for effect in option.effects { apply(effect, playerID: event.playerID, using: &random) }
        event.resolvedChoice = choice
        event.resultText = option.result
        world.events.history.insert(event, at: 0)
        if world.events.history.count > 40 { world.events.history.removeLast(world.events.history.count - 40) }
        for messageIndex in inbox.indices where inbox[messageIndex].kind == .event && inbox[messageIndex].offerID == id {
            inbox[messageIndex].isResolved = true
            inbox[messageIndex].isRead = true
        }
        bump("events")
        return option.result
    }

    /// Eventos sem resposta se resolvem sozinhos pela opção padrão.
    mutating func expireWorldEvents() {
        for event in world.events.pending where event.expiresWorldDay <= worldDay {
            _ = resolveEvent(id: event.id, choice: event.defaultChoice)
        }
    }

    mutating func apply(_ effect: EventEffect, playerID: Int?, using random: inout FootballRandom) {
        guard let selectedClubID else { return }
        func clamp(_ value: Int) -> Int { min(100, max(0, value)) }
        func firstTeam() -> [Int] { players.indices.filter { players[$0].teamID == selectedClubID && !players[$0].isYouth } }
        switch effect {
        case .playerMorale(let delta):
            if let playerID, let index = players.firstIndex(where: { $0.id == playerID }) { players[index].morale = clamp(players[index].morale + delta) }
        case .squadMorale(let delta):
            for index in firstTeam() { players[index].morale = clamp(players[index].morale + delta) }
        case .fanMood(let delta): fanMood = clamp(fanMood + delta)
        case .board(let delta): boardConfidence = clamp(boardConfidence + delta)
        case .reputation(let delta): changeReputation(delta)
        case .clubCash(let delta): book(.other, delta, "Acontecimento")
        case .personalCash(let delta): world.coach.personalCash += delta
        case .energy(let delta): world.coach.energy = clamp(world.coach.energy + delta)
        case .stress(let delta): world.coach.stress = clamp(world.coach.stress + delta)
        case .followers(let delta): world.social.coachFollowers = max(500, world.social.coachFollowers + delta)
        case .controversy(let delta): world.social.controversy = clamp(world.social.controversy + delta)
        case .fichas(let delta): world.betting.fichas = max(0, world.betting.fichas + delta)
        case .conditionAll(let delta):
            for index in firstTeam() { players[index].condition = min(100, max(40, players[index].condition + delta)) }
        case .injury(let rounds):
            let target = playerID.flatMap { id in players.firstIndex(where: { $0.id == id }) } ?? random.pick(firstTeam())
            if let target { players[target].injuryRounds = max(players[target].injuryRounds, rounds); repairLineup() }
        case .discoverYouth:
            let strength = (selectedClub?.strength ?? 65)
            let position = random.pick(FootballPosition.allCases) ?? .midfielder
            var kid = FootballSeason.makeYouth(id: nextPlayerID, position: position, teamStrength: strength, teamID: selectedClubID, season: season, quality: 5, using: &random)
            kid.potential = max(kid.potential, 82 + random.int(in: 0...8))
            kid.isYouth = true
            players.append(kid)
            nextPlayerID += 1
            addInbox(.general, title: "\(kid.name) chegou à base", body: "O garoto descoberto na pelada tem potencial \(kid.potential).", playerID: kid.id)
        case .observeStar:
            let candidates = players.filter { $0.teamID != nil && $0.teamID != selectedClubID && $0.potential >= 80 && $0.age <= 23 }
            if let star = random.pick(candidates) {
                scoutKnowledge[star.id] = 85
                addInbox(.scouting, title: "Dica de olheiro: \(star.name)", body: "\(star.name) (\(star.position.rawValue), \(star.age) anos, \(FootballSeason.teamName(star.teamID ?? 0))) tem potencial \(star.potential).", playerID: star.id)
            }
        case .bookProgress(let sessions):
            world.coach.bookSessions += sessions
        case .gamble(let chance, let winAmount, let lossAmount):
            if random.chance(chance) { world.coach.personalCash += winAmount } else { world.coach.personalCash -= lossAmount }
        }
    }
}
