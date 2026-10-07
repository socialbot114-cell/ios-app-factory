import Foundation
import XCTest
@testable import ManagerFutebol

final class FootballMarketListTests: XCTestCase {
    /// Atleta com os campos usados pela busca, pela ordenação e pela paginação.
    private func athlete(_ id: Int, name: String, overall: Int, potential: Int? = nil, age: Int = 25,
                         value: Int = 1_000_000, endSeason: Int = 2028) -> FootballPlayer {
        var player = FootballPlayer(id: id, name: name, position: .midfielder, age: age, overall: overall,
                                    potential: potential ?? overall, condition: 90, marketValue: value, teamID: nil)
        player.contract.endSeason = endSeason
        return player
    }

    /// Setenta e cinco atletas com geral decrescente: o Jogador 1 é o melhor.
    private func longList() -> [FootballPlayer] {
        (1...75).map { athlete($0, name: "Jogador \($0)", overall: 100 - $0) }
    }

    private func names(_ players: [FootballPlayer]) -> [String] {
        players.map(\.name)
    }

    // MARK: Busca

    func testBuscaIgnoraAcentoEMaiuscula() {
        let players = [
            athlete(1, name: "João Silva", overall: 70),
            athlete(2, name: "Zé Ademir", overall: 68),
            athlete(3, name: "Carlos Eduardo", overall: 65),
        ]
        var list = FootballMarketList()

        list.query = "JOAO"
        XCTAssertEqual(names(list.page(of: players).players), ["João Silva"], "Maiúscula sem acento acha João")
        XCTAssertEqual(list.page(of: players).total, 1)

        list.query = "joão"
        XCTAssertEqual(names(list.page(of: players).players), ["João Silva"], "Acento na busca também acha João")

        list.query = "ZÉ"
        XCTAssertEqual(names(list.page(of: players).players), ["Zé Ademir"], "Zé acha pelo nome sem acento")

        list.query = "eduardo carlos"
        XCTAssertEqual(names(list.page(of: players).players), ["Carlos Eduardo"], "Cada palavra pode vir em qualquer ordem")

        list.query = "   "
        XCTAssertEqual(list.page(of: players).total, 3, "Espaços sozinhos não filtram nada")
        XCTAssertFalse(list.isSearching)

        list.query = "xyz"
        XCTAssertEqual(list.page(of: players).total, 0, "Nome inexistente não acha ninguém")
        XCTAssertTrue(list.isSearching)

        XCTAssertEqual(FootballMarketList.normalized("  Ação   Fácil "), "acao facil")
    }

    // MARK: Ordenação

    func testCadaOrdenacaoTemSuaDirecao() {
        // Alberto: geral 70, potencial 88, 30 anos, valor 20 mi, contrato até 2028.
        // Bruno: geral 80, potencial 84, 22 anos, valor 2 mi, contrato até 2027.
        // Caio: geral 75, potencial 90, 28 anos, valor 10 mi, sem contrato (zero).
        // Diego: geral 60, potencial 85, 19 anos, valor 1 mi, contrato até 2026.
        let players = [
            athlete(1, name: "Alberto", overall: 70, potential: 88, age: 30, value: 20_000_000, endSeason: 2028),
            athlete(2, name: "Bruno", overall: 80, potential: 84, age: 22, value: 2_000_000, endSeason: 2027),
            athlete(3, name: "Caio", overall: 75, potential: 90, age: 28, value: 10_000_000, endSeason: 0),
            athlete(4, name: "Diego", overall: 60, potential: 85, age: 19, value: 1_000_000, endSeason: 2026),
        ]
        let expected: [(FootballMarketSort, [String])] = [
            (.overall, ["Bruno", "Caio", "Alberto", "Diego"]),
            (.potential, ["Caio", "Alberto", "Diego", "Bruno"]),
            (.age, ["Diego", "Bruno", "Caio", "Alberto"]),
            (.value, ["Alberto", "Caio", "Bruno", "Diego"]),
            (.contractEnd, ["Diego", "Bruno", "Alberto", "Caio"]),
        ]
        for (sort, order) in expected {
            var list = FootballMarketList()
            list.sort = sort
            XCTAssertEqual(names(list.page(of: players).players), order, "Ordenação \(sort.rawValue)")
        }
    }

    func testEmpateDeGeralDesempataPorNome() {
        let players = [
            athlete(1, name: "Zeca", overall: 70),
            athlete(2, name: "Ana", overall: 70),
        ]
        var list = FootballMarketList()
        XCTAssertEqual(names(list.page(of: players).players), ["Ana", "Zeca"], "Empate de geral sai por nome")
        list.sort = .age
        XCTAssertEqual(names(list.page(of: players).players), ["Ana", "Zeca"], "Empate de idade também sai por nome")
    }

    // MARK: Paginação

    func testPrimeiraPaginaTemTrintaAtletas() {
        let page = FootballMarketList().page(of: longList())

        XCTAssertEqual(page.players.count, FootballMarketList.pageSize)
        XCTAssertEqual(FootballMarketList.pageSize, 30)
        XCTAssertEqual(page.total, 75)
        XCTAssertEqual(page.remaining, 45)
        XCTAssertEqual(page.players.first?.id, 1)
        XCTAssertEqual(page.players.last?.id, 30)
    }

    func testListaCurtaMostraTudoSemRestante() {
        let page = FootballMarketList().page(of: Array(longList().prefix(12)))

        XCTAssertEqual(page.players.count, 12)
        XCTAssertEqual(page.remaining, 0, "Sem restante, o botão Mostrar mais some")
    }

    func testMostrarMaisSomaTrintaETerminaNoFim() {
        let all = longList()
        var list = FootballMarketList()

        list.showMore()
        var page = list.page(of: all)
        XCTAssertEqual(page.players.count, 60)
        XCTAssertEqual(page.remaining, 15)

        list.showMore()
        page = list.page(of: all)
        XCTAssertEqual(page.players.count, 75, "Último lote traz o que sobrou")
        XCTAssertEqual(page.remaining, 0)
        XCTAssertEqual(page.players.last?.id, 75)

        list.showMore()
        XCTAssertEqual(list.page(of: all).players.count, 75, "Passar do fim não repete atletas")
    }

    func testBuscaOuOrdenacaoVoltaParaPrimeiraPagina() {
        let all = longList()
        var list = FootballMarketList()

        list.showMore()
        XCTAssertEqual(list.limit, 60)
        list.query = "jogador"
        XCTAssertEqual(list.limit, 30, "Mudar a busca volta para a primeira página")

        list.showMore()
        list.sort = .age
        XCTAssertEqual(list.limit, 30, "Mudar a ordenação volta para a primeira página")

        list.showMore()
        list.query = "jogador"
        XCTAssertEqual(list.limit, 60, "Repetir o mesmo texto não volta à primeira página")

        list.resetPage()
        XCTAssertEqual(list.page(of: all).players.count, 30, "Reset manual volta para a primeira página")
    }
}
