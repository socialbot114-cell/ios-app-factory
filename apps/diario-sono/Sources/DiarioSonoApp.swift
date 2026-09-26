import SwiftUI

@main
struct DiarioSonoApp: App {
    var body: some Scene { WindowGroup { SleepDiaryHome() } }
}

struct SleepRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    var rating: Int
    var note: String

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date, rating: Int, note: String = "") {
        self.id = id; self.startedAt = startedAt; self.endedAt = endedAt; self.rating = min(max(rating, 1), 5); self.note = note
    }
}

struct SleepSessionEngine: Codable, Equatable {
    private(set) var activeStartedAt: Date?
    private(set) var records: [SleepRecord] = []

    mutating func start(at date: Date) {
        guard activeStartedAt == nil else { return }
        activeStartedAt = date
    }

    @discardableResult
    mutating func finish(at date: Date, rating: Int, note: String = "") -> Bool {
        guard let start = activeStartedAt, date > start else { return false }
        records.insert(SleepRecord(startedAt: start, endedAt: date, rating: rating, note: note), at: 0)
        activeStartedAt = nil
        return true
    }

    mutating func clear() { activeStartedAt = nil; records.removeAll() }
}

struct SleepDiaryHome: View {
    @State private var engine = SleepSessionEngine.load()
    @State private var rating = 4
    @State private var note = ""
    @State private var showingFinish = false
    @State private var showingDeleteConfirmation = false
    private let accent = Color(red: 0.53, green: 0.43, blue: 0.78)
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                FactoryHeader(eyebrow: "Diário pessoal", title: engine.activeStartedAt == nil ? "Desacelere." : "Sua sessão está ativa.", subtitle: "Registre horários e como você se sentiu. Este diário não mede fases do sono.", accent: accent)
                FactoryDemoNotice(message: "Registro manual · sem microfone · dados locais")
                if let started = engine.activeStartedAt {
                    activeSession(started: started)
                } else {
                    startCard
                }
                HStack(spacing: 12) {
                    FactoryMetric(label: "Sessões", value: "\(engine.records.count)", symbol: "moon.zzz.fill", tint: accent)
                    FactoryMetric(label: "Última avaliação", value: engine.records.first.map { "\($0.rating)/5" } ?? "—", symbol: "star.fill", tint: .orange)
                }
                if !engine.records.isEmpty { historyCard }
                FactoryPanel(title: "Seus dados", systemImage: "lock.shield.fill") {
                    Text("Os registros ficam neste aparelho. Use a lixeira para apagar todos os dados do diário.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .factoryPage()
            .navigationTitle("Diário do Sono").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Apagar registros do diário")
                }
            }
            .confirmationDialog("Apagar todos os registros deste aparelho?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Apagar registros", role: .destructive) { engine.clear(); engine.persist() }
                Button("Cancelar", role: .cancel) {}
            }
            .sheet(isPresented: $showingFinish) {
                FinishSleepSheet(rating: $rating, note: $note, onSave: finishSession)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: engine) { _, _ in engine.persist() }
            .onAppear {
                if capture == "active", engine.activeStartedAt == nil {
                    engine.start(at: .now.addingTimeInterval(-3_726))
                }
            }
        }
        .tint(accent)
    }

    private var startCard: some View {
        FactoryPanel {
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill").font(.system(size: 34)).foregroundStyle(accent)
                    .frame(width: 66, height: 66).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Quando estiver pronto").font(.headline)
                    Text("O registro começa quando você tocar no botão.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button { engine.start(at: .now) } label: { Label("Iniciar registro manual", systemImage: "moon.zzz.fill") }
                .buttonStyle(FactoryPrimaryButtonStyle())
        }
    }

    private func activeSession(started: Date) -> some View {
        FactoryPanel {
            Label("Sessão iniciada às \(started.formatted(date: .omitted, time: .shortened))", systemImage: "moon.zzz.fill")
                .font(.headline)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(Int(context.date.timeIntervalSince(started)), 0)
                Text(String(format: "%02d:%02d:%02d", elapsed / 3_600, (elapsed / 60) % 60, elapsed % 60))
                    .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(accent)
            }
            Text("O contador fica visível enquanto o app está aberto. A sessão é recuperável se o processo for encerrado.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Acordei — finalizar", systemImage: "sun.max.fill") { showingFinish = true }
                .buttonStyle(FactoryPrimaryButtonStyle()).tint(Color(red: 0.82, green: 0.56, blue: 0.25))
        }
    }

    private var historyCard: some View {
        FactoryPanel(title: "Histórico", systemImage: "calendar") {
            ForEach(engine.records.prefix(5)) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.startedAt.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                        Text("\(record.duration.formatted(.time(pattern: .hourMinute))) · avaliação pessoal \(record.rating)/5")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "star.fill").foregroundStyle(.orange)
                }
                if record.id != engine.records.prefix(5).last?.id { Divider() }
            }
        }
    }

    private func finishSession() {
        guard engine.finish(at: .now, rating: rating, note: note) else { return }
        rating = 4; note = ""
    }
}

struct FinishSleepSheet: View {
    @Binding var rating: Int
    @Binding var note: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Como você se sente?") {
                    Picker("Avaliação pessoal", selection: $rating) {
                        ForEach(1...5, id: \.self) { value in Text("\(value) de 5 estrelas").tag(value) }
                    }
                    .accessibilityLabel("Avaliação pessoal de sono")
                    TextField("Nota opcional", text: $note, axis: .vertical).lineLimit(2...5)
                }
                Section {
                    Text("A avaliação é um autorrelato e não uma medição clínica.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ao acordar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salvar") { onSave(); dismiss() } }
            }
        }
    }
}

extension SleepSessionEngine {
    static func load(defaults: UserDefaults = .standard) -> SleepSessionEngine {
        guard let data = defaults.data(forKey: "sleep.engine"), let value = try? JSONDecoder().decode(SleepSessionEngine.self, from: data) else { return SleepSessionEngine() }
        return value
    }

    func persist(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "sleep.engine")
    }
}
