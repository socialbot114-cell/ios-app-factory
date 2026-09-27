import SwiftUI

// MARK: - Biblioteca: 12 artes em Crianças / Relaxar

struct AtelierLibraryView: View {
    @ObservedObject var store: AtelierStore
    var onOpen: (AtelierArtInstance) -> Void
    @State private var segment: AtelierSegment? = nil
    @State private var category: AtelierCategory? = nil
    @State private var query = ""
    private let accent = Color(red: 0.86, green: 0.30, blue: 0.25)

    var filtered: [AtelierArtwork] {
        AtelierLibrary.artworks.filter { art in
            (segment == nil || art.segment == segment) &&
            (category == nil || art.category == category) &&
            (query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
             art.title.localizedCaseInsensitiveContains(query) ||
             art.subtitle.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Biblioteca · 12 artes",
                title: "O que vamos colorir?",
                subtitle: "Originais do app, sem licença pendente. Escolha e continue de onde parou.",
                accent: accent
            )

            SearchBar(query: $query)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Tudo", selected: segment == nil) { segment = nil }
                    ForEach(AtelierSegment.allCases) { s in
                        FilterChip(title: s.title, systemImage: s.systemImage, selected: segment == s) {
                            segment = (segment == s) ? nil : s
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Categorias", selected: false, enabled: false) {}
                    FilterChip(title: "Todas", selected: category == nil) { category = nil }
                    ForEach(AtelierCategory.allCases) { c in
                        FilterChip(title: c.title, selected: category == c) {
                            category = (category == c) ? nil : c
                        }
                    }
                }
            }

            if filtered.isEmpty {
                ContentUnavailableView(
                    "Nada por aqui",
                    systemImage: "magnifyingglass",
                    description: Text("Tente outra busca ou limpe os filtros.")
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(filtered) { art in
                        ArtworkCard(
                            artwork: art,
                            instance: store.latestInstance(for: art.id),
                            accent: accent,
                            onOpen: {
                                let inst = store.openOrCreate(artworkId: art.id)
                                AtelierExporter.impact()
                                onOpen(inst)
                            }
                        )
                    }
                }
            }

            FactoryPanel(title: "Artes licenciadas", systemImage: "tray.and.arrow.down.fill") {
                Text("Este catálogo é 100% autoral. Quando você enviar SVGs/PDFs licenciados, eles entram aqui sem mudar o editor — o motor já aceita novos traços por drop-in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .factoryPage(backgroundColor: Color(red: 1.0, green: 0.976, blue: 0.94))
        .navigationTitle("Biblioteca")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SearchBar: View {
    @Binding var query: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Buscar arte", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FilterChip: View {
    var title: String
    var systemImage: String? = nil
    var selected: Bool
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.caption) }
                Text(title).font(.subheadline.weight(selected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct ArtworkCard: View {
    var artwork: AtelierArtwork
    var instance: AtelierArtInstance?
    var accent: Color
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 1, green: 0.97, blue: 0.91))
                Group {
                    if let instance {
                        AtelierThumbView(
                            id: instance.id,
                            artwork: artwork,
                            fills: instance.fills,
                            customs: instance.effectiveCustomColors()
                        )
                        .padding(10)
                    } else {
                        AtelierCanvas(artwork: artwork, fills: [:])
                            .padding(10)
                    }
                }
            }
            .frame(height: 150)

            Text(artwork.title).font(.headline).lineLimit(1)
            Text("\(artwork.regionCount) regiões · \(artwork.category.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let instance, !instance.fills.isEmpty {
                ProgressView(value: instance.progress(regionCount: artwork.regionCount))
                    .tint(accent)
                Text(instance.fills.count == artwork.regionCount ? "Concluída" : "\(instance.fills.count)/\(artwork.regionCount) coloridas")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(action: onOpen) {
                Label(instance == nil ? "Colorir" : "Continuar", systemImage: "paintbrush.pointed.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .accessibilityIdentifier("open-\(artwork.id)")
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
