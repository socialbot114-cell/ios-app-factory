import SwiftUI

/// Chuva de confete curta para vitórias. Vai em `.overlay`: não altera o layout e some sozinha.
struct FootballCelebrationBurst: View {
    var colors: [Color] = [FootballTheme.gold, .white, .green, .yellow, .orange]
    var count = 34
    /// Ritmo do FutOS: no Clássico a chuva tem menos partículas e termina antes.
    var rhythm: FootballRhythm = .immersive

    @State private var fired = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var particles: Int { rhythm.celebrationCount(count) }

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<particles, id: \.self) { index in
                    let angle = Double(index) / Double(particles) * 2 * .pi
                    let distance = 90.0 + Double((index * 37) % 70)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[index % colors.count])
                        .frame(width: 7, height: 11)
                        .rotationEffect(.degrees(fired ? Double(index * 53 % 360) : 0))
                        .offset(x: fired ? cos(angle) * distance : 0,
                                y: fired ? sin(angle) * distance + 40 : 0)
                        .opacity(fired ? 0 : 1)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .sensoryFeedback(.success, trigger: fired)
        .onAppear {
            withAnimation(.easeOut(duration: rhythm.celebrationSeconds(1.6))) { fired = true }
        }
    }
}
