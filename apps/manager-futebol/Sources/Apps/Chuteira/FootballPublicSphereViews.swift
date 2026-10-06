import SwiftUI

/// Nova publicação com assunto, alvo e prévia do que vai acontecer.
struct FootballComposeDraftPanel: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    let onNote: (String) -> Void

    @State private var tone: PostTone = .motivational
    @State private var subjectKind = 0
    @State private var playerID: Int?
    @State private var rivalID = 1
    @State private var journalistID: String?
    @State private var photo: SocialPhoto?

    private var subject: PostSubject {
        switch subjectKind {
        case 1: return .player(playerID ?? career.clubRoster.first?.id ?? 0)
        case 2: return .rival(rivalID)
        case 3: return .journalist(journalistID ?? career.profiles.first { $0.kind == .journalist }?.id ?? "")
        default: return .team
        }
    }

    var body: some View {
        let draft = PostDraft(tone: tone, subject: subject, photo: photo)
        let preview = career.previewPost(draft)
        FactoryPanel(title: "Nova publicação", systemImage: "square.and.pencil") {
            Text("Uma publicação por dia de jogo. Escolha o assunto, o alvo e o tom; a prévia mostra o texto, o alcance e os efeitos antes de publicar.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Assunto", selection: $subjectKind) {
                Text("Time").tag(0)
                Text("Atleta").tag(1)
                Text("Rival").tag(2)
                Text("Imprensa").tag(3)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("post-subject")
            switch subjectKind {
            case 1:
                Picker("Atleta", selection: Binding(get: { playerID ?? career.clubRoster.first?.id ?? 0 }, set: { playerID = $0 })) {
                    ForEach(career.clubRoster.sorted { $0.overall > $1.overall }.prefix(12)) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
            case 2:
                Picker("Rival", selection: $rivalID) {
                    ForEach(FootballSeason.teams.filter { $0.id != career.selectedClubID }) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
            case 3:
                Picker("Jornalista", selection: Binding(get: { journalistID ?? career.profiles.first { $0.kind == .journalist }?.id ?? "" }, set: { journalistID = $0 })) {
                    ForEach(career.profiles.filter { $0.kind == .journalist }) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
            default:
                EmptyView()
            }
            Picker("Tom", selection: $tone) {
                ForEach(PostTone.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("post-tone")
            Text(tone.summary).font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Foto (+15% de curtidas)").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        photoChip(nil)
                        ForEach(SocialPhoto.allCases) { photoChip($0) }
                    }
                }
                if let photo { SocialPhotoView(photo: photo, seed: career.worldDay, height: 130) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Prévia").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                Text("“\(preview.text)”").font(.subheadline)
                Label("Alcance \(FootballFormat.compact(preview.reachLow))–\(FootballFormat.compact(preview.reachHigh)) · risco de polêmica \(preview.risk)", systemImage: "chart.bar.fill")
                    .font(.caption)
                ForEach(preview.effects, id: \.self) { Label($0, systemImage: "arrow.right.circle").font(.caption).foregroundStyle(.secondary) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("post-preview")
            Button {
                if let post = career.publishPost(draft: draft) {
                    onNote(post.viral ? "Sua publicação viralizou! O resto do engajamento chega nos próximos dias." : "Publicado. O engajamento completo chega nos próximos dias.")
                } else {
                    onAlert(preview.blocked ?? "Não foi possível publicar agora.")
                }
            } label: {
                Label("Publicar", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(preview.blocked != nil)
            .accessibilityIdentifier("post-publish")
            if let blocked = preview.blocked { Text(blocked).font(.caption).foregroundStyle(.orange) }
        }
        .onAppear { career.ensureProfiles() }
    }

    private func photoChip(_ option: SocialPhoto?) -> some View {
        Button { photo = option } label: {
            Label(option?.title ?? "Sem foto", systemImage: option?.symbol ?? "text.alignleft")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(photo == option ? FootballTheme.accent.opacity(0.25) : Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("post-photo-\(option?.rawValue ?? "none")")
    }
}

/// Fonte, etapa do engajamento e comentários de uma publicação, com resposta do treinador.
struct FootballPostThread: View {
    @Binding var career: FootballCareer
    let post: SocialPost

    var body: some View {
        let source = career.postSource(post)
        let replies = career.replies(for: post.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(source.label).font(.caption2.weight(.semibold)).foregroundStyle(source.reliability == "rumor" ? Color.orange : (source.reliability == "denied" ? Color.red : Color.secondary))
                if post.isUser, let stage = post.stage, stage < 2 {
                    Text("· engajamento \(stage == 0 ? "inicial" : "parcial"), cresce nos próximos dias").font(.caption2).foregroundStyle(.secondary)
                }
            }
            ForEach(replies) { reply in
                VStack(alignment: .leading, spacing: 3) {
                    Label("\(reply.name): \(reply.text)", systemImage: reply.sentiment < 0 ? "bubble.left.fill" : "bubble.left")
                        .font(.caption)
                        .foregroundStyle(reply.sentiment < 0 ? Color.red : Color.primary)
                    if let answer = reply.answer {
                        Text(answer == "firm" ? "Você rebateu." : "Você respondeu com calma.").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 8) {
                            Button("Responder com calma") { career.answerReply(reply.id, firm: false) }
                                .accessibilityIdentifier("reply-calm-\(reply.id)")
                            Button("Rebater") { career.answerReply(reply.id, firm: true) }
                                .accessibilityIdentifier("reply-firm-\(reply.id)")
                        }
                        .font(.caption2.weight(.bold))
                    }
                }
                .padding(.leading, 10)
            }
        }
    }
}

/// Quem está na conversa pública e o que ela lembra do treinador.
struct FootballPublicSpherePanel: View {
    let career: FootballCareer

    var body: some View {
        FactoryPanel(title: "Quem fala de você", systemImage: "person.2.wave.2.fill") {
            let voices = career.profiles.filter { $0.kind == .journalist || $0.kind == .pundit || $0.kind == .fans }
            if voices.isEmpty { Text("Os perfis aparecem depois da primeira rodada.").font(.caption).foregroundStyle(.secondary) }
            ForEach(voices.prefix(8)) { profile in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.name).font(.subheadline.weight(.semibold))
                        Text(profile.bio).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Credibilidade \(profile.credibility)").font(.caption2)
                        Text("Postura \(profile.stance >= 0 ? "+" : "")\(profile.stance)").font(.caption2.weight(.bold))
                            .foregroundStyle(profile.stance >= 10 ? Color.green : (profile.stance <= -10 ? Color.red : Color.secondary))
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if !career.publicMemory.isEmpty {
                Divider()
                Text("A memória pública").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                ForEach(career.publicMemory.suffix(5).reversed()) { entry in
                    Label("Dia \(entry.worldDay + 1): \(entry.text)", systemImage: entry.kind == .praise ? "hand.thumbsup.fill" : "exclamationmark.bubble.fill")
                        .font(.caption)
                }
                Text("Posts polêmicos antigos podem voltar numa crise de imagem.").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("public-sphere")
    }
}
