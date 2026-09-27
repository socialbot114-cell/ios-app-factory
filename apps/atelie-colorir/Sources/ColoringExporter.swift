import SwiftUI
import UIKit
import AVFoundation
import CoreMedia
import CoreVideo

// MARK: - Exportação HD (PNG/JPEG local, Fotos, Compartilhar, timelapse)

@MainActor
enum AtelierExporter {
    static func image(
        artwork: AtelierArtwork,
        fills: [Int: Int],
        customs: [Color],
        background: Color?,
        pixelSize: CGFloat
    ) -> UIImage? {
        let canvas = AtelierCanvas(artwork: artwork, fills: fills, customs: customs)
            .frame(width: pixelSize, height: pixelSize)
        let content: AnyView
        if let background {
            content = AnyView(canvas.background(background))
        } else {
            content = AnyView(canvas)
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return renderer.uiImage
    }

    static func pngData(
        artwork: AtelierArtwork,
        fills: [Int: Int],
        customs: [Color],
        exportScale: Int,
        background: Color?
    ) -> Data? {
        let base: CGFloat = 900
        let size = base * CGFloat(max(1, min(3, exportScale)))
        guard let image = image(artwork: artwork, fills: fills, customs: customs, background: background, pixelSize: size) else { return nil }
        return image.pngData()
    }

    static func jpegData(
        artwork: AtelierArtwork,
        fills: [Int: Int],
        customs: [Color],
        exportScale: Int,
        background: Color,
        quality: CGFloat = 0.9
    ) -> Data? {
        let base: CGFloat = 900
        let size = base * CGFloat(max(1, min(3, exportScale)))
        guard let image = image(artwork: artwork, fills: fills, customs: customs, background: background, pixelSize: size) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }

    static func exportsFolder() -> URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ColoringExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func slug(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.isEmpty ? "arte" : trimmed
        let s = safe
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return s.isEmpty ? "arte" : String(s.prefix(40))
    }

    @discardableResult
    static func saveData(_ data: Data, title: String, ext: String) -> URL? {
        let url = exportsFolder().appendingPathComponent("\(slug(title))-\(UUID().uuidString.prefix(8)).\(ext)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @discardableResult
    static func savePNG(_ data: Data, title: String) -> URL? {
        saveData(data, title: title, ext: "png")
    }

    static func impact() {
        if UIAccessibility.isReduceMotionEnabled { return }
        let enabled = UserDefaults.standard.object(forKey: "atelier.haptics") as? Bool ?? true
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: Timelapse (até 60 quadros a partir dos eventos)

    static func timelapseURL(
        artwork: AtelierArtwork,
        events: [AtelierPaintEvent],
        customs: [Color]
    ) -> URL? {
        guard !events.isEmpty else { return nil }
        let size = CGSize(width: 720, height: 720)
        let url = exportsFolder().appendingPathComponent("timelapse-\(UUID().uuidString.prefix(8)).mov")
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return nil }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let step = max(1, events.count / 60)
        var fills: [Int: Int] = [:]
        var frameIndex: Int64 = 0
        let frameDuration = CMTime(value: 1, timescale: 10)
        var idx = 0
        while idx < events.count {
            let end = min(idx + step, events.count)
            for e in events[idx..<end] { fills[e.region] = e.color }
            idx = end
            guard let img = image(artwork: artwork, fills: fills, customs: customs, background: Color.white, pixelSize: size.width),
                  let buffer = Self.pixelBuffer(from: img, size: size) else { continue }
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
            adaptor.append(buffer, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex)))
            frameIndex += 1
        }
        // segura o quadro final
        if let img = image(artwork: artwork, fills: fills, customs: customs, background: Color.white, pixelSize: size.width),
           let buffer = Self.pixelBuffer(from: img, size: size) {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
            adaptor.append(buffer, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex)))
            frameIndex += 1
        }
        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()
        return writer.status == .completed ? url : nil
    }

    private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        guard let cg = image.cgImage else { return nil }
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                                  kCVPixelFormatType_32ARGB, attrs as CFDictionary, &buffer) == kCVReturnSuccess,
              let px = buffer else { return nil }
        CVPixelBufferLockBaseAddress(px, [])
        defer { CVPixelBufferUnlockBaseAddress(px, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(px),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(px),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(origin: .zero, size: size))
        return px
    }
}

struct AtelierShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Compat: nome antigo usado pelo MVP

struct FactoryShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
