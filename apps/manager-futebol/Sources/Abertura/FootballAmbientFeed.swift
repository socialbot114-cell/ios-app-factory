import SwiftUI

/// Aviso de ambiente: dá a sensação de um celular de verdade na sala de espera. Não vem da carreira e não leva a lugar nenhum.
struct AmbientNotice: Identifiable {
    enum Kind: String, CaseIterable {
        case message, sponsor, meme, news, fantasy, bank, social, weather, system
    }

    let id: Int
    let kind: Kind
    let app: String
    let symbol: String
    let tint: Color
    let title: String
    let body: String
    /// Prévia oculta, como no celular com a tela bloqueada.
    let hidden: Bool
    /// Quando preenchido, o aviso só aparece se a carreira estiver nessa situação.
    var mood: Mood? = nil

    enum Mood: String {
        case win, draw, loss, lowCash
    }
}

/// O que a carreira conta para os avisos de ambiente reagirem (sem nunca levar a lugar nenhum).
struct AmbientContext: Equatable {
    var lastResult: FootballResult? = nil
    var lowCash = false

    var moods: [AmbientNotice.Mood] {
        var result: [AmbientNotice.Mood] = []
        switch lastResult {
        case .win: result.append(.win)
        case .draw: result.append(.draw)
        case .loss: result.append(.loss)
        case nil: break
        }
        if lowCash { result.append(.lowCash) }
        return result
    }
}

extension FootballCareer {
    var ambientContext: AmbientContext {
        let result = selectedClubID.flatMap { latestUserFixture?.result(for: $0) }
        return AmbientContext(lastResult: result, lowCash: selectedClubID != nil && transferBudget < 0)
    }
}

enum AmbientFeed {
    static let pool: [AmbientNotice] = [
        AmbientNotice(id: 0, kind: .message, app: "Mensagens", symbol: "tray.full.fill", tint: .green,
                      title: "Mãe", body: "Vai jantar aqui no domingo? Fiz a lasanha.", hidden: false),
        AmbientNotice(id: 1, kind: .message, app: "Mensagens", symbol: "tray.full.fill", tint: .green,
                      title: "Preparador físico", body: "Prévia oculta", hidden: true),
        AmbientNotice(id: 2, kind: .message, app: "Mensagens", symbol: "tray.full.fill", tint: .green,
                      title: "Grupo da Comissão", body: "Alguém trouxe o café hoje?", hidden: false),
        AmbientNotice(id: 3, kind: .sponsor, app: "Anúncio", symbol: "megaphone.fill", tint: .orange,
                      title: "Cerveja Gol de Placa", body: "Dois por um em toda rodada de quarta.", hidden: false),
        AmbientNotice(id: 4, kind: .sponsor, app: "Anúncio", symbol: "megaphone.fill", tint: .orange,
                      title: "Chuteiras Raio", body: "A nova coleção chegou. Frete grátis para treinadores.", hidden: false),
        AmbientNotice(id: 5, kind: .sponsor, app: "Anúncio", symbol: "megaphone.fill", tint: .orange,
                      title: "Banco Esquina", body: "Sem tarifa no primeiro ano de contrato.", hidden: false),
        AmbientNotice(id: 6, kind: .meme, app: "Chuteira", symbol: "face.smiling.inverse", tint: .pink,
                      title: "Meme do dia", body: "Zagueiro tentando explicar o impedimento para a esposa.", hidden: false),
        AmbientNotice(id: 7, kind: .meme, app: "Chuteira", symbol: "face.smiling.inverse", tint: .pink,
                      title: "Torcedor revoltado", body: "Quando o técnico tira o camisa 10 aos 40 do segundo tempo.", hidden: false),
        AmbientNotice(id: 8, kind: .meme, app: "Chuteira", symbol: "face.smiling.inverse", tint: .pink,
                      title: "Resenha", body: "Time que perde três seguidas e diz que o projeto é a longo prazo.", hidden: false),
        AmbientNotice(id: 9, kind: .news, app: "Liga", symbol: "list.number", tint: .indigo,
                      title: "Rodada do fim de semana", body: "Cinco clássicos prometem lotar os estádios.", hidden: false),
        AmbientNotice(id: 10, kind: .news, app: "Liga", symbol: "list.number", tint: .indigo,
                      title: "Mercado aquecido", body: "Rumores de uma proposta milionária por um atacante.", hidden: false),
        AmbientNotice(id: 11, kind: .fantasy, app: "Rodada", symbol: "sportscourt.fill", tint: Color(red: 0.20, green: 0.62, blue: 0.30),
                      title: "Rodada Mágica", body: "Escale seus 11 até as 18h.", hidden: false),
        AmbientNotice(id: 12, kind: .bank, app: "Banco", symbol: "banknote.fill", tint: Color(red: 0.10, green: 0.50, blue: 0.40),
                      title: "Extrato disponível", body: "Prévia oculta", hidden: true),
        AmbientNotice(id: 13, kind: .social, app: "Chuteira", symbol: "bubble.left.and.bubble.right.fill", tint: .pink,
                      title: "12 mil curtidas", body: "A foto do treino de ontem está bombando.", hidden: false),
        AmbientNotice(id: 14, kind: .social, app: "Chuteira", symbol: "bubble.left.and.bubble.right.fill", tint: .pink,
                      title: "Nova menção", body: "Um jornalista marcou você em uma enquete.", hidden: false),
        AmbientNotice(id: 15, kind: .weather, app: "Tempo", symbol: "cloud.rain.fill", tint: .blue,
                      title: "Chuva forte à tarde", body: "Gramado pesado em boa parte do país.", hidden: false),
        AmbientNotice(id: 16, kind: .weather, app: "Tempo", symbol: "sun.max.fill", tint: .yellow,
                      title: "Dia de sol", body: "Perfeito para treino aberto.", hidden: false),
        AmbientNotice(id: 17, kind: .system, app: "Sistema", symbol: "battery.25percent", tint: .gray,
                      title: "Bateria em 20%", body: "Conecte o carregador antes do jogo.", hidden: false),
        AmbientNotice(id: 18, kind: .system, app: "Sistema", symbol: "arrow.down.circle.fill", tint: .gray,
                      title: "Atualização disponível", body: "FutOS tem novidades para o seu celular.", hidden: false),
        AmbientNotice(id: 19, kind: .meme, app: "Chuteira", symbol: "face.smiling.inverse", tint: .pink,
                      title: "Torcedor feliz", body: "Hoje ninguém quer ouvir a palavra crise.", hidden: false, mood: .win),
        AmbientNotice(id: 20, kind: .news, app: "Liga", symbol: "list.number", tint: .indigo,
                      title: "Time embalado", body: "A vitória reacendeu a briga pelo topo da tabela.", hidden: false, mood: .win),
        AmbientNotice(id: 21, kind: .social, app: "Chuteira", symbol: "bubble.left.and.bubble.right.fill", tint: .pink,
                      title: "Assunto do momento", body: "A torcida pôs o seu nome nos assuntos mais comentados.", hidden: false, mood: .win),
        AmbientNotice(id: 22, kind: .sponsor, app: "Anúncio", symbol: "megaphone.fill", tint: .orange,
                      title: "Cerveja Gol de Placa", body: "Vitória pede brinde. Rodada por nossa conta.", hidden: false, mood: .win),
        AmbientNotice(id: 23, kind: .meme, app: "Chuteira", symbol: "face.smiling.inverse", tint: .pink,
                      title: "Resenha", body: "Quando o técnico diz que o time jogou bem e perdeu de três.", hidden: false, mood: .loss),
        AmbientNotice(id: 24, kind: .news, app: "Liga", symbol: "list.number", tint: .indigo,
                      title: "Pressão", body: "Torcida pede explicações depois da derrota.", hidden: false, mood: .loss),
        AmbientNotice(id: 25, kind: .message, app: "Mensagens", symbol: "tray.full.fill", tint: .green,
                      title: "Mãe", body: "Vi o jogo. Come alguma coisa, filho.", hidden: false, mood: .loss),
        AmbientNotice(id: 26, kind: .social, app: "Chuteira", symbol: "bubble.left.and.bubble.right.fill", tint: .pink,
                      title: "Fórum da torcida", body: "O tópico Professor, e agora? já tem 2 mil respostas.", hidden: false, mood: .loss),
        AmbientNotice(id: 27, kind: .meme, app: "Chuteira", symbol: "face.smiling.inverse", tint: .pink,
                      title: "Um ponto", body: "O empate que ninguém comemorou.", hidden: false, mood: .draw),
        AmbientNotice(id: 28, kind: .news, app: "Liga", symbol: "list.number", tint: .indigo,
                      title: "Tabela", body: "Mais um empate: a briga fica para a próxima rodada.", hidden: false, mood: .draw),
        AmbientNotice(id: 29, kind: .bank, app: "Banco", symbol: "banknote.fill", tint: Color(red: 0.10, green: 0.50, blue: 0.40),
                      title: "Saldo curto", body: "Confira o Banco antes de contratar.", hidden: false, mood: .lowCash),
        AmbientNotice(id: 30, kind: .message, app: "Mensagens", symbol: "tray.full.fill", tint: .green,
                      title: "Empresário", body: "Tem proposta boa na mesa, mas olha o caixa antes.", hidden: false, mood: .lowCash),
    ]

    /// Avisos de tipos diferentes; a seleção troca a cada 90 segundos. Com contexto, até dois avisos reagem à carreira.
    static func batch(at date: Date = Date(), count: Int = 5, context: AmbientContext? = nil) -> [AmbientNotice] {
        var state = UInt64(max(0, date.timeIntervalSince1970 / 90)) &* 6364136223846793005 &+ 1442695040888963407
        func next() -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int(state >> 33)
        }
        var order = Array(pool.indices)
        if order.count > 1 {
            for index in stride(from: order.count - 1, to: 0, by: -1) {
                order.swapAt(index, next() % (index + 1))
            }
        }
        var used = Set<AmbientNotice.Kind>()
        var result: [AmbientNotice] = []
        // Primeiro os avisos que reagem à carreira (no máximo dois), depois os de ambiente puro.
        let moods = context?.moods ?? []
        if !moods.isEmpty {
            for index in order where result.count < 2 {
                let notice = pool[index]
                if let mood = notice.mood, moods.contains(mood), used.insert(notice.kind).inserted { result.append(notice) }
            }
        }
        for index in order where result.count < count {
            let notice = pool[index]
            if notice.mood == nil, used.insert(notice.kind).inserted { result.append(notice) }
        }
        return result
    }
}
