import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

@main
struct MeuQrPixApp: App {
    var body: some Scene { WindowGroup { PixHome() } }
}

enum PixPayloadError: Error, Equatable {
    case invalidName
    case invalidCity
    case invalidKey
    case invalidAmount
}

struct PixDraft: Codable, Identifiable, Equatable {
    let id: UUID
    let payload: String
    let name: String
    let city: String
    let key: String
    let amount: String
    let createdAt: Date

    init(id: UUID = UUID(), payload: String, name: String, city: String, key: String, amount: String, createdAt: Date = .now) {
        self.id = id; self.payload = payload; self.name = name; self.city = city; self.key = key; self.amount = amount; self.createdAt = createdAt
    }
}

enum PixPayload {
    static func make(key: String, name: String, city: String, amount: String = "") throws -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, normalizedName.utf8.count <= 25 else { throw PixPayloadError.invalidName }
        guard !normalizedCity.isEmpty, normalizedCity.utf8.count <= 15 else { throw PixPayloadError.invalidCity }
        guard isSupportedKey(normalizedKey), normalizedKey.utf8.count <= 77 else { throw PixPayloadError.invalidKey }

        var payload = field("00", "01") + field("01", "11")
        let merchantAccount = field("00", "br.gov.bcb.pix") + field("01", normalizedKey)
        guard merchantAccount.utf8.count <= 99 else { throw PixPayloadError.invalidKey }
        payload += field("26", merchantAccount)
        payload += field("52", "0000") + field("53", "986")
        if !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalized = amount.replacingOccurrences(of: ",", with: ".")
            let pieces = normalized.split(separator: ".", omittingEmptySubsequences: false)
            guard pieces.count <= 2, !pieces[0].isEmpty, pieces[0].allSatisfy(\.isNumber),
                  pieces.count == 1 || (pieces[1].count <= 2 && pieces[1].allSatisfy(\.isNumber)) else {
                throw PixPayloadError.invalidAmount
            }
            guard let decimal = Decimal(string: normalized), decimal > 0 else { throw PixPayloadError.invalidAmount }
            guard decimal * 100 == (decimal * 100).rounded(.down) else { throw PixPayloadError.invalidAmount }
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.usesGroupingSeparator = false
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            guard let formatted = formatter.string(from: NSDecimalNumber(decimal: decimal)) else { throw PixPayloadError.invalidAmount }
            payload += field("54", formatted)
        }
        payload += field("58", "BR") + field("59", normalizedName) + field("60", normalizedCity)
        payload += field("62", field("05", "***"))
        let checksumInput = payload + "6304"
        return checksumInput + crc16(checksumInput)
    }

    static func crc16(_ input: String) -> String {
        var crc: UInt16 = 0xFFFF
        for byte in input.utf8 {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return String(format: "%04X", crc)
    }

    private static func field(_ id: String, _ value: String) -> String {
        id + String(format: "%02d", value.utf8.count) + value
    }

    private static func isSupportedKey(_ key: String) -> Bool {
        guard !key.isEmpty, key == key.trimmingCharacters(in: .whitespacesAndNewlines), !key.contains(where: \.isWhitespace) else { return false }
        if UUID(uuidString: key) != nil { return true }
        if key.contains("@") {
            let parts = key.split(separator: "@", omittingEmptySubsequences: false)
            return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".")
        }
        let digits = key.filter(\.isNumber)
        if digits == key { return digits.count == 11 || digits.count == 14 }
        if key.hasPrefix("+") { return key.dropFirst().allSatisfy(\.isNumber) && (10...13).contains(key.count - 1) }
        return false
    }
}

struct PixHome: View {
    @State private var key = "demo@example.invalid"
    @State private var name = "PESSOA DEMO"
    @State private var city = "BRASILIA"
    @State private var amount = "12,50"
    @State private var payload = (try? PixPayload.make(key: "demo@example.invalid", name: "PESSOA DEMO", city: "BRASILIA", amount: "12,50")) ?? ""
    @State private var errorMessage: String?
    @State private var copied = false
    @State private var selectedTab = 0
    @State private var history = PixHome.loadHistory()
    private let accent = Color(red: 0.0, green: 0.58, blue: 0.53)
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "qr" || selectedTab == 1 { qrView }
                else if capture == "history" || selectedTab == 2 { historyView }
                else { formView }
            }
            .safeAreaInset(edge: .bottom) { navigationBar }
        }
        .tint(accent)
        .onAppear {
            if FactoryCapture.isUITesting {
                FactoryCapture.resetAppDefaults()
                history = []
                selectedTab = 0
            }
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(eyebrow: "Gerado no aparelho", title: "Crie seu QR Pix.", subtitle: "Monte um código estático e confira todos os dados antes de compartilhar.", accent: accent)
            FactoryDemoNotice(message: "Demonstração · chave fictícia · não representa pagamento")
            FactoryPanel(title: "Dados do recebedor", systemImage: "person.crop.circle") {
                input("Chave Pix", text: $key, symbol: "key.fill", placeholder: "Sua chave")
                input("Nome", text: $name, symbol: "person.fill", placeholder: "Nome do recebedor")
                input("Cidade", text: $city, symbol: "mappin.and.ellipse", placeholder: "Cidade")
            }
            FactoryPanel(title: "Cobrança", systemImage: "banknote.fill") {
                TextField("Valor opcional", text: $amount, prompt: Text("R$ 0,00"))
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .accessibilityLabel("Valor em reais")
                Text("Valor de demonstração; revise os centavos antes de gerar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            Button(action: generate) { Label("Gerar QR estático", systemImage: "qrcode") }
                .buttonStyle(FactoryPrimaryButtonStyle())
            Text("O banco do recebedor confirma a entrada. Este app apenas cria o código.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .factoryPage().navigationTitle("Meu QR Pix").navigationBarTitleDisplayMode(.inline)
    }

    private var qrView: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(eyebrow: "Código criado", title: "Confira antes de compartilhar.", subtitle: "QR estático gerado localmente; não consulta nem confirma pagamentos.", accent: accent)
            FactoryDemoNotice(message: "DADOS FICTÍCIOS · CÓDIGO DE TESTE")
            FactoryPanel {
                QRCodeImage(payload: payload)
                    .frame(maxWidth: 270).padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .frame(maxWidth: .infinity)
                VStack(spacing: 5) {
                    Text(name).font(.headline)
                    Text(city).font(.subheadline).foregroundStyle(.secondary)
                    Text(amount.isEmpty ? "Sem valor definido" : "R$ \(amount)")
                        .font(.title2.bold()).foregroundStyle(accent)
                    Text("Chave: \(key)").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
                Button {
                    UIPasteboard.general.string = payload
                    copied = true
                } label: { Label(copied ? "Código copiado" : "Copiar código Pix", systemImage: copied ? "checkmark" : "doc.on.doc") }
                    .buttonStyle(FactoryPrimaryButtonStyle())
                ShareLink(item: payload) { Label("Compartilhar copia e cola", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            }
            Text("A tela confirma apenas que o código foi criado — nunca que houve pagamento.")
                .font(.footnote).foregroundStyle(.secondary)
        }.factoryPage().navigationTitle("QR gerado").navigationBarTitleDisplayMode(.inline)
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(eyebrow: "Neste aparelho", title: "Histórico local", subtitle: "Rascunhos de códigos criados nesta demonstração.", accent: accent)
            FactoryDemoNotice()
            ForEach(displayedHistory) { draft in
                Button { reopen(draft) } label: {
                    FactoryPanel {
                        HStack {
                            Image(systemName: "qrcode").font(.title2).foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(draft.name).font(.headline).foregroundStyle(.primary)
                                Text("\(draft.city) · \(draft.amount.isEmpty ? "sem valor" : "R$ \(draft.amount)")")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("Código criado · não pago · \(draft.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(accent)
                            }
                        }
                    }
                }.buttonStyle(.plain)
            }
            if displayedHistory.isEmpty {
                ContentUnavailableView("Nenhum código criado", systemImage: "qrcode", description: Text("Gere um QR para vê-lo no histórico local."))
            }
        }.factoryPage().navigationTitle("Histórico").navigationBarTitleDisplayMode(.inline)
    }

    private var navigationBar: some View {
        HStack {
            nav("Criar", symbol: "plus.circle.fill", index: 0)
            nav("QR", symbol: "qrcode", index: 1)
            nav("Histórico", symbol: "clock.arrow.circlepath", index: 2)
        }.padding(8).background(.regularMaterial, in: Capsule()).padding(.horizontal, 26).padding(.bottom, 8)
    }

    private var displayedHistory: [PixDraft] {
        if !history.isEmpty { return history }
        guard capture == "history" else { return [] }
        return [PixDraft(payload: payload, name: name, city: city, key: key, amount: amount)]
    }

    private func nav(_ title: String, symbol: String, index: Int) -> some View {
        Button { selectedTab = index } label: { Label(title, systemImage: symbol).font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 42).foregroundStyle(selectedTab == index ? accent : .secondary) }
            .buttonStyle(.plain)
    }

    private func input(_ title: String, text: Binding<String>, symbol: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(accent).frame(width: 20)
                TextField(placeholder, text: text).textInputAutocapitalization(.never).autocorrectionDisabled()
            }.padding(13).background(FactoryColor.canvas, in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func generate() {
        do {
            name = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            city = city.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            key = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let generated = try PixPayload.make(key: key, name: name, city: city, amount: amount)
            payload = generated
            errorMessage = nil
            let normalizedAmount = amount.replacingOccurrences(of: ",", with: ".")
            if let decimal = Decimal(string: normalizedAmount) {
                let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.usesGroupingSeparator = false; formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
                amount = formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? amount
            }
            let draft = PixDraft(payload: generated, name: name, city: city, key: key, amount: amount)
            history.insert(draft, at: 0)
            history = Array(history.prefix(20))
            Self.saveHistory(history)
            selectedTab = 1
        }
        catch PixPayloadError.invalidAmount { errorMessage = "Informe um valor maior que zero ou deixe o campo vazio." }
        catch PixPayloadError.invalidKey { errorMessage = "Confira a chave Pix e o limite de caracteres." }
        catch PixPayloadError.invalidName { errorMessage = "O nome é obrigatório e deve ter até 25 caracteres." }
        catch { errorMessage = "Confira os dados informados." }
    }

    private func reopen(_ draft: PixDraft) {
        name = draft.name; city = draft.city; key = draft.key; amount = draft.amount; payload = draft.payload; selectedTab = 1
    }

    private static func loadHistory() -> [PixDraft] {
        guard let data = UserDefaults.standard.data(forKey: "pix.history"), let items = try? JSONDecoder().decode([PixDraft].self, from: data) else { return [] }
        return items
    }

    private static func saveHistory(_ items: [PixDraft]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: "pix.history")
    }
}

struct QRCodeImage: View {
    let payload: String
    private var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().interpolation(.none) }
            else { ContentUnavailableView("QR indisponível", systemImage: "qrcode", description: Text("Gere novamente o código.")) }
        }
        .accessibilityLabel("QR Pix demonstrativo")
    }
}
