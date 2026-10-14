import SwiftUI

/// Faixa de brilho que atravessa a superfície uma vez quando `active` vira verdadeiro, ou já está verdadeiro ao aparecer (ANI-01).
/// Com "reduzir movimento" ligado, não aparece nem anima.
struct FootballShineBand: View {
    let active: Bool
    @State private var sweep: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.5)
                .offset(x: proxy.size.width * (sweep * 1.5 - 0.5))
        }
        .clipped()
        .allowsHitTesting(false)
        .onAppear(perform: run)
        .onChange(of: active) { _, _ in run() }
    }

    private func run() {
        guard active, !reduceMotion else { return }
        sweep = 0
        withAnimation(.easeInOut(duration: 0.9)) { sweep = 1 }
    }
}
