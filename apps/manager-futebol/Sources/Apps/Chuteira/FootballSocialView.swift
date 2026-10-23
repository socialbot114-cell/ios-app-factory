import SwiftUI

// MARK: - Chuteira (rede social do futebol)

struct FootballSocialView: View {
    @Binding var career: FootballCareer
    let onAlert: (String) -> Void
    @State private var lastNote: String?
    var onOpenApp: (PhoneApp) -> Void = { _ in }

    private var social: SocialState { career.world.social }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FactoryMetric(label: social.verified ? "Seguidores · verificado" : "Seguidores", value: FootballFormat.compact(social.coachFollowers),
                              symbol: social.verified ? "checkmark.seal.fill" : "person.2.fill", tint: .pink)
                FactoryMetric(label: "Polêmica", value: "\(social.controversy)", symbol: "flame.fill", tint: social.controversy >= 60 ? .red : .orange)
            }
            SocialStoriesRow(stories: career.storyItems())
            Button { onOpenApp(.messages) } label: {
                Label("Mensagens diretas", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("social-open-messages")
            if let crisis = social.crisis { crisisPanel(crisis) }
            if let lastNote {
                Label(lastNote, systemImage: "bubble.left.fill").font(.subheadline.weight(.medium)).foregroundStyle(FootballTheme.accent)
            }
            FootballComposeDraftPanel(career: $career, onAlert: onAlert) { lastNote = $0 }
            brandPanel
            feedPanel
            FootballPublicSpherePanel(career: career)
        }
        .factoryPage()
        .navigationTitle("Chuteira")
    }

    // MARK: Crise

    private func crisisPanel(_ crisis: SocialCrisis) -> some View {
        FactoryPanel(title: "Crise de imagem", systemImage: "exclamationmark.triangle.fill") {
            Text(crisis.title).font(.subheadline.weight(.bold)).foregroundStyle(.red)
            Text(crisis.body).font(.subheadline)
            ForEach(CrisisResponse.allCases) { response in
                Button {
                    lastNote = career.resolveCrisis(response)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(response.title).font(.subheadline.weight(.bold))
                        Text(response.hint).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("crisis-\(response.rawValue)")
            }
        }
    }

    // MARK: Marcas

    private var brandPanel: some View {
        FactoryPanel(title: "Contratos de marca", systemImage: "tag.fill") {
            if social.brandDeals.isEmpty && social.brandOffers.isEmpty {
                Text("Marcas procuram perfis com pelo menos alguns mil seguidores. Publique e volte mais tarde.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(social.brandDeals) { deal in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(deal.brand).font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(deal.postsDone)/\(deal.postsRequired) publis").font(.caption.weight(.bold))
                    }
                    ProgressView(value: Double(deal.postsDone), total: Double(max(1, deal.postsRequired))).tint(.pink)
                    Text("\(FootballFormat.money(deal.payPerPost)) por publi · até a temporada \(deal.endSeason)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(social.brandOffers) { offer in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Proposta: \(offer.brand)").font(.subheadline.weight(.semibold))
                        Text("\(FootballFormat.money(offer.payPerPost)) por publi · \(offer.postsRequired) publis · mín. \(FootballFormat.compact(offer.minFollowers)) seguidores")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Aceitar") {
                        if !career.acceptBrandDeal(id: offer.id) { onAlert("Você já tem dois contratos de marca ativos.") }
                    }
                    .buttonStyle(.borderedProminent).font(.caption.weight(.bold))
                }
            }
        }
    }

    // MARK: Feed

    private var feedPanel: some View {
        FactoryPanel(title: "Linha do tempo", systemImage: "list.bullet.below.rectangle") {
            if social.posts.isEmpty {
                Text("O feed ganha vida a cada rodada. Jogue uma partida e volte.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(social.posts.prefix(25)) { post in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: icon(post.author)).foregroundStyle(post.isUser ? FootballTheme.accent : .secondary)
                        Text(post.name).font(.subheadline.weight(.bold))
                        Text(post.handle).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if post.viral { PillLabel(text: "VIRAL", systemImage: "flame.fill", tint: .red) }
                    }
                    Text(post.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    if let photo = post.shownPhoto { SocialPhotoView(photo: photo, seed: post.id) }
                    HStack(spacing: 16) {
                        Button { career.toggleLike(postID: post.id) } label: {
                            Label(FootballFormat.compact(post.likes), systemImage: career.hasLiked(post.id) ? "heart.fill" : "heart")
                                .foregroundStyle(career.hasLiked(post.id) ? Color.pink : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("like-\(post.id)")
                        Label(FootballFormat.compact(post.shares), systemImage: "arrow.2.squarepath")
                        Label(FootballFormat.compact(post.replies), systemImage: "bubble.left")
                        Spacer()
                        if post.author == .fan, post.tag != "#respondido" {
                            Button("Responder") { if career.replyToFan(postID: post.id) { lastNote = "Você respondeu \(post.name)." } }
                                .font(.caption.weight(.bold))
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    FootballPostThread(career: $career, post: post)
                }
                .accessibilityElement(children: .contain)
                if post.id != social.posts.prefix(25).last?.id { Divider() }
            }
        }
    }

    private func icon(_ author: SocialAuthor) -> String {
        switch author {
        case .fan: return "person.crop.circle.fill"
        case .journalist: return "newspaper.fill"
        case .player: return "figure.soccer"
        case .club: return "shield.fill"
        case .rival: return "flame.fill"
        case .coach: return "person.fill.checkmark"
        case .brand: return "tag.fill"
        case .pundit: return "tv.fill"
        }
    }
}
