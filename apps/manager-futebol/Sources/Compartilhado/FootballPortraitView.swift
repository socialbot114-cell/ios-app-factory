import SwiftUI

/// Retrato de um atleta: o busto 3D com a camisa pintada na cor do clube. O mesmo atleta tem sempre o mesmo rosto.
/// A camisa vem como máscara à parte; multiplicar a cor do clube pela camisa branca mantém as sombras.
struct FootballPortraitView: View {
    let player: FootballPlayer
    var kit: Color = FootballTheme.accent
    var size: CGFloat = 56
    /// Em listas, recorta o rosto num círculo; fora delas, mostra o busto inteiro.
    var face = false

    var body: some View {
        let spec = FootballPortraits.spec(playerID: player.id, age: player.age, region: player.region)
        let figure = ZStack {
            Image(spec.assetName).resizable().scaledToFit()
            Image(spec.maskName).resizable().renderingMode(.template).scaledToFit()
                .foregroundStyle(kit).blendMode(.multiply)
        }
        .compositingGroup()
        Group {
            if face {
                figure
                    .scaleEffect(1.9, anchor: UnitPoint(x: 0.5, y: 0.3))
                    .frame(width: size, height: size)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
            } else {
                figure
                    .frame(width: size, height: size * 1.25)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            }
        }
        .accessibilityHidden(true)
    }
}
