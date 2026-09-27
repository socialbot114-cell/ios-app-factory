import SwiftUI

// MARK: - Ajustes: exportação, iCloud, experiência, dados

struct AtelierSettingsView: View {
    @ObservedObject var store: AtelierStore
    @AppStorage("atelier.exportScale") private var exportScale = 2
    @AppStorage("atelier.exportFormat") private var exportFormat = "png"
    @AppStorage("atelier.exportBackground") private var exportBackground = "white"
    @AppStorage("atelier.saveToPhotos") private var saveToPhotos = false
    @AppStorage("atelier.haptics") private var haptics = true
    @AppStorage("atelier.icloud") private var iCloudEnabled = false
    @State private var showEraseGate = false
    @State private var iCloudError = false
    private let accent = Color(red: 0.86, green: 0.30, blue: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FactoryHeader(
                eyebrow: "Do seu jeito",
                title: "Ajustes",
                subtitle: "Exportação, sincronização e seus dados — tudo local por padrão.",
                accent: accent
            )

            FactoryPanel(title: "Exportação", systemImage: "photo.artframe") {
                Picker("Qualidade", selection: $exportScale) {
                    Text("Padrão (900px)").tag(1)
                    Text("Alta (1800px)").tag(2)
                    Text("Máxima (2700px)").tag(3)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Qualidade de exportação")
                Picker("Formato", selection: $exportFormat) {
                    Text("PNG").tag("png")
                    Text("JPEG").tag("jpeg")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Formato de exportação")
                Picker("Fundo", selection: $exportBackground) {
                    Text("Branco").tag("white")
                    Text("Transparente (PNG)").tag("transparent")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Fundo da exportação")
                if exportBackground == "transparent" && exportFormat == "jpeg" {
                    Text("JPEG não tem transparência: o fundo sai branco.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle(isOn: $saveToPhotos) {
                    Text("Salvar também em Fotos")
                        .font(.subheadline)
                }
            }

            FactoryPanel(title: "Sincronização", systemImage: "icloud.fill") {
                Toggle(isOn: $iCloudEnabled) {
                    Text("iCloud Drive (beta)")
                        .font(.subheadline)
                }
                .onChange(of: iCloudEnabled) { _, new in
                    if new && !AtelierStore.iCloudAvailable() {
                        iCloudEnabled = false
                        iCloudError = true
                    } else if !store.setiCloudEnabled(new) {
                        iCloudEnabled = false
                        iCloudError = true
                    }
                }
                .alert("iCloud indisponível", isPresented: $iCloudError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Entre com sua conta Apple e ative o iCloud Drive para sincronizar as obras entre aparelhos.")
                }
                Text("Desligado por padrão. Ao ligar, o arquivo de obras muda para o iCloud Drive.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FactoryPanel(title: "Experiência", systemImage: "hand.tap.fill") {
                Toggle(isOn: $haptics) {
                    Text("Vibração ao pintar")
                        .font(.subheadline)
                }
                Button("Apagar cores recentes") {
                    UserDefaults.standard.removeObject(forKey: "atelier.recents")
                }
                .font(.subheadline)
            }

            FactoryPanel(title: "Seus dados", systemImage: "internaldrive.fill") {
                Text("\(store.instances.count) obras · \(store.completedCount) com cor · \(store.totalMinutes) min pintando")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Apagar todas as obras", systemImage: "trash", role: .destructive) {
                    showEraseGate = true
                }
                .font(.subheadline.weight(.semibold))
                .sheet(isPresented: $showEraseGate) {
                    AtelierParentalGate(
                        onCancel: { showEraseGate = false },
                        onConfirm: {
                            store.deleteAll()
                            showEraseGate = false
                        }
                    )
                }
            }

            FactoryPanel(title: "Sobre", systemImage: "info.circle.fill") {
                Text("Ateliê de Colorir · 12 artes autorais em 6 categorias. Toque-para-preencher, pensado para crianças e para quem quer desacelerar. Nenhuma conta, nenhuma rede: sua arte nunca sai do aparelho sem você mandar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .factoryPage(backgroundColor: Color(red: 1.0, green: 0.976, blue: 0.94))
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Portão parental: conta simples antes de apagar tudo

struct AtelierParentalGate: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void
    @State private var answer = ""
    @State private var a = Int.random(in: 3...9)
    @State private var b = Int.random(in: 3...9)
    @State private var wrong = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                Text("Só um adulto pode fazer isso")
                    .font(.headline)
                Text("Quanto é \(a) + \(b)?")
                    .font(.title2.bold())
                TextField("Resposta", text: $answer)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                if wrong {
                    Text("Tente de novo.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Apagar todas as obras", role: .destructive) {
                    if Int(answer.trimmingCharacters(in: .whitespaces)) == a + b {
                        onConfirm()
                    } else {
                        wrong = true
                    }
                }
                .buttonStyle(FactoryPrimaryButtonStyle())
                Button("Cancelar", role: .cancel) { onCancel() }
            }
            .padding(24)
            .navigationTitle("Confirmar")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
