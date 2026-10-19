import SwiftUI

// MARK: - Pastas da tela inicial

/// O que o jogador pode fazer com as pastas; a tela inicial só avisa, quem altera a carreira é o `FootballHome`.
enum PhoneFolderAction {
    case create(app: String)
    case move(app: String, folder: String)
    case remove(app: String)
    case rename(folder: String, name: String)
    case dissolve(folder: String)
}

struct PhoneFolderRef: Identifiable {
    let id: String
}

/// Ícone quadrado de um app, nos tamanhos da grade e da pasta.
struct PhoneAppTile: View {
    let app: PhoneApp
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: app.symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [app.tint, app.tint.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Miniatura da pasta na grade: os quatro primeiros apps em um quadrado translúcido.
struct PhoneFolderTile: View {
    let apps: [PhoneApp]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.white.opacity(0.24))
            LazyVGrid(columns: [GridItem(.fixed(22), spacing: 4), GridItem(.fixed(22), spacing: 4)], spacing: 4) {
                ForEach(Array(apps.prefix(4))) { app in
                    Image(systemName: app.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(app.tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}

/// Conteúdo de uma pasta aberta: os apps dentro dela, o nome e as ações de tirar app ou desfazer a pasta.
struct PhoneFolderSheet: View {
    let career: FootballCareer
    let folderID: String
    let onOpen: (PhoneApp) -> Void
    let onAction: (PhoneFolderAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var didLoad = false

    private var folder: PhoneFolder? { career.world.phone.preferences.folder(folderID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let folder {
                    VStack(alignment: .leading, spacing: 18) {
                        TextField("Nome da pasta", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit { onAction(.rename(folder: folderID, name: name)) }
                            .accessibilityIdentifier("folder-name")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                            ForEach(folder.appIDs.compactMap { PhoneApp(rawValue: $0) }) { app in
                                VStack(spacing: 6) {
                                    Button {
                                        dismiss()
                                        onOpen(app)
                                    } label: {
                                        VStack(spacing: 4) {
                                            PhoneAppTile(app: app)
                                            Text(app.title).font(.caption2.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(app.title)
                                    .accessibilityIdentifier("folder-app-\(app.rawValue)")
                                    Button("Tirar") { onAction(.remove(app: app.rawValue)) }
                                        .font(.caption2.weight(.semibold))
                                        .accessibilityIdentifier("folder-remove-\(app.rawValue)")
                                }
                            }
                        }
                        Button("Desfazer a pasta", role: .destructive) {
                            onAction(.dissolve(folder: folderID))
                            dismiss()
                        }
                        .buttonStyle(FootballSecondaryButtonStyle())
                        .accessibilityIdentifier("folder-dissolve")
                    }
                    .padding(20)
                    .onAppear {
                        guard !didLoad else { return }
                        didLoad = true
                        name = folder.name
                    }
                }
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle(folder?.name ?? "Pasta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") {
                        if let folder, name != folder.name { onAction(.rename(folder: folderID, name: name)) }
                        dismiss()
                    }
                }
            }
            .onChange(of: folder == nil) { _, gone in if gone { dismiss() } }
        }
        .tint(FootballTheme.accent)
        .presentationDetents([.medium])
    }
}

// MARK: - Central de controle

/// Ajustes rápidos do celular: Foco, vibração, sons, tema, travar a tela e abrir Ajustes.
struct FootballControlCenterSheet: View {
    @Binding var career: FootballCareer
    let onLock: () -> Void
    let onOpenSettings: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var preferences: Binding<PhonePreferences> {
        Binding(get: { career.world.phone.preferences }, set: { career.world.phone.preferences = $0 })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Foco").font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(PhoneFocusMode.allCases) { mode in focusChip(mode) }
                        }
                        Text(preferences.wrappedValue.focusMode.summary + " Avisos urgentes, como a coletiva, passam sempre.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    Toggle("Vibração", isOn: Binding(get: { preferences.wrappedValue.hapticsOn },
                                                     set: { preferences.wrappedValue.hapticsEnabled = $0 ? nil : false }))
                        .accessibilityIdentifier("control-haptics")
                    Toggle("Sons", isOn: Binding(get: { preferences.wrappedValue.soundsOn },
                                                 set: { preferences.wrappedValue.soundEnabled = $0 ? nil : false }))
                        .accessibilityIdentifier("control-sounds")
                    Picker("Tema", selection: Binding(get: { preferences.wrappedValue.themeChoice },
                                                      set: { preferences.wrappedValue.theme = $0 == .system ? nil : $0 })) {
                        ForEach(PhoneThemeChoice.allCases) { choice in Text(choice.title).tag(choice) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("control-theme")
                    Divider()
                    HStack(spacing: 10) {
                        Button { dismiss(); onLock() } label: { Label("Bloquear tela", systemImage: "lock.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(FootballSecondaryButtonStyle())
                            .accessibilityIdentifier("control-lock")
                        Button { dismiss(); onOpenSettings() } label: { Label("Ajustes", systemImage: "gearshape.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(FootballSecondaryButtonStyle())
                            .accessibilityIdentifier("control-settings")
                    }
                }
                .padding(20)
            }
            .background(FactoryColor.canvas.ignoresSafeArea())
            .navigationTitle("Central de controle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
        }
        .tint(FootballTheme.accent)
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("control-center")
    }

    private func focusChip(_ mode: PhoneFocusMode) -> some View {
        let selected = preferences.wrappedValue.focusMode == mode
        return Button {
            preferences.wrappedValue.focus = mode == .none ? nil : mode
        } label: {
            Label(mode.title, systemImage: mode.symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? FootballTheme.accent : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Foco \(mode.title)" + (selected ? ", ativo" : ""))
        .accessibilityIdentifier("control-focus-\(mode.rawValue)")
    }
}
