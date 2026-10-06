import SwiftUI

/// "Foto" de um post: cena desenhada a partir do tipo (treino, jogo, torcida…), sem arquivos de imagem.
struct SocialPhotoView: View {
    let photo: SocialPhoto
    var seed = 0
    var height: CGFloat = 170

    private var colors: [Color] {
        switch photo {
        case .training: return [Color(red: 0.16, green: 0.55, blue: 0.28), Color(red: 0.05, green: 0.25, blue: 0.14)]
        case .matchday: return [Color(red: 0.10, green: 0.45, blue: 0.30), Color(red: 0.03, green: 0.15, blue: 0.20)]
        case .stadium: return [Color(red: 0.20, green: 0.30, blue: 0.55), Color(red: 0.05, green: 0.08, blue: 0.20)]
        case .trophy: return [Color(red: 0.95, green: 0.72, blue: 0.20), Color(red: 0.45, green: 0.25, blue: 0.05)]
        case .family: return [Color(red: 0.95, green: 0.55, blue: 0.40), Color(red: 0.55, green: 0.20, blue: 0.35)]
        case .crowd: return [Color(red: 0.75, green: 0.20, blue: 0.30), Color(red: 0.20, green: 0.05, blue: 0.15)]
        case .travel: return [Color(red: 0.30, green: 0.65, blue: 0.90), Color(red: 0.10, green: 0.25, blue: 0.50)]
        case .press: return [Color(red: 0.35, green: 0.35, blue: 0.45), Color(red: 0.08, green: 0.08, blue: 0.14)]
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                var state = UInt64(truncatingIfNeeded: abs(seed) &* 2_654_435_761 &+ photo.rawValue.count &* 97 &+ 12_345)
                func next() -> CGFloat {
                    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    return CGFloat((state >> 33) % 1000) / 1000
                }
                switch photo {
                case .crowd, .stadium:
                    for row in 0..<5 {
                        for column in 0..<18 {
                            let x = (CGFloat(column) + next() * 0.5) / 18 * size.width
                            let y = size.height * 0.35 + CGFloat(row) * size.height * 0.12 + next() * 4
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 9, height: 9)), with: .color(.white.opacity(0.18 + next() * 0.3)))
                        }
                    }
                case .training, .matchday:
                    let line = Path(CGRect(x: 0, y: size.height * 0.72, width: size.width, height: 2))
                    context.fill(line, with: .color(.white.opacity(0.35)))
                    context.stroke(Path(ellipseIn: CGRect(x: size.width * 0.35, y: size.height * 0.45, width: size.width * 0.3, height: size.height * 0.5)),
                                   with: .color(.white.opacity(0.25)), lineWidth: 2)
                    for _ in 0..<4 {
                        context.fill(Path(ellipseIn: CGRect(x: next() * size.width, y: size.height * 0.55 + next() * size.height * 0.3, width: 7, height: 7)),
                                     with: .color(.white.opacity(0.7)))
                    }
                default:
                    for _ in 0..<14 {
                        let dot = 4 + next() * 10
                        context.fill(Path(ellipseIn: CGRect(x: next() * size.width, y: next() * size.height, width: dot, height: dot)),
                                     with: .color(.white.opacity(0.07 + next() * 0.12)))
                    }
                }
            }
            Image(systemName: photo.symbol)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Label(photo.title, systemImage: "camera.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.black.opacity(0.35), in: Capsule())
                .padding(8)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Foto: \(photo.title)")
        .accessibilityIdentifier("social-photo")
    }
}

/// Faixa de histórias do dia, no topo da Chuteira.
struct SocialStoriesRow: View {
    let stories: [SocialStory]
    @State private var selected: SocialStory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(stories) { story in
                    Button { selected = story } label: {
                        VStack(spacing: 4) {
                            Image(systemName: story.authorSymbol)
                                .font(.title3).foregroundStyle(.white)
                                .frame(width: 58, height: 58)
                                .background(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2).padding(2))
                            Text(story.name).font(.caption2).foregroundStyle(.primary).lineLimit(1).frame(width: 62)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("story-\(story.id)")
                }
            }
            .padding(.horizontal, 2)
        }
        .sheet(item: $selected) { story in
            VStack(spacing: 16) {
                Text(story.name).font(.headline)
                SocialPhotoView(photo: story.photo, seed: story.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }, height: 320)
                Text(story.caption).font(.body).multilineTextAlignment(.center)
                Button("Fechar") { selected = nil }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            .presentationDetents([.medium, .large])
        }
    }
}
