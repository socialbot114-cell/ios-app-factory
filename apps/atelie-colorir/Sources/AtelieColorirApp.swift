import SwiftUI
import UIKit

@main
struct AtelieColorirApp: App {
    var body: some Scene { WindowGroup { ColoringHome() } }
}

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
        guard let data = defaults.data(forKey: "atelier.engine"), let value = try? JSONDecoder().decode(ColoringEngine.self, from: data) else { return ColoringEngine() }
        return value
    }

    func persist(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "atelier.engine")
    }
}

private enum ColoringPalette {
    static let colors: [Color] = [
        Color(red: 0.99, green: 0.42, blue: 0.33), Color(red: 0.10, green: 0.43, blue: 0.48),
        Color(red: 0.98, green: 0.75, blue: 0.28), Color(red: 0.56, green: 0.40, blue: 0.72),
        Color(red: 0.38, green: 0.67, blue: 0.48), Color(red: 0.98, green: 0.57, blue: 0.32)
    ]
}

struct ColoringHome: View {
    @AppStorage("atelier.savedArtCount") private var savedArtCount = 1
    @State private var showEditor = false
    @State private var showSaved = false
    private let accent = Color(red: 0.86, green: 0.30, blue: 0.25)
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "saved" || showSaved {
                    savedArts
                } else if capture == "editor" || showEditor {
                    ColoringEditor(onSave: { _ in savedArtCount += 1 })
                } else {
                    home
                }
            }
            .toolbar {
                if capture == "editor" || showEditor || capture == "saved" || showSaved {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Início", systemImage: "chevron.left") { showEditor = false; showSaved = false }
                    }
                }
            }
        }
        .tint(accent)
        .onAppear {
            if FactoryCapture.isUITesting {
                FactoryCapture.resetAppDefaults()
                savedArtCount = 1
            }
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 22) {
            FactoryHeader(eyebrow: "Seu espaço criativo", title: "Um momento só seu.", subtitle: "Escolha uma ilustração, encontre suas cores e deixe a imaginação guiar.", accent: accent)
            FactoryDemoNotice()
            FactoryPanel {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(Color(red: 1, green: 0.97, blue: 0.91))
                    ColoringArtwork(fills: [:]).padding(18)
                }
                .frame(height: 220)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Jardim em traços").font(.title3.bold())
                    Text("Ilustração demonstrativa · 9 regiões") .font(.subheadline).foregroundStyle(.secondary)
                }
                Button { showEditor = true } label: {
                    Label("Começar a colorir", systemImage: "paintpalette.fill")
                }
                .buttonStyle(FactoryPrimaryButtonStyle())
            }
            HStack(spacing: 12) {
                FactoryMetric(label: "Minhas artes", value: "\(savedArtCount)", symbol: "square.stack.3d.up.fill", tint: accent)
                FactoryMetric(label: "Paleta", value: "6 cores", symbol: "circle.lefthalf.filled", tint: .orange)
            }
            FactoryPanel(title: "Continue explorando", systemImage: "sparkles") {
                Text("Natureza · Mandalas · Brasília")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Coleção visual de demonstração. As ilustrações finais serão adicionadas após a etapa de arte e licenciamento.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button { showSaved = true } label: { Label("Abrir minhas artes", systemImage: "square.stack.3d.up.fill") }
                .buttonStyle(.bordered)
        }
        .factoryPage(backgroundColor: Color(red: 1.0, green: 0.976, blue: 0.94))
        .navigationTitle("Ateliê")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var savedArts: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Sua coleção", title: "Minhas artes", subtitle: "PNG exportados ficam guardados neste aparelho.", accent: accent)
            FactoryDemoNotice()
            let files = Self.exportedArtURLs
            if files.isEmpty {
                if capture == "saved" {
                    FactoryPanel {
                        Label("PNG de demonstração", systemImage: "photo.artframe")
                            .font(.headline)
                        Text("Salve sua primeira arte no editor para criar uma imagem real nesta coleção.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView("Nenhuma arte salva", systemImage: "paintpalette", description: Text("Abra o editor e salve sua primeira ilustração."))
                    Button { showSaved = false; showEditor = true } label: { Label("Começar a colorir", systemImage: "paintbrush.pointed.fill") }
                        .buttonStyle(FactoryPrimaryButtonStyle())
                }
            } else {
                ForEach(files, id: \.absoluteString) { url in
                    FactoryPanel {
                        HStack {
                            Image(systemName: "photo.artframe").font(.title2).foregroundStyle(accent)
                            Text(url.deletingPathExtension().lastPathComponent).font(.headline)
                            Spacer()
                            ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                                .accessibilityLabel("Compartilhar arte")
                        }
                    }
                }
            }
        }
        .factoryPage().navigationTitle("Minhas artes").navigationBarTitleDisplayMode(.inline)
    }

    static var exportedArtURLs: [URL] {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ColoringExports", isDirectory: true)
        return ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}

struct ColoringEditor: View {
    var onSave: (UIImage) -> Void = { _ in }
    @State private var engine = ColoringEngine.load()
    @State private var selectedColor = 0
    @State private var showShare = false
    @State private var shareImage: UIImage?
    private let accent = Color(red: 0.86, green: 0.30, blue: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(eyebrow: "Editor demonstrativo", title: "Jardim em traços", subtitle: "Toque nas regiões para colorir. Use desfazer para experimentar sem medo.", accent: accent)
            ColoringArtwork(fills: engine.fills) { region in engine.fill(region: region, color: selectedColor) }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(red: 1, green: 0.97, blue: 0.91), in: RoundedRectangle(cornerRadius: 24))
            FactoryPanel(title: "Sua paleta", systemImage: "paintpalette.fill") {
                HStack(spacing: 12) {
                    ForEach(ColoringPalette.colors.indices, id: \.self) { index in
                        Button {
                            selectedColor = index
                        } label: {
                            Circle().fill(ColoringPalette.colors[index])
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(selectedColor == index ? Color.primary : .clear, lineWidth: 3).padding(-3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(["Coral", "Azul petróleo", "Amarelo", "Violeta", "Verde", "Laranja"][index])
                        .accessibilityValue(selectedColor == index ? "Selecionada" : "")
                        .accessibilityIdentifier("palette-color-\(index)")
                    }
                    Spacer(minLength: 0)
                    Button("Desfazer", systemImage: "arrow.uturn.backward") { engine.undo() }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Desfazer")
                }
            }
            Button {
                let renderer = ImageRenderer(content: ColoringArtwork(fills: engine.fills).frame(width: 900, height: 900))
                shareImage = renderer.uiImage
                if let image = shareImage, let data = image.pngData() {
                    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ColoringExports", isDirectory: true)
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        try data.write(to: folder.appendingPathComponent("arte-\(UUID().uuidString).png"), options: .atomic)
                        engine.persist()
                        onSave(image)
                        showShare = true
                    } catch { showShare = false }
                }
            } label: { Label("Salvar e compartilhar PNG", systemImage: "square.and.arrow.up") }
                .buttonStyle(FactoryPrimaryButtonStyle())
            Text("O rascunho é mantido nesta sessão demonstrativa. A exportação cria uma imagem local; nenhuma conexão é necessária.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity)
        .background(Color(red: 1.0, green: 0.976, blue: 0.94).ignoresSafeArea())
        .sheet(isPresented: $showShare) {
            if let shareImage { FactoryShareSheet(items: [shareImage]) }
        }
        .onChange(of: engine) { _, _ in engine.persist() }
        .navigationTitle("Colorir")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ColoringArtwork: View {
    var fills: [Int: Int]
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(Color(red: 0.87, green: 0.78, blue: 0.60).opacity(0.32)).frame(width: side * 0.57)
                ForEach(0..<9, id: \.self) { index in
                    let angle = Double(index) * 40 - 140
                    Button { onTap?(index) } label: {
                        PetalShape()
                            .fill(fills[index].map { ColoringPalette.colors[$0] } ?? .white)
                            .overlay(PetalShape().stroke(Color.black.opacity(0.82), lineWidth: 2.4))
                            .frame(width: side * 0.28, height: side * 0.46)
                            .offset(y: -side * 0.16)
                            .rotationEffect(.degrees(angle))
                            .contentShape(PetalShape())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Região \(index + 1)")
                    .accessibilityIdentifier("color-region-\(index)")
                }
                Circle().fill(Color(red: 0.98, green: 0.78, blue: 0.35))
                    .overlay(Circle().stroke(Color.black, lineWidth: 2.4))
                    .frame(width: side * 0.22)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.18))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18))
        path.closeSubpath()
        return path
    }
}

struct FactoryShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
