import SwiftUI

@main
struct BrasiliaPoliticaApp: App {
    var body: some Scene { WindowGroup { PoliticsLibrary() } }
}

struct DemoArticle: Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let summary: String
    let body: String
    let date: String

    static let all: [DemoArticle] = [
        .init(id: "01", category: "Instituições", title: "Como funciona uma lei distrital?", summary: "Um roteiro demonstrativo pelas etapas de elaboração e debate.", body: "CONTEÚDO FICTÍCIO PARA TESTE.\n\nEste protótipo demonstra como será a leitura de um guia cívico. O texto final deverá ser escrito, revisado e referenciado editorialmente antes de qualquer distribuição.\n\nUma proposta pode passar por apresentação, análise em comissões, debate e votação. As regras exatas dependem da matéria e precisam ser confirmadas em fontes oficiais.", date: "Conteúdo demo · 26 set 2026"),
        .init(id: "02", category: "Orçamento", title: "Orçamento público em linguagem simples", summary: "Receitas, despesas e prioridades explicadas sem jargão.", body: "CONTEÚDO FICTÍCIO PARA TESTE.\n\nEste texto de exemplo serve apenas para validar tipografia, favoritos e busca local. Valores, dados e afirmações sobre o orçamento não foram verificados e não devem ser tratados como informação factual.", date: "Conteúdo demo · 26 set 2026"),
        .init(id: "03", category: "Eleições", title: "O que observar em um plano de governo", summary: "Perguntas para leitura crítica de propostas públicas.", body: "CONTEÚDO FICTÍCIO PARA TESTE.\n\nCompare objetivos, prazos, custos e indicadores. O conteúdo editorial definitivo deve apresentar fontes, autoria, período de cobertura e processo de correção.", date: "Conteúdo demo · 26 set 2026"),
        .init(id: "04", category: "GDF", title: "Serviços do DF: guia de navegação", summary: "Uma estrutura de demonstração para guias de serviços.", body: "CONTEÚDO FICTÍCIO PARA TESTE.\n\nA versão final deve verificar cada serviço diretamente em sua fonte oficial e registrar quando a informação foi conferida. Este cartão não descreve um serviço real específico.", date: "Conteúdo demo · 26 set 2026"),
        .init(id: "05", category: "Instituições", title: "Por que acompanhar uma audiência pública?", summary: "Um exemplo de conteúdo explicativo e atemporal.", body: "CONTEÚDO FICTÍCIO PARA TESTE.\n\nAudiências podem oferecer um espaço para apresentação de informações e participação social. As regras e agendas variam; consulte fontes oficiais atualizadas antes de agir.", date: "Conteúdo demo · 26 set 2026"),
        .init(id: "06", category: "Orçamento", title: "Glossário cívico de demonstração", summary: "Termos de exemplo para testar busca e navegação.", body: "CONTEÚDO FICTÍCIO PARA TESTE.\n\nO glossário final exigirá definição editorial, referências e revisão. Este texto é uma amostra de interface, não uma publicação jornalística.", date: "Conteúdo demo · 26 set 2026")
    ]
}

enum DemoNewsCatalog {
    static func search(_ query: String, articles: [DemoArticle] = DemoArticle.all) -> [DemoArticle] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return articles }
        return articles.filter { $0.title.localizedCaseInsensitiveContains(term) || $0.summary.localizedCaseInsensitiveContains(term) || $0.body.localizedCaseInsensitiveContains(term) }
    }
}

struct PoliticsLibrary: View {
    @State private var query = ""
    @State private var selectedCategory = "Todas"
    @State private var showSaved = false
    @State private var favorites: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "politics.favorites") ?? [])
    private let accent = Color(red: 0.11, green: 0.23, blue: 0.37)
    private let categories = ["Todas", "Instituições", "Orçamento", "Eleições", "GDF"]
    private var capture: String? { FactoryCapture.screen }
    private var articles: [DemoArticle] {
        let searched = DemoNewsCatalog.search(query)
        return selectedCategory == "Todas" ? searched : searched.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "saved" { savedView }
                else if showSaved { savedView }
                else if capture == "article", let article = DemoArticle.all.first { ArticleDetail(article: article) }
                else { homeView }
            }
            .navigationDestination(for: DemoArticle.self) { ArticleDetail(article: $0) }
        }
        .tint(accent)
        .preferredColorScheme(.dark)
        .onAppear {
            if FactoryCapture.isUITesting {
                FactoryCapture.resetAppDefaults()
                favorites = []
                showSaved = false
            }
            if capture == "saved", favorites.isEmpty {
                favorites.insert("01")
            }
        }
    }

    private var homeView: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(eyebrow: "Acervo editorial demonstrativo", title: "Brasília em contexto.", subtitle: "Guias cívicos locais, datados e preparados para leitura offline.", accent: accent)
            FactoryDemoNotice(message: "CONTEÚDO FICTÍCIO · NÃO É NOTÍCIA ATUAL")
            FactoryPanel {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACERVO DE DEMONSTRAÇÃO").font(.caption.bold()).tracking(1.2).foregroundStyle(accent)
                        Text("Interface editorial em avaliação") .font(.title3.bold())
                        Text("26 de setembro de 2026 · data ilustrativa do pacote")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "text.book.closed.fill").font(.largeTitle).foregroundStyle(accent)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(accent)
                TextField("Buscar no acervo", text: $query).accessibilityLabel("Buscar no acervo")
            }.padding(14).background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 14))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(categories, id: \.self) { category in
                        Button(category) { selectedCategory = category }
                            .font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10)
                            .background(selectedCategory == category ? accent : FactoryColor.card, in: Capsule())
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                    }
                }
            }
            ForEach(articles) { article in
                NavigationLink(value: article) {
                    ArticleCard(article: article, isFavorite: favorites.contains(article.id), toggleFavorite: { toggle(article.id) })
                }.buttonStyle(.plain)
            }
            if articles.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            Text("6 textos demonstrativos · os 20+ artigos finais exigem apuração, fontes e revisão editorial.")
                .font(.footnote).foregroundStyle(.secondary)
        }.factoryPage().navigationTitle("Contexto").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSaved.toggle(); selectedCategory = "Todas"; query = "" } label: {
                        Image(systemName: showSaved ? "house.fill" : "bookmark.fill")
                    }
                    .accessibilityLabel(showSaved ? "Voltar ao acervo" : "Ver conteúdo salvo")
                }
            }
    }

    private var savedView: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Neste aparelho", title: "Leitura salva", subtitle: "Favoritos locais para encontrar depois.", accent: accent)
            FactoryDemoNotice()
            ForEach(DemoArticle.all.filter { favorites.contains($0.id) }) { article in
                NavigationLink(value: article) { ArticleCard(article: article, isFavorite: true, toggleFavorite: { toggle(article.id) }) }
                    .buttonStyle(.plain)
            }
            if favorites.isEmpty { ContentUnavailableView("Nada salvo ainda", systemImage: "bookmark", description: Text("Toque no marcador de uma matéria demonstrativa.")) }
        }.factoryPage().navigationTitle("Salvos").navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ id: String) {
        if !favorites.insert(id).inserted { favorites.remove(id) }
        UserDefaults.standard.set(Array(favorites), forKey: "politics.favorites")
    }
}

struct ArticleCard: View {
    let article: DemoArticle
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    var body: some View {
        FactoryPanel {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.category.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(.tint)
                    Text(article.title).font(.title3.bold()).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    Text(article.summary).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(article.date).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                Button(action: toggleFavorite) { Image(systemName: isFavorite ? "bookmark.fill" : "bookmark") }
                    .buttonStyle(.plain).foregroundStyle(.tint).accessibilityLabel(isFavorite ? "Remover dos salvos" : "Salvar matéria")
            }
        }
    }
}

struct ArticleDetail: View {
    let article: DemoArticle
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryDemoNotice(message: "CONTEÚDO FICTÍCIO · PARA AVALIAÇÃO DA INTERFACE")
            Text(article.category.uppercased()).font(.caption.bold()).tracking(1.4).foregroundStyle(.tint)
            Text(article.title).font(.system(size: 32, weight: .bold, design: .serif)).fixedSize(horizontal: false, vertical: true)
            Text("Redação demonstrativa · \(article.date)").font(.caption).foregroundStyle(.secondary)
            Divider()
            Text(article.body).font(.body).lineSpacing(7).fixedSize(horizontal: false, vertical: true)
            FactoryPanel(title: "Sobre este texto", systemImage: "info.circle") {
                Text("Amostra fictícia para testar leitura offline. Não representa reportagem, orientação pública ou fato verificado.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }.factoryPage().navigationTitle("Leitura").navigationBarTitleDisplayMode(.inline)
    }
}
