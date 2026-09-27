import SwiftUI

// MARK: - Galeria: grid real com thumbnails, CRUD, busca, exportados

struct AtelierGalleryView: View {
    @ObservedObject var store: AtelierStore
    var onOpen: (AtelierArtInstance) -> Void
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var sort: Sort = .recent
    @State private var renaming: AtelierArtInstance? = nil
    @State private var renameText = ""
    @State private var albumText = ""
    @State private var albumFilter: String? = nil
    @State private var timelapseBusy = false
    @State private var deleting: AtelierArtInstance? = nil
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    private let accent = Color(red: 0.86, green: 0.30, blue: 0.25)

    enum Sort: String, CaseIterable, Identifiable {
        case recent, name, progress
        var id: String { rawValue }
        var title: String {
            switch self {
            case .recent: return "Recentes"
            case .name: return "Nome"
            case .progress: return "Progresso"
            }
        }
    }

    var filtered: [AtelierArtInstance] {
        var list = store.instances
        if favoritesOnly { list = list.filter { $0.isFavorite } }
        if let album = albumFilter { list = list.filter { $0.album == album } }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter {
                $0.displayTitle(fallback: AtelierLibrary.artwork(id: $0.artworkId).title)
                    .localizedCaseInsensitiveContains(q)
            }
        }
        switch sort {
        case .recent: list.sort { $0.updatedAt > $1.updatedAt }
        case .name:
            list.sort {
                $0.displayTitle(fallback: AtelierLibrary.artwork(id: $0.artworkId).title).localizedCompare(
                    $1.displayTitle(fallback: AtelierLibrary.artwork(id: $1.artworkId).title)) == .orderedAscending
            }
        case .progress:
            list.sort {
                progress($0) > progress($1)
            }
        }
        return list
    }

    func progress(_ inst: AtelierArtInstance) -> Double {
        inst.progress(regionCount: AtelierLibrary.artwork(id: inst.artworkId).regionCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Sua coleção",
                title: "Minhas artes",
                subtitle: "Tudo guardado neste aparelho. Toque para continuar, arraste para mais ações.",
                accent: accent
            )

            HStack {
                TextField("Buscar nas suas artes", text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker("Ordenar", selection: $sort) {
                    ForEach(Sort.allCases) { s in Text(s.title).tag(s) }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Ordenar")
            }

            Toggle(isOn: $favoritesOnly) {
                Label("Só favoritas", systemImage: "star.fill")
                    .font(.subheadline)
            }
            .tint(.yellow)

            if timelapseBusy {
                HStack {
                    ProgressView()
                    Text("Gerando timelapse…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Gerando timelapse")
            }

            if !store.albums.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        albumChip(title: "Todos os álbuns", selected: albumFilter == nil) { albumFilter = nil }
                        ForEach(store.albums, id: \.self) { album in
                            albumChip(title: album, selected: albumFilter == album) {
                                albumFilter = (albumFilter == album) ? nil : album
                            }
                        }
                    }
                }
            }

            if filtered.isEmpty {
                if store.instances.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma arte salva",
                        systemImage: "paintpalette",
                        description: Text("Abra a biblioteca e salve sua primeira ilustração.")
                    )
                    if FactoryCapture.screen == "saved" {
                        FactoryPanel {
                            HStack(spacing: 16) {
                                AtelierCanvas(
                                    artwork: AtelierLibrary.artwork(id: "mandala-cerrado"),
                                    fills: [0: 2, 1: 0, 2: 3, 3: 4, 5: 1, 8: 5, 13: 6, 21: 7, 30: 0, 40: 4]
                                )
                                .frame(width: 140, height: 140)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Mandala do cerrado").font(.headline)
                                    Label("Prévia demonstrativa", systemImage: "info.circle")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("As suas exportações aparecerão aqui.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Sem resultados",
                        systemImage: "magnifyingglass",
                        description: Text("Ajuste a busca ou desative o filtro de favoritas.")
                    )
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(filtered) { inst in
                        let art = AtelierLibrary.artwork(id: inst.artworkId)
                        GalleryCard(
                            instance: inst,
                            artwork: art,
                            accent: accent,
                            onOpen: { onOpen(inst) },
                            onFavorite: { store.toggleFavorite(id: inst.id) },
                            onRename: {
                                renaming = inst
                                renameText = inst.displayTitle(fallback: art.title)
                                albumText = inst.album ?? ""
                            },
                            onDuplicate: { _ = store.duplicate(id: inst.id) },
                            onDelete: { deleting = inst },
                            onShare: { share(inst: inst, artwork: art) },
                            onTimelapse: { makeTimelapse(inst: inst, artwork: art) }
                        )
                    }
                }
            }

            legacyExportsSection
        }
        .factoryPage()
        .navigationTitle("Minhas artes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $renaming) { inst in
            NavigationStack {
                Form {
                    TextField("Nome da arte", text: $renameText)
                        .textInputAutocapitalization(.words)
                    TextField("Álbum (opcional)", text: $albumText)
                        .textInputAutocapitalization(.words)
                }
                .navigationTitle("Renomear")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { renaming = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salvar") {
                            store.rename(id: inst.id, title: renameText)
                            store.setAlbum(id: inst.id, album: albumText)
                            renaming = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert(
            "Excluir esta arte?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            actions: {
                Button("Excluir", role: .destructive) {
                    if let inst = deleting { store.delete(id: inst.id) }
                    deleting = nil
                }
                Button("Cancelar", role: .cancel) { deleting = nil }
            },
            message: { Text("Essa ação não pode ser desfeita.") }
        )
        .sheet(isPresented: $showShare) {
            if !shareItems.isEmpty { AtelierShareSheet(items: shareItems) }
        }
    }

    private var legacyExportsSection: some View {
        let files = AtelierStore.legacyExportedArtURLs
        return FactoryPanel(title: "PNGs exportados (\(files.count))", systemImage: "photo.artframe") {
            if files.isEmpty {
                Text("Ao tocar em “Salvar e compartilhar PNG” no editor, o arquivo aparece aqui para reenviar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(files.prefix(8), id: \.absoluteString) { url in
                    HStack {
                        Image(systemName: "photo.artframe").font(.title3).foregroundStyle(accent)
                        Text(url.deletingPathExtension().lastPathComponent)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("Compartilhar arte")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func share(inst: AtelierArtInstance, artwork: AtelierArtwork) {
        let scale = UserDefaults.standard.object(forKey: "atelier.exportScale") as? Int ?? 2
        let bgName = UserDefaults.standard.string(forKey: "atelier.exportBackground") ?? "white"
        let format = UserDefaults.standard.string(forKey: "atelier.exportFormat") ?? "png"
        let background: Color? = (bgName == "transparent") ? nil : Color.white
        let customs = inst.effectiveCustomColors()
        let title = inst.displayTitle(fallback: artwork.title)
        if format == "jpeg" {
            guard let data = AtelierExporter.jpegData(
                artwork: artwork, fills: inst.fills, customs: customs,
                exportScale: scale, background: background ?? Color.white
            ) else { return }
            if let url = AtelierExporter.saveData(data, title: title, ext: "jpg"),
               let image = UIImage(data: data) {
                shareItems = [image, url]
                showShare = true
            }
        } else {
            guard let data = AtelierExporter.pngData(
                artwork: artwork, fills: inst.fills, customs: customs,
                exportScale: scale, background: background
            ) else { return }
            if let url = AtelierExporter.savePNG(data, title: title),
               let image = UIImage(data: data) {
                shareItems = [image, url]
                showShare = true
            }
        }
    }

    private func makeTimelapse(inst: AtelierArtInstance, artwork: AtelierArtwork) {
        guard !timelapseBusy, !inst.events.isEmpty else { return }
        timelapseBusy = true
        Task { @MainActor in
            let url = AtelierExporter.timelapseURL(
                artwork: artwork, events: inst.events, customs: inst.effectiveCustomColors()
            )
            timelapseBusy = false
            if let url {
                shareItems = [url]
                showShare = true
            }
        }
    }

    private func albumChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct GalleryCard: View {
    var instance: AtelierArtInstance
    var artwork: AtelierArtwork
    var accent: Color
    var onOpen: () -> Void
    var onFavorite: () -> Void
    var onRename: () -> Void
    var onDuplicate: () -> Void
    var onDelete: () -> Void
    var onShare: () -> Void
    var onTimelapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 1, green: 0.97, blue: 0.91))
                    AtelierThumbView(
                        id: instance.id,
                        artwork: artwork,
                        fills: instance.fills,
                        customs: instance.effectiveCustomColors()
                    )
                    .padding(10)
                    .frame(height: 140)
                    if instance.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .padding(8)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir \(instance.displayTitle(fallback: artwork.title))")

            Text(instance.displayTitle(fallback: artwork.title))
                .font(.headline)
                .lineLimit(1)
            ProgressView(value: instance.progress(regionCount: artwork.regionCount))
                .tint(accent)
            Text("\(instance.fills.count)/\(artwork.regionCount) · \(formattedDate)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                IconButton(systemImage: instance.isFavorite ? "star.fill" : "star", tint: .yellow, label: "Favoritar", action: onFavorite)
                IconButton(systemImage: "pencil", label: "Renomear", action: onRename)
                IconButton(systemImage: "plus.square.on.square", label: "Duplicar", action: onDuplicate)
                IconButton(systemImage: "square.and.arrow.up", label: "Compartilhar", action: onShare)
                IconButton(systemImage: "trash", tint: .red, label: "Excluir", action: onDelete)
            }
            if !instance.events.isEmpty {
                Button(action: onTimelapse) {
                    Label("Ver timelapse", systemImage: "film.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(accent)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button { onOpen() } label: { Label("Continuar pintando", systemImage: "paintbrush.pointed.fill") }
            Button { onFavorite() } label: { Label(instance.isFavorite ? "Desfavoritar" : "Favoritar", systemImage: "star") }
            Button { onRename() } label: { Label("Renomear", systemImage: "pencil") }
            Button { onDuplicate() } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
            Button { onShare() } label: { Label("Compartilhar imagem", systemImage: "square.and.arrow.up") }
            if !instance.events.isEmpty {
                Button { onTimelapse() } label: { Label("Exportar timelapse", systemImage: "film.fill") }
            }
            Button(role: .destructive) { onDelete() } label: { Label("Excluir", systemImage: "trash") }
        }
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f.string(from: instance.updatedAt)
    }
}

private struct IconButton: View {
    var systemImage: String
    var tint: Color = .primary
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
