import Foundation

enum FootballFormat {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    /// Valor curto: "R$ 8,0 mi", "R$ 750 mil".
    static func money(_ value: Int) -> String {
        let sign = value < 0 ? "-" : ""
        let absolute = abs(value)
        if absolute >= 1_000_000 {
            let millions = decimalFormatter.string(from: NSNumber(value: Double(absolute) / 1_000_000)) ?? "\(absolute / 1_000_000)"
            return "\(sign)R$ \(millions) mi"
        }
        if absolute >= 1_000 {
            return "\(sign)R$ \(absolute / 1_000) mil"
        }
        return "\(sign)R$ \(absolute)"
    }

    static func fullMoney(_ value: Int) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "R$ \(value)"
    }

    /// Contagem curta: "12,5 mil", "1,2 mi".
    static func compact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return (decimalFormatter.string(from: NSNumber(value: Double(value) / 1_000_000)) ?? "\(value / 1_000_000)") + " mi"
        }
        if value >= 10_000 {
            return (decimalFormatter.string(from: NSNumber(value: Double(value) / 1_000)) ?? "\(value / 1_000)") + " mil"
        }
        return "\(value)"
    }

    static func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

    static func expectedGoals(_ value: Double?) -> String {
        guard let value else { return "—" }
        return decimalFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
