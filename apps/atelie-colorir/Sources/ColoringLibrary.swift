import Foundation

// MARK: - Catálogo: 12 artes vetoriais próprias (híbido: drop-in licenciado depois)

enum AtelierLibrary {
    static let artworks: [AtelierArtwork] = [
        AtelierArtwork(
            id: "jardim-tracos",
            title: "Jardim em traços",
            subtitle: "A flor original do protótipo · 9 regiões",
            category: .natureza,
            segment: .infantil,
            kind: .flower9
        ),
        AtelierArtwork(
            id: "sol-alegre",
            title: "Sol alegre",
            subtitle: "Sol, raios e colinas · 11 regiões",
            category: .natureza,
            segment: .infantil,
            kind: .sunburst8
        ),
        AtelierArtwork(
            id: "peixinho-bolhas",
            title: "Peixinho e bolhas",
            subtitle: "Mosaico do fundo do mar · 16 regiões",
            category: .animais,
            segment: .infantil,
            kind: .mosaic44
        ),
        AtelierArtwork(
            id: "gatinho-listrado",
            title: "Gatinho listrado",
            subtitle: "Mosaico felpudo · 18 regiões",
            category: .animais,
            segment: .infantil,
            kind: .mosaic36
        ),
        AtelierArtwork(
            id: "foguete-espacial",
            title: "Foguete espacial",
            subtitle: "Missão às estrelas · 16 regiões",
            category: .aventura,
            segment: .infantil,
            kind: .mosaic28
        ),
        AtelierArtwork(
            id: "borboleta-jardim",
            title: "Borboleta do jardim",
            subtitle: "Asas em mandala leve · 21 regiões",
            category: .natureza,
            segment: .infantil,
            kind: .radial10x2
        ),
        AtelierArtwork(
            id: "mandala-cerrado",
            title: "Mandala do cerrado",
            subtitle: "Três anéis de pétalas · 49 regiões",
            category: .mandalas,
            segment: .relaxar,
            kind: .radial16x3
        ),
        AtelierArtwork(
            id: "mandala-noite",
            title: "Mandala da noite",
            subtitle: "Cinco anéis profundos · 61 regiões",
            category: .mandalas,
            segment: .relaxar,
            kind: .radial12x5
        ),
        AtelierArtwork(
            id: "ipe-amarelo",
            title: "Ipê-amarelo",
            subtitle: "Florada do Planalto · 41 regiões",
            category: .brasilia,
            segment: .relaxar,
            kind: .radial8x5
        ),
        AtelierArtwork(
            id: "arara-planalto",
            title: "Arara do Planalto",
            subtitle: "Mosaico de penas · 42 regiões",
            category: .animais,
            segment: .relaxar,
            kind: .mosaic67
        ),
        AtelierArtwork(
            id: "catedral-vitral",
            title: "Catedral em vitral",
            subtitle: "Homenagem a Brasília · 36 regiões",
            category: .brasilia,
            segment: .relaxar,
            kind: .mosaic66
        ),
        AtelierArtwork(
            id: "vitral-planalto",
            title: "Vitral do Planalto",
            subtitle: "Rosácea em quatro anéis · 53 regiões",
            category: .vitral,
            segment: .relaxar,
            kind: .radial13x4
        ),
    ]

    static func artwork(id: String) -> AtelierArtwork {
        artworks.first(where: { $0.id == id }) ?? artworks[0]
    }

    static var infantis: [AtelierArtwork] { artworks.filter { $0.segment == .infantil } }
    static var relaxar: [AtelierArtwork] { artworks.filter { $0.segment == .relaxar } }
}
