import SwiftUI

/// Pulso de ícone (ANI-01): o ícone cresce e volta uma vez quando `active` vira verdadeiro, ou já está verdadeiro ao aparecer.
/// Com "reduzir movimento" ligado, o ícone fica parado. No Clássico, o pulso é mais curto (PIL-08).
struct FootballIconPulse: ViewModifier {
    let active: Bool
    let classic: Bool
    @State private var pulses = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: CGFloat(1), trigger: pulses) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.3, duration: classic ? 0.15 : 0.25)
                    CubicKeyframe(1, duration: classic ? 0.2 : 0.35)
                }
            }
            .onAppear(perform: run)
            .onChange(of: active) { _, _ in run() }
    }

    private func run() {
        guard active, !reduceMotion else { return }
        pulses += 1
    }
}
