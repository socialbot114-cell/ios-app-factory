import SwiftUI

/// Fundo cinematográfico das telas de abertura e onboarding.
///
/// Vai sempre em `.background { }`: a imagem recebe o tamanho exato da tela e é recortada, então nunca
/// aumenta o layout do conteúdo (uma imagem `scaledToFill` solta num ZStack alarga tudo e desproporciona as telas).
struct FootballBackdrop: View {
    let drift: Bool
    var imageOpacity = 0.5
    var zoom: CGFloat = 1.14
    var topShade = 0.3
    var glow = 0.2
    var seconds = 16.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("MatchSceneV2")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(drift ? zoom : 1.0)
                    .animation(.easeInOut(duration: seconds).repeatForever(autoreverses: true), value: drift)
                    .opacity(imageOpacity)
                LinearGradient(colors: [Color.black.opacity(topShade), Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [FootballTheme.gold.opacity(glow), .clear], center: .top, startRadius: 10, endRadius: 400)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .background(Color.black)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
