import Observation
import SwiftUI
import UIKit

@main
struct CrimeIdleApp: App {
    var body: some Scene { WindowGroup { CrimeIdleRoot() } }
}

struct CrimeFloater: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let critical: Bool
    let drift: Double
}

enum CrimeHaptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func thud() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

@MainActor
@Observable
final class CrimeGameStore {
    static let saveKey = "crime.save.v2"

    var state: CrimeState
    var floaters: [CrimeFloater] = []
    var offlineReport: CrimeOfflineReport?
    var heistOutcome: CrimeHeistOutcome?
    var toast: String?
    var rankUp: Int?
    var showDaily = false
    var dailyClaim: CrimeDailyClaim?
    var soundOn = CrimeSound.isEnabled
    var eventsEnabled = true
    var dailyEnabled = true
    var persists = true

    @ObservationIgnored private var knownRank: Int
    @ObservationIgnored private var lastTick = Date()
    @ObservationIgnored private var lastSave = Date()
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(state: CrimeState) {
        self.state = state
        knownRank = state.rankIndex
    }

    static func loadSaved(defaults: UserDefaults = .standard) -> CrimeState {
        guard let data = defaults.data(forKey: saveKey),
              let state = try? JSONDecoder().decode(CrimeState.self, from: data) else { return CrimeState(seed: UInt64.random(in: 1...UInt64.max)) }
        return state
    }

    func save() {
        guard persists, let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.saveKey)
        lastSave = Date()
    }

    // MARK: - Relógio

    func resume(now: Date = Date()) {
        if let report = state.resume(at: now), persists { offlineReport = report }
        lastTick = now
        CrimeNotifications.clear()
        offerDailyIfReady(now: now)
        save()
    }

    func enterBackground() {
        save()
        CrimeNotifications.schedule(for: state)
    }

    /// Tutorial, patente e envelope reagem ao estado; checado a cada tick.
    private func checkProgress() {
        if state.tutorial != .done {
            let before = state.tutorial
            if state.advanceTutorial() {
                CrimeSound.levelup.play()
                CrimeHaptics.success()
                show("Tutorial concluído! +\(Int(CrimeState.tutorialRewardRespect)) de respeito para recrutar a família")
                offerDailyIfReady()
            } else if state.tutorial != before {
                CrimeSound.buy.play()
            }
        }
        let rank = state.rankIndex
        if rank > knownRank {
            knownRank = rank
            CrimeSound.levelup.play()
            CrimeHaptics.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { rankUp = rank }
        }
    }

    private func offerDailyIfReady(now: Date = Date()) {
        guard dailyEnabled, state.tutorial == .done, state.isDailyAvailable(today: CrimeState.dayNumber(now)) else { return }
        dailyClaim = nil
        showDaily = true
    }

    func openDaily() {
        dailyClaim = nil
        showDaily = true
    }

    func claimDaily() {
        guard let claim = state.claimDaily(today: CrimeState.dayNumber(Date())) else { return }
        CrimeSound.crit.play()
        CrimeHaptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dailyClaim = claim }
        save()
    }

    func skipTutorial() {
        state.skipTutorial()
        CrimeSound.click.play()
        offerDailyIfReady()
    }

    func toggleSound() {
        soundOn.toggle()
        CrimeSound.isEnabled = soundOn
        CrimeSound.click.play()
    }

    func tick(now: Date = Date()) {
        let elapsed = min(max(now.timeIntervalSince(lastTick), 0), 1)
        lastTick = now
        state.tick(elapsed, online: eventsEnabled)
        state.lastSeen = now
        checkProgress()
        if now.timeIntervalSince(lastSave) > 5 { save() }
    }

    func runLoop() async {
        lastTick = Date()
        while !Task.isCancelled {
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            tick()
        }
    }

    // MARK: - Ações do jogador

    func tapStreet() {
        let result = state.tapStreet()
        let floater = CrimeFloater(text: (result.critical ? "BOLADA! +" : "+") + CrimeFormat.cash(result.amount),
                                   critical: result.critical, drift: Double.random(in: -70...70))
        floaters.append(floater)
        if floaters.count > 14 { floaters.removeFirst(floaters.count - 14) }
        if result.critical { CrimeHaptics.thud(); CrimeSound.crit.play() } else { CrimeHaptics.tap(); CrimeSound.tap.play() }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_100))
            self?.floaters.removeAll { $0.id == floater.id }
        }
    }

    func buy(_ index: Int, mode: CrimeBuyMode) {
        let quantity = state.quantity(for: mode, racket: index)
        let before = state.owned[index]
        guard state.buy(racket: index, quantity: quantity) else { return CrimeHaptics.failure() }
        CrimeHaptics.tap()
        CrimeSound.buy.play()
        if let milestone = CrimeRacket.nextMilestone(after: before), state.owned[index] >= milestone.count {
            show("\(CrimeRacket.catalog[index].name): \(milestone.label)!")
            CrimeHaptics.success()
        }
    }

    func run(_ index: Int) {
        if state.run(racket: index) { CrimeHaptics.tap(); CrimeSound.click.play() }
    }

    func hire(_ index: Int) {
        guard state.hireManager(index) else { return CrimeHaptics.failure() }
        CrimeHaptics.success()
        CrimeSound.success.play()
        show("\(CrimeRacket.catalog[index].managerName) agora toca o \(CrimeRacket.catalog[index].name)")
    }

    func buyUpgrade(_ id: Int) {
        guard state.buyUpgrade(id), let upgrade = CrimeUpgrade.catalog.first(where: { $0.id == id }) else { return CrimeHaptics.failure() }
        CrimeHaptics.success()
        CrimeSound.buy.play()
        show("\(upgrade.name): \(upgrade.detail)")
    }

    func bribe() {
        guard state.bribe() else { return CrimeHaptics.failure() }
        CrimeHaptics.success()
        CrimeSound.crit.play()
        show("O delegado olhou para o outro lado")
    }

    func upgradeCrew(_ id: Int) {
        let wasRecruited = state.crewLevels[id] > 0
        guard state.upgradeCrew(id) else { return CrimeHaptics.failure() }
        CrimeHaptics.success()
        CrimeSound.success.play()
        let member = CrimeCrewMember.catalog[id]
        show(wasRecruited ? "\(member.name) subiu para o nível \(state.crewLevels[id])" : "\(member.name) entrou para a família")
    }

    func conquer(_ id: Int) {
        guard state.conquer(id) else { return CrimeHaptics.failure() }
        CrimeHaptics.success()
        CrimeSound.levelup.play()
        show("\(CrimeDistrict.catalog[id].name) agora é seu")
    }

    func startHeist(_ id: Int, plan: CrimeHeistPlan) {
        guard state.startHeist(id, plan: plan) else { return CrimeHaptics.failure() }
        CrimeHaptics.thud()
        CrimeSound.click.play()
        if state.heistsStarted == 1 { CrimeNotifications.requestPermission() }
    }

    func revealHeist() {
        guard let outcome = state.resolveHeist() else { return }
        if outcome.success { CrimeHaptics.success(); CrimeSound.success.play() } else { CrimeHaptics.failure(); CrimeSound.fail.play() }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { heistOutcome = outcome }
        save()
    }

    func choose(_ choice: Int) {
        guard state.choose(choice) else { return CrimeHaptics.failure() }
        CrimeHaptics.tap()
        CrimeSound.click.play()
    }

    func claimContract(_ id: Int) {
        guard state.claimContract(id) else { return }
        CrimeHaptics.success()
        CrimeSound.crit.play()
        show("Contrato cumprido")
    }

    func prestige() {
        let gained = state.claimableLegacy
        guard state.prestige() else { return CrimeHaptics.failure() }
        CrimeHaptics.success()
        CrimeSound.levelup.play()
        knownRank = state.rankIndex
        save()
        show("Nova identidade: +\(CrimeFormat.short(gained)) de lenda")
    }

    func resetEverything() {
        state = CrimeState(seed: UInt64.random(in: 1...UInt64.max))
        floaters = []
        knownRank = state.rankIndex
        save()
        show("Uma nova história começa")
    }

    func show(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.35)) { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { self?.toast = nil }
        }
    }
}

enum CrimeTab: Int, CaseIterable, Identifiable {
    case home, rackets, heists, crew, map

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Império"
        case .rackets: return "Negócios"
        case .heists: return "Golpes"
        case .crew: return "Família"
        case .map: return "Mapa"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "building.2.crop.circle.fill"
        case .rackets: return "briefcase.fill"
        case .heists: return "bolt.shield.fill"
        case .crew: return "person.3.fill"
        case .map: return "map.fill"
        }
    }

    init(capture: String?) {
        switch capture {
        case "operations": self = .rackets
        case "heists": self = .heists
        case "crew": self = .crew
        case "territory": self = .map
        default: self = .home
        }
    }
}

struct CrimeIdleRoot: View {
    @State private var store: CrimeGameStore
    @State private var tab: CrimeTab
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store: CrimeGameStore
        if FactoryCapture.isUITesting {
            FactoryCapture.resetAppDefaults()
            store = CrimeGameStore(state: CrimeState(seed: 7))
            store.eventsEnabled = false
            store.dailyEnabled = false
        } else if let screen = FactoryCapture.screen {
            store = CrimeGameStore(state: .capturePreview(screen: screen))
            store.eventsEnabled = false
            store.dailyEnabled = false
            store.persists = false
            if screen == "daily" { store.showDaily = true }
            if screen == "rankup" { store.rankUp = store.state.rankIndex }
        } else {
            store = CrimeGameStore(state: CrimeGameStore.loadSaved())
        }
        _store = State(initialValue: store)
        _tab = State(initialValue: CrimeTab(capture: FactoryCapture.screen))
    }

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
            switch tab {
            case .home: CrimeHomeView(store: store, openTab: { tab = $0 })
            case .rackets: CrimeRacketsView(store: store)
            case .heists: CrimeHeistsView(store: store)
            case .crew: CrimeCrewView(store: store)
            case .map: CrimeMapView(store: store)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if store.state.tutorial != .done {
                    CrimeCoachCard(step: store.state.tutorial, isOnTargetTab: tab == tutorialTab,
                                   go: { withAnimation(.snappy) { tab = tutorialTab } },
                                   skip: { store.skipTutorial() })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                tabBar
            }
            .animation(.spring(response: 0.4), value: store.state.tutorial)
        }
        .overlay(alignment: .top) { toastView }
        .overlay {
            if let outcome = store.heistOutcome {
                CrimeHeistOutcomeView(outcome: outcome) {
                    withAnimation(.easeOut(duration: 0.25)) { store.heistOutcome = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if let rank = store.rankUp {
                CrimeRankUpView(rankIndex: rank) {
                    withAnimation(.easeOut(duration: 0.25)) { store.rankUp = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if store.showDaily && store.offlineReport == nil {
                CrimeDailyView(store: store) {
                    withAnimation(.easeOut(duration: 0.25)) { store.showDaily = false }
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: Binding(get: { store.offlineReport != nil }, set: { if !$0 { store.offlineReport = nil } })) {
            if let report = store.offlineReport {
                CrimeOfflineSheet(report: report) { store.offlineReport = nil }
                    .presentationDetents([.medium])
                    .presentationBackground(Noir.night)
            }
        }
        .tint(Noir.gold)
        .preferredColorScheme(.dark)
        .task {
            store.resume()
            await store.runLoop()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: store.resume()
            case .background: store.enterBackground()
            case .inactive: store.save()
            @unknown default: break
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(CrimeTab.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.22)) { tab = item }
                    CrimeHaptics.tap()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.system(size: 18, weight: .semibold))
                        Text(item.title).font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(tab == item ? Noir.gold : Noir.muted)
                    .background {
                        if tab == item {
                            Capsule().fill(Noir.gold.opacity(0.14))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if hasBadge(item) {
                            Circle().fill(Noir.neon).frame(width: 9, height: 9).offset(x: -14, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityValue(tab == item ? "Selecionado" : "")
                .accessibilityIdentifier("tab-\(item.title)")
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .simultaneousGesture(TapGesture().onEnded { CrimeSound.click.play() })
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: 620)
    }

    private var tutorialTab: CrimeTab {
        switch store.state.tutorial {
        case .tapStreet, .done: return .home
        case .buyRacket, .runRacket, .growRacket, .hireManager: return .rackets
        case .firstHeist: return .heists
        }
    }

    private func hasBadge(_ item: CrimeTab) -> Bool {
        if store.state.tutorial != .done { return item == tutorialTab && tab != item }
        let state = store.state
        switch item {
        case .home: return state.pendingEvent != nil || state.openContracts.contains { state.canClaimContract($0.id) }
        case .rackets: return CrimeRacket.catalog.contains { state.canHireManager($0.id) }
        case .heists: return state.activeHeist?.isReady == true
        case .crew: return CrimeCrewMember.catalog.contains { state.crewLevels[$0.id] == 0 && state.canUpgradeCrew($0.id) }
        case .map: return state.canConquer(state.districts) || state.canPrestige
        }
    }

    @ViewBuilder private var toastView: some View {
        if let toast = store.toast {
            Text(toast)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Noir.raised, in: Capsule())
                .overlay(Capsule().strokeBorder(Noir.gold.opacity(0.5)))
                .shadow(color: Noir.gold.opacity(0.25), radius: 14)
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("toast")
        }
    }
}

struct CrimeOfflineSheet: View {
    let report: CrimeOfflineReport
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 46))
                .foregroundStyle(Noir.gold)
                .padding(.top, 26)
            Text("Enquanto você estava fora…")
                .font(.title3.weight(.bold))
            Text("Seus gerentes trabalharam por \(CrimeFormat.duration(report.seconds)).")
                .foregroundStyle(Noir.muted)
            Text("+" + CrimeFormat.cash(report.cash))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Noir.money)
            Button("Recolher a grana", action: dismiss)
                .buttonStyle(NoirButtonStyle(tint: Noir.gold))
                .padding(.horizontal, 30)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}

extension CrimeState {
    /// Estados determinísticos para capturas de revisão no simulador.
    static func capturePreview(screen: String) -> CrimeState {
        var state = CrimeState(seed: 2026, now: Date())
        state.cash = 1e13
        state.respect = 400
        state.conquer(1)
        state.conquer(2)
        for (index, count) in [(0, 180), (1, 120), (2, 90), (3, 60), (4, 30), (5, 12)] {
            state.buy(racket: index, quantity: count)
        }
        for index in 0..<5 { state.hireManager(index) }
        for upgrade in [0, 1, 2, 3, 4] { state.buyUpgrade(upgrade) }
        for (member, level) in [(0, 6), (1, 4), (2, 3), (3, 2), (4, 1)] {
            for _ in 0..<level { state.upgradeCrew(member) }
        }
        state.cash = 3.42e9
        state.respect = 38
        state.heat = 47
        state.lifetimeTotal = 7.9e10
        state.lifetimeRun = 7.9e10
        state.heistsCompleted = 9
        state.claimedContracts = [0, 1, 2, 3, 4, 5]
        state.progress = [0.4, 1.6, 2.2, 7.1, 9.5, 41, 0, 0, 0, 0]
        state.tutorial = .done
        state.dailyStreak = 4
        state.lastDailyDay = CrimeState.dayNumber(Date()) - (screen == "daily" ? 1 : 0)
        if screen == "home" { state.pendingEvent = 1 }
        if screen == "heists" || screen == "home" {
            state.startHeist(3, plan: .standard)
            state.activeHeist?.remaining = 480
        }
        return state
    }
}
