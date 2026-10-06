import SwiftUI

// MARK: - Apps do celular

/// Cada app é uma micro-realidade do jogo; todos leem e escrevem na mesma carreira.
enum PhoneApp: String, CaseIterable, Identifiable {
    case manager, squad, league, market, club, messages, social, betting, fantasy
    case life, business, quests, trophies, alerts, brand, bank, contacts, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manager: return "Gestor"
        case .squad: return "Tática"
        case .league: return "Liga"
        case .market: return "Transfer"
        case .club: return "Clube"
        case .messages: return "Mensagens"
        case .social: return "Chuteira"
        case .betting: return "Palpite+"
        case .fantasy: return "Rodada"
        case .life: return "Vida"
        case .business: return "Negócios"
        case .quests: return "Metas"
        case .trophies: return "Troféus"
        case .alerts: return "Alertas"
        case .brand: return "Marca"
        case .bank: return "Banco"
        case .contacts: return "Contatos"
        case .settings: return "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .manager: return "house.fill"
        case .squad: return "person.3.fill"
        case .league: return "list.number"
        case .market: return "arrow.left.arrow.right"
        case .club: return "trophy.fill"
        case .messages: return "tray.full.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .betting: return "ticket.fill"
        case .fantasy: return "sportscourt.fill"
        case .life: return "figure.walk"
        case .business: return "building.2.crop.circle.fill"
        case .quests: return "checklist"
        case .trophies: return "medal.fill"
        case .alerts: return "exclamationmark.bubble.fill"
        case .brand: return "tv.and.mediabox.fill"
        case .bank: return "banknote.fill"
        case .contacts: return "person.crop.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .manager: return Color(red: 0.06, green: 0.55, blue: 0.34)
        case .squad: return .blue
        case .league: return .indigo
        case .market: return .orange
        case .club: return Color(red: 0.80, green: 0.58, blue: 0.10)
        case .messages: return .green
        case .social: return .pink
        case .betting: return .purple
        case .fantasy: return Color(red: 0.20, green: 0.62, blue: 0.30)
        case .life: return .teal
        case .business: return Color(red: 0.35, green: 0.35, blue: 0.80)
        case .quests: return Color(red: 0.20, green: 0.45, blue: 0.85)
        case .trophies: return Color(red: 0.85, green: 0.64, blue: 0.16)
        case .alerts: return .red
        case .brand: return Color(red: 0.85, green: 0.25, blue: 0.45)
        case .bank: return Color(red: 0.10, green: 0.50, blue: 0.40)
        case .contacts: return Color(red: 0.25, green: 0.55, blue: 0.65)
        case .settings: return Color(red: 0.45, green: 0.47, blue: 0.52)
        }
    }

    /// O que mora em cada app. Um assunto tem um dono só; os demais apps apontam para ele por atalhos.
    var purpose: String {
        switch self {
        case .manager: return "Dia a dia: próxima partida, agenda, preparação e resultados"
        case .squad: return "Escalação, tática, funções e treino do elenco"
        case .league: return "Tabelas, rodadas, copa, artilharia e perfis de clubes"
        case .market: return "Contratações, propostas, observação e categorias de base"
        case .club: return "Diretoria, estádio, estrutura, comissão técnica e história"
        case .messages: return "Caixa de entrada com mensagens e ofertas"
        case .social: return "Redes, imagem pública e contratos de marca pessoal"
        case .betting: return "Palpites e fichas"
        case .fantasy: return "Rodada Mágica: monte 11 atletas e pontue com a rodada real"
        case .life: return "Energia, estresse, dinheiro pessoal, licenças e investimentos"
        case .business: return "Loja, nome do estádio, projetos sociais, amistosos e empresários"
        case .quests: return "Metas e tarefas ativas"
        case .trophies: return "Conquistas e galeria"
        case .alerts: return "Acontecimentos que pedem decisão"
        case .brand: return "Marketing, TV, torcida e patrocínio"
        case .bank: return "Caixa do clube, folha salarial, extratos e projeções"
        case .contacts: return "Pessoas próximas e conversas"
        case .settings: return "Carreiras salvas, dificuldade, desafios, avisos e tutorial"
        }
    }

    static let dock: [PhoneApp] = [.manager, .messages, .social, .club]
    static var grid: [PhoneApp] { allCases.filter { !dock.contains($0) } }
}
