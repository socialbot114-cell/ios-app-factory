import Foundation

// MARK: - Patrocinadores que aparecem no estádio e na transmissão

/// Um patrocinador contratado e o lugar onde ele aparece. Marcas fictícias, as mesmas dos contratos.
struct VisibleSponsor: Identifiable, Equatable {
    let role: String
    let name: String

    var id: String { role }
}

extension FootballCareer {
    /// Contratos ativos, na ordem em que o torcedor os vê: camisa, depois os espaços vendidos e o nome do estádio.
    var visibleSponsors: [VisibleSponsor] {
        var list: [VisibleSponsor] = []
        if let deal = sponsorDeal { list.append(VisibleSponsor(role: "Camisa", name: deal.sponsor)) }
        for deal in world.growth.slotDeals { list.append(VisibleSponsor(role: deal.slot.title, name: deal.sponsor)) }
        if let naming = world.business.naming { list.append(VisibleSponsor(role: "Nome do estádio", name: naming.sponsor)) }
        return list
    }

    /// Matiz estável (0 a 359) para a cor da marca nas placas: o mesmo nome dá sempre a mesma cor.
    static func brandHue(of name: String) -> Int {
        name.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 360 }
    }
}
