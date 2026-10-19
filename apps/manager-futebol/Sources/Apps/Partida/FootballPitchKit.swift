import SwiftUI

// MARK: - Uniformes

struct PitchKit {
    enum Pattern { case solid, verticalStripes, hoops, halves, sash }

    var shirt: Color
    var trim: Color
    var shorts: Color
    var socks: Color
    var pattern: Pattern

    static func rgb(_ color: Color) -> (Double, Double, Double) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (Double(resolved.red), Double(resolved.green), Double(resolved.blue))
    }

    /// Distância entre cores de 0 (iguais) a 1 (preto contra branco).
    static func contrast(_ a: Color, _ b: Color) -> Double {
        let left = rgb(a)
        let right = rgb(b)
        let dr = left.0 - right.0, dg = left.1 - right.1, db = left.2 - right.2
        return (dr * dr + dg * dg + db * db).squareRoot() / 1.732
    }

    static func patternFor(_ teamID: Int) -> Pattern {
        [Pattern.solid, .verticalStripes, .hoops, .halves, .sash][abs(teamID) % 5]
    }

    static func home(_ team: LeagueTeam?) -> PitchKit {
        let primary = team?.primaryColor ?? FootballTheme.accent
        let secondary = team?.secondaryColor ?? .white
        let dark = contrast(primary, .black) < 0.28
        return PitchKit(shirt: primary, trim: secondary, shorts: dark ? secondary : (contrast(secondary, primary) > 0.3 ? secondary : .white),
                        socks: primary, pattern: patternFor(team?.id ?? 0))
    }

    /// Camisa reserva: o visitante troca de uniforme quando as cores se confundem com as do mandante.
    static func away(_ team: LeagueTeam?, against rival: PitchKit) -> PitchKit {
        let first = home(team)
        if contrast(first.shirt, rival.shirt) >= 0.34 && contrast(first.trim, rival.shirt) >= 0.2 { return first }
        let swapped = PitchKit(shirt: first.trim, trim: first.shirt, shorts: first.shirt, socks: first.trim, pattern: first.pattern == .solid ? .hoops : .solid)
        if contrast(swapped.shirt, rival.shirt) >= 0.34 { return swapped }
        return PitchKit(shirt: .white, trim: first.shirt, shorts: first.shirt, socks: .white, pattern: .sash)
    }

    static func keeper(avoiding colors: [Color]) -> PitchKit {
        let palette: [Color] = [Color(red: 0.55, green: 0.90, blue: 0.20), Color(red: 1.0, green: 0.55, blue: 0.10),
                                Color(red: 0.95, green: 0.35, blue: 0.65), Color(red: 0.25, green: 0.80, blue: 0.95),
                                Color(red: 0.62, green: 0.40, blue: 0.95)]
        let pick = palette.first { candidate in colors.allSatisfy { contrast(candidate, $0) > 0.4 } } ?? palette[0]
        return PitchKit(shirt: pick, trim: .black.opacity(0.5), shorts: .black, socks: pick, pattern: .solid)
    }
}
