import SwiftUI
import UIKit

// MARK: - Entrada

@main
struct AtelieColorirApp: App {
    var body: some Scene { WindowGroup { AtelierRoot() } }
}

// MARK: - Motor legado (mantido p/ testes + migração v1 -> v2)

struct ColoringEngine: Codable, Equatable {
    private(set) var fills: [Int: Int] = [:]
    private var history: [[Int: Int]] = []

    mutating func fill(region: Int, color: Int) {
        guard (0..<9).contains(region), (0..<6).contains(color) else { return }
        guard fills[region] != color else { return }
        history.append(fills)
        fills[region] = color
    }

    mutating func undo() {
        guard let previous = history.popLast() else { return }
        fills = previous
    }

    static func load(defaults: UserDefaults = .standard) -> ColoringEngine {
        guard let data = defaults.data(forKey: "atelier.engine"),
              let value = try? JSONDecoder().decode(ColoringEngine.self, from: data)
        else { return ColoringEngine() }
        return value
    }

    func persist(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "atelier.engine")
    }
}

// MARK: - Rotas

private enum AtelierRoute: Hashable {
    case library
    case gallery
    case settings
    case editor(UUID)
}

// MARK: - Raiz com captura p/ screenshots (home/editor/saved)

struct AtelierRoot: View {
    @StateObject private var store = AtelierStore()
    @AppStorage("atelier.savedArtCount") private var savedArtCount = 0
    @AppStorage("atelier.hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var path = NavigationPath()
    private let accent = Color(red: 0.86, green: 0.30, blue: 0.25)
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if capture == "editor" {
                    editorCapture
                } else if capture == "saved" {
                    AtelierGalleryView(store: store, onOpen: { _ in })
                } else {
                    ColoringHome(store: store, path: $path)
                }
            }
            .navigationDestination(for: AtelierRoute.self) { route in
                switch route {
                case .library:
                    AtelierLibraryView(store: store, onOpen: { openEditor($0) })
                case .gallery:
                    AtelierGalleryView(store: store, onOpen: { openEditor($0) })
                case .settings:
                    AtelierSettingsView(store: store)
                case .editor(let id):
                    AtelierEditorView(store: store, instanceId: id)
                }
            }
        }
        .tint(accent)
        .onAppear {
            if FactoryCapture.isUITesting {
                FactoryCapture.resetAppDefaults()
                savedArtCount = 0
            }
        }
        .sheet(isPresented: Binding(
            get: { !hasSeenOnboarding && !FactoryCapture.isUITesting && capture == nil },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            AtelierOnboarding(done: { hasSeenOnboarding = true })
        }
    }

    private var editorCapture: some View {
        // Screenshot determinística: mandala parcialmente colorida
        let art = AtelierLibrary.artwork(id: "mandala-cerrado")
        return VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Editor demonstrativo",
                title: art.title,
                subtitle: "Toque nas regiões para colorir. Use desfazer para experimentar sem medo.",
                accent: accent
            )
            AtelierCanvas(
                artwork: art,
                fills: [0: 2, 1: 0, 2: 3, 3: 4, 5: 1, 8: 5, 13: 6, 21: 7],
                onTap: nil
            )
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(red: 1, green: 0.97, blue: 0.91), in: RoundedRectangle(cornerRadius: 24))
            FactoryPanel(title: "Sua paleta", systemImage: "paintpalette.fill") {
                Text("12 cores + personalizada").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity)
        .background(Color(red: 1.0, green: 0.976, blue: 0.94).ignoresSafeArea())
        .navigationTitle("Colorir")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openEditor(_ instance: AtelierArtInstance) {
        path.append(AtelierRoute.editor(instance.id))
    }
}

// MARK: - Início (mantém textos/IDs dos UI tests)

struct ColoringHome: View {
    @ObservedObject var store: AtelierStore
    @Binding var path: NavigationPath
    @AppStorage("atelier.savedArtCount") private var savedArtCount = 0
    private let accent = Color(red: 0.86, green: 0.30, blue: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            FactoryHeader(
                eyebrow: "Seu espaço criativo",
                title: "Um momento só seu.",
                subtitle: "12 artes originais em 6 categorias. Escolha, encontre suas cores e deixe a imaginação guiar.",
                accent: accent
            )

            FactoryPanel {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(Color(red: 1, green: 0.97, blue: 0.91))
                    AtelierCanvas(
                        artwork: AtelierLibrary.artwork(id: "jardim-tracos"),
                        fills: store.latestInstance(for: "jardim-tracos")?.fills ?? [:]
                    )
                    .padding(18)
                }
                .frame(height: 220)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Jardim em traços").font(.title3.bold())
                    Text("Ilustração autoral · 9 regiões").font(.subheadline).foregroundStyle(.secondary)
                }
                Button { startQuick() } label: {
                    Label("Começar a colorir", systemImage: "paintpalette.fill")
                }
                .buttonStyle(FactoryPrimaryButtonStyle())
            }

            HStack(spacing: 12) {
                FactoryMetric(
                    label: "Minhas artes",
                    value: "\(store.instances.count)",
                    symbol: "square.stack.3d.up.fill",
                    tint: accent
                )
                FactoryMetric(
                    label: "Paleta",
                    value: "12 cores",
                    symbol: "circle.lefthalf.filled",
                    tint: .orange
                )
                FactoryMetric(
                    label: "Minutos",
                    value: "\(store.totalMinutes)",
                    symbol: "clock.fill",
                    tint: .green
                )
            }

            FactoryPanel(title: "Biblioteca", systemImage: "books.vertical.fill") {
                Text("6 infantis · 6 para relaxar — Natureza, Mandalas, Brasília, Animais, Aventura e Vitral.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button { path.append(AtelierRoute.library) } label: {
                    Label("Explorar as 12 artes", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button { path.append(AtelierRoute.gallery) } label: {
                    Label("Abrir minhas artes", systemImage: "square.stack.3d.up.fill")
                }
                .buttonStyle(.bordered)
                Button { path.append(AtelierRoute.settings) } label: {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .buttonStyle(.bordered)
            }

            FactoryPanel(title: "Obra do dia", systemImage: "calendar.badge.clock") {
                let art = AtelierLibrary.artworkOfTheDay()
                HStack(spacing: 14) {
                    AtelierCanvas(artwork: art, fills: store.latestInstance(for: art.id)?.fills ?? [:])
                        .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(art.title).font(.headline)
                        Text("\(art.regionCount) regiões · \(art.category.title)")
                            .font(.caption).foregroundStyle(.secondary)
                        if AtelierStreak.current() > 1 {
                            Label("\(AtelierStreak.current()) dias criando", systemImage: "flame.fill")
                                .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                }
                Button {
                    let inst = store.openOrCreate(artworkId: art.id)
                    AtelierExporter.impact()
                    path.append(AtelierRoute.editor(inst.id))
                } label: {
                    Label("Pintar obra do dia", systemImage: "paintbrush.pointed.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }

            FactoryPanel(title: "Selos", systemImage: "medal.fill") {
                let badges = AtelierBadges.earned(store: store)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                    ForEach(badges) { badge in
                        VStack(spacing: 5) {
                            Image(systemName: badge.systemImage)
                                .font(.title3)
                                .foregroundStyle(badge.earned ? accent : .secondary.opacity(0.4))
                            Text(badge.title)
                                .font(.caption2)
                                .foregroundStyle(badge.earned ? .primary : .secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .opacity(badge.earned ? 1 : 0.6)
                        .accessibilityLabel("\(badge.title): \(badge.earned ? "conquistado" : "bloqueado")")
                    }
                }
            }
        }
        .factoryPage(backgroundColor: Color(red: 1.0, green: 0.976, blue: 0.94))
        .navigationTitle("Ateliê")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startQuick() {
        let inst = store.openOrCreate(artworkId: "jardim-tracos")
        AtelierExporter.impact()
        path.append(AtelierRoute.editor(inst.id))
    }
}

// MARK: - Onboarding (3 passos, só na primeira abertura)

private struct AtelierOnboarding: View {
    var done: () -> Void

    var body: some View {
        NavigationStack {
            TabView {
                OnboardingPage(
                    systemImage: "books.vertical.fill",
                    title: "12 artes para todos",
                    text: "Traços simples para crianças e mandalas detalhadas para desacelerar. Tudo criado no app, sem downloads."
                )
                OnboardingPage(
                    systemImage: "paintpalette.fill",
                    title: "Toque para colorir",
                    text: "12 cores, uma cor personalizada, desfazer e refazer ilimitados, zoom para os detalhes."
                )
                OnboardingPage(
                    systemImage: "square.stack.3d.up.fill",
                    title: "Sua coleção, seu aparelho",
                    text: "Tudo salvo offline. Exporte PNG em alta resolução para compartilhar ou imprimir quando quiser."
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .navigationTitle("Bem-vindo ao Ateliê")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Começar") { done() }.font(.headline)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct OnboardingPage: View {
    var systemImage: String
    var title: String
    var text: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(Color(red: 0.86, green: 0.30, blue: 0.25))
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(text).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
