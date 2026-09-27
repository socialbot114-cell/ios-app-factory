import SwiftUI

// MARK: - Editor Pro: 12 cores + 4 customs, undo/redo persistente, zoom, progresso

struct AtelierEditorView: View {
    @ObservedObject var store: AtelierStore
    var instanceId: UUID
    @AppStorage("atelier.savedArtCount") private var savedArtCount = 0
    @State private var session: AtelierEditingSession
    @State private var selectedColor = 0
    @State private var customs: [Color]
    @State private var customSlot = 0
    @State private var recents: [Int] = []
    @State private var zoom: CGFloat = 1
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var showClearConfirm = false
    @State private var sessionStart = Date()
    private let accent = Color(red: 0.86, green: 0.30, blue: 0.25)

    private var instance: AtelierArtInstance? {
        store.instances.first(where: { $0.id == instanceId })
    }

    private var artwork: AtelierArtwork {
        AtelierLibrary.artwork(id: instance?.artworkId ?? "jardim-tracos")
    }

    init(store: AtelierStore, instanceId: UUID) {
        self.store = store
        self.instanceId = instanceId
        let inst = store.instances.first(where: { $0.id == instanceId })
        let art = AtelierLibrary.artwork(id: inst?.artworkId ?? "jardim-tracos")
        var s = AtelierEditingSession(regionCount: art.regionCount, fills: inst?.fills ?? [:])
        s.restore(undo: inst?.history ?? [], redo: inst?.redoStack ?? [])
        _session = State(initialValue: s)
        _customs = State(initialValue: inst?.effectiveCustomColors() ?? Array(repeating: AtelierPalette.defaultCustom, count: AtelierPalette.customCount))
        _recents = State(initialValue: (UserDefaults.standard.array(forKey: "atelier.recents") as? [Int] ?? [])
            .filter { (0..<AtelierPalette.totalCount).contains($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FactoryHeader(
                eyebrow: artwork.segment.title + " · " + artwork.category.title,
                title: instance?.displayTitle(fallback: artwork.title) ?? artwork.title,
                subtitle: "Toque nas regiões para colorir. Pinça para zoom, desfazer e refazer à vontade.",
                accent: accent
            )

            progressRow

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                AtelierCanvas(artwork: artwork, fills: session.fills, customs: customs) { region in
                    paint(region: region)
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(red: 1, green: 0.97, blue: 0.91), in: RoundedRectangle(cornerRadius: 24))
                .scaleEffect(zoom)
            }
            .frame(minHeight: 280, maxHeight: 420)

            zoomRow

            FactoryPanel(title: "Sua paleta · 12 cores + 4 pessoais", systemImage: "paintpalette.fill") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                    ForEach(0..<AtelierPalette.colors.count, id: \.self) { index in
                        paletteDot(index: index, color: AtelierPalette.colors[index])
                    }
                    ForEach(0..<customs.count, id: \.self) { slot in
                        let index = AtelierPalette.fixedCount + slot
                        Button {
                            selectedColor = index
                            customSlot = slot
                            pushRecent(index)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(customs[slot])
                                    .frame(width: 38, height: 38)
                                    .overlay(Circle().stroke(selectedColor == index ? Color.primary : .clear, lineWidth: 3).padding(-3))
                                Image(systemName: "eyedropper.half.full").font(.caption2).foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cor personalizada \(slot + 1)")
                        .accessibilityValue(selectedColor == index ? "Selecionada" : "")
                        .accessibilityIdentifier("palette-color-custom-\(slot)")
                    }
                }

                if AtelierPalette.customIndices.contains(selectedColor) {
                    ColorPicker("Ajustar personalizada \(customSlot + 1)", selection: customBinding(), supportsOpacity: false)
                        .font(.subheadline)
                } else {
                    Text("Toque numa cor pessoal (conta-gotas) para ajustar o tom.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !recents.isEmpty {
                    HStack(spacing: 10) {
                        Text("Recentes").font(.caption).foregroundStyle(.secondary)
                        ForEach(recents, id: \.self) { idx in
                            Button { selectedColor = idx } label: {
                                Circle()
                                    .fill(AtelierPalette.color(for: idx, customs: customs))
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Recente \(AtelierPalette.name(for: idx))")
                        }
                    }
                }

                HStack {
                    Button("Desfazer", systemImage: "arrow.uturn.backward") {
                        session.undo()
                        persist()
                    }
                    .disabled(!session.canUndo)
                    .accessibilityLabel("Desfazer")
                    .keyboardShortcut("z", modifiers: .command)

                    Button("Refazer", systemImage: "arrow.uturn.forward") {
                        session.redo()
                        persist()
                    }
                    .disabled(!session.canRedo)
                    .accessibilityLabel("Refazer")
                    .keyboardShortcut("z", modifiers: [.command, .shift])

                    Spacer()

                    Button("Limpar", systemImage: "trash", role: .destructive) {
                        showClearConfirm = true
                    }
                    .accessibilityLabel("Limpar pintura")
                    .confirmationDialog("Limpar esta arte?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                        Button("Limpar tudo", role: .destructive) {
                            session.clear()
                            persist()
                        }
                        Button("Cancelar", role: .cancel) {}
                    }
                }
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.medium))
            }

            Button(action: saveAndShare) {
                Label("Salvar e compartilhar PNG", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(FactoryPrimaryButtonStyle())
            .disabled(session.fills.isEmpty)

            Text("Salvamento automático neste aparelho. Exporte em alta resolução para compartilhar ou imprimir — sem conta, sem internet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity)
        .background(Color(red: 1.0, green: 0.976, blue: 0.94).ignoresSafeArea())
        .navigationTitle("Colorir")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if !shareItems.isEmpty { AtelierShareSheet(items: shareItems) }
        }
        .onAppear { sessionStart = Date() }
        .onDisappear {
            persist()
            store.addSeconds(id: instanceId, seconds: Date().timeIntervalSince(sessionStart))
        }
    }

    private func customBinding() -> Binding<Color> {
        Binding(
            get: { customs[customSlot] },
            set: { new in
                customs[customSlot] = new
                store.updateCustomColor(id: instanceId, slot: customSlot, color: new)
            }
        )
    }

    private var progressRow: some View {
        let total = artwork.regionCount
        let done = session.fills.count
        let pct = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(done)/\(total) regiões · \(pct)%")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(AtelierPalette.name(for: selectedColor))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("selected-color-name")
            }
            ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                .tint(accent)
        }
    }

    private var zoomRow: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            Slider(value: $zoom, in: 1...2.5, step: 0.1) {
                Text("Zoom")
            }
            .accessibilityLabel("Zoom")
            Text(String(format: "%.1fx", zoom))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40)
            Button("1x") { zoom = 1 }.font(.caption).buttonStyle(.bordered)
        }
    }

    private func paletteDot(index: Int, color: Color) -> some View {
        Button {
            selectedColor = index
            pushRecent(index)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(selectedColor == index ? Color.primary : .clear, lineWidth: 3).padding(-3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AtelierPalette.names[index])
        .accessibilityValue(selectedColor == index ? "Selecionada" : "")
        .accessibilityIdentifier("palette-color-\(index)")
    }

    private func pushRecent(_ index: Int) {
        var list = [index] + recents.filter { $0 != index }
        list = Array(list.prefix(6))
        recents = list
        UserDefaults.standard.set(list, forKey: "atelier.recents")
    }

    private func paint(region: Int) {
        let before = session.fills[region]
        session.fill(region: region, color: selectedColor)
        guard session.fills[region] != before else { return }
        pushRecent(selectedColor)
        AtelierExporter.impact()
        persist()
        store.addEvent(id: instanceId, region: region, color: selectedColor)
    }

    private func persist() {
        store.updateFills(id: instanceId, fills: session.fills)
        store.saveHistory(id: instanceId, undo: session.undoHistory, redo: session.redoHistory)
    }

    private func saveAndShare() {
        persist()
        let scale = UserDefaults.standard.object(forKey: "atelier.exportScale") as? Int ?? 2
        let bgName = UserDefaults.standard.string(forKey: "atelier.exportBackground") ?? "white"
        let format = UserDefaults.standard.string(forKey: "atelier.exportFormat") ?? "png"
        let background: Color? = (bgName == "transparent") ? nil : Color.white
        let title = instance?.displayTitle(fallback: artwork.title) ?? artwork.title
        if format == "jpeg" {
            guard let data = AtelierExporter.jpegData(
                artwork: artwork, fills: session.fills, customs: customs,
                exportScale: scale, background: background ?? Color.white
            ) else { return }
            let url = AtelierExporter.saveData(data, title: title, ext: "jpg")
            savedArtCount += 1
            saveToPhotosIfEnabled(data: data)
            if let image = UIImage(data: data) {
                shareItems = url.map { [image, $0] as [Any] } ?? [image]
            } else if let url {
                shareItems = [url]
            }
        } else {
            guard let data = AtelierExporter.pngData(
                artwork: artwork, fills: session.fills, customs: customs,
                exportScale: scale, background: background
            ) else { return }
            let url = AtelierExporter.savePNG(data, title: title)
            savedArtCount += 1
            saveToPhotosIfEnabled(data: data)
            if let image = UIImage(data: data) {
                shareItems = url.map { [image, $0] as [Any] } ?? [image]
            } else if let url {
                shareItems = [url]
            }
        }
        showShare = !shareItems.isEmpty
    }

    private func saveToPhotosIfEnabled(data: Data) {
        if UserDefaults.standard.object(forKey: "atelier.saveToPhotos") as? Bool == true,
           let image = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}

// MARK: - Compat: nome antigo usado pelo MVP e pelos UI tests

struct ColoringEditor: View {
    var onSave: (UIImage) -> Void = { _ in }
    @StateObject private var store = AtelierStore()
    @State private var instanceId: UUID?

    var body: some View {
        Group {
            if let id = instanceId, store.instances.contains(where: { $0.id == id }) {
                AtelierEditorView(store: store, instanceId: id)
                    .onDisappear { onSave(UIImage()) }
            } else {
                ProgressView().onAppear {
                    let inst = store.openOrCreate(artworkId: "jardim-tracos")
                    instanceId = inst.id
                }
            }
        }
    }
}
