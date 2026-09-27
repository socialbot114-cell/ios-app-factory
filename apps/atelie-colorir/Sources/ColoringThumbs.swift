import SwiftUI
import UIKit

// MARK: - Cache de thumbnails (PNG 300px por obra; evita re-render vetorial contínuo)

enum AtelierThumbCache {
    static let pixelSize: CGFloat = 300
    private static let mem: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 60
        return c
    }()

    nonisolated static func fileURL(id: UUID) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Atelier/thumbs", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).png")
    }

    nonisolated static func cached(id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        if let img = mem.object(forKey: key) { return img }
        guard let data = try? Data(contentsOf: fileURL(id: id)),
              let img = UIImage(data: data) else { return nil }
        mem.setObject(img, forKey: key)
        return img
    }

    @MainActor
    @discardableResult
    static func refresh(id: UUID, artwork: AtelierArtwork, fills: [Int: Int], customs: [Color]) -> UIImage? {
        let view = AtelierCanvas(artwork: artwork, fills: fills, customs: customs)
            .frame(width: pixelSize, height: pixelSize)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let img = renderer.uiImage else { return cached(id: id) }
        mem.setObject(img, forKey: id.uuidString as NSString)
        let url = fileURL(id: id)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? img.pngData()?.write(to: url, options: .atomic)
        return img
    }

    nonisolated static func remove(id: UUID) {
        mem.removeObject(forKey: id.uuidString as NSString)
        try? FileManager.default.removeItem(at: fileURL(id: id))
    }
}

@MainActor
final class AtelierThumbState: ObservableObject {
    @Published var image: UIImage?

    func load(id: UUID, artwork: AtelierArtwork, fills: [Int: Int], customs: [Color]) {
        if image == nil { image = AtelierThumbCache.cached(id: id) }
        image = AtelierThumbCache.refresh(id: id, artwork: artwork, fills: fills, customs: customs)
    }
}

struct AtelierThumbView: View {
    var id: UUID
    var artwork: AtelierArtwork
    var fills: [Int: Int]
    var customs: [Color] = []
    @StateObject private var state = AtelierThumbState()

    var body: some View {
        Group {
            if let img = state.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            } else {
                AtelierCanvas(artwork: artwork, fills: fills, customs: customs)
            }
        }
        .onAppear { state.load(id: id, artwork: artwork, fills: fills, customs: customs) }
        .onChange(of: fills) { _, new in
            state.load(id: id, artwork: artwork, fills: new, customs: customs)
        }
    }
}
