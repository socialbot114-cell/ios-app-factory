import SwiftUI
import UIKit

enum FactoryCapture {
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("--uitesting") }

    static var screen: String? {
        ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--capture=") })?
            .replacingOccurrences(of: "--capture=", with: "")
    }

    static func resetAppDefaults() {
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: identifier)
    }
}

enum FactoryColor {
    static let ink = Color(red: 0.10, green: 0.14, blue: 0.19)
    static let muted = Color(red: 0.40, green: 0.45, blue: 0.50)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

struct FactoryHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(FactoryColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FactoryPanel<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                HStack(spacing: 9) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(.tint)
                    }
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        }
    }
}

struct FactoryDemoNotice: View {
    var message: String = "Versão demonstrativa · dados locais"

    var body: some View {
        Label(message, systemImage: "info.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.045), in: Capsule())
            .accessibilityLabel(message)
    }
}

struct FactoryMetric: View {
    let label: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct FactoryPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension View {
    func factoryPage() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                self
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .padding(.bottom, 92)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(FactoryColor.canvas.ignoresSafeArea())
    }
}
