import Foundation

enum CrimeFormat {
    private static let suffixes = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

    /// "950", "12,4K", "3,07B" — escala curta de jogos idle.
    static func short(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }
        let sign = value < 0 ? "-" : ""
        var number = abs(value)
        if number < 1_000 {
            let text = number < 10 && number.rounded() != number
                ? String(format: "%.1f", number)
                : String(format: "%.0f", number.rounded(.down))
            return sign + text.replacingOccurrences(of: ".", with: ",")
        }
        var tier = 0
        while number >= 1_000 && tier < suffixes.count - 1 {
            number /= 1_000
            tier += 1
        }
        if number >= 1_000 {
            return sign + String(format: "%.2e", abs(value)).replacingOccurrences(of: ".", with: ",")
        }
        let decimals = number >= 100 ? 0 : (number >= 10 ? 1 : 2)
        let text = String(format: "%.\(decimals)f", floorTo(number, decimals: decimals))
        return sign + text.replacingOccurrences(of: ".", with: ",") + suffixes[tier]
    }

    static func cash(_ value: Double) -> String { "$" + short(value) }

    static func duration(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0).rounded(.up))
        if total < 60 { return "\(total)s" }
        let hours = total / 3_600, minutes = (total % 3_600) / 60, secs = total % 60
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h" }
        return secs > 0 ? "\(minutes)min \(secs)s" : "\(minutes)min"
    }

    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    /// Arredonda para baixo, para o jogador nunca ver mais dinheiro do que tem.
    private static func floorTo(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10, Double(decimals))
        return (value * factor).rounded(.down) / factor
    }
}
