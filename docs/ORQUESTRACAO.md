# Orquestração das sessões — manager-futebol

Fonte única de verdade sobre quem faz o quê. Mantida pela sessão **6a** (orquestradora). Branch: `manager-futebol/phases-2-7`.

## Quadro de fatias

| Sessão | Fatia | Arquivos que pode alterar | Fora do alcance |
|---|---|---|---|
| **6a** (orquestra) | Jogo ao vivo, pós-jogo, F1 (fatos/compromissos), F2, F3 (memória/negociação), integração, prints e TestFlight | `Core/FootballLive*`, `FootballMatchImpact`, `FootballPitchEngine`, `FootballLivePitchView`, `FootballLiveMatchView`, `FootballFacts`, `FootballCommitments`, `FootballMemory`, `FootballNegotiation`, `FootballPromiseOutcome`, `FootballAgenda`, `Tests/Football{PromiseOutcome,FactsAndTalks}Tests` | F4, F5, `Resources/` |
| **01** | F4: projeção de caixa, reunião de diretoria, projeto comercial, agenda pessoal, balanceamento; motor de variedade da partida | `FootballCashProjection*`, `FootballBoardMeetings`, `FootballCommercialProjects`, `FootballMatchVariety`, `FootballCareer+Business`, `+Club`, Sources de Banco/Clube/Negócios | F1/F3, F5, `Resources/` |
| **18** | F5: amplitude dos apps (Liga, Rodada, Palpite+, Metas, Troféus, FutOS) | `FootballLeagueAnalysis`, Sources dos apps citados, `Tests/*League*` | F1/F3/F4, `Resources/` |
| **82** | Arte | só `apps/manager-futebol/Resources/` | todo o resto |

`eleicao-44` não participa (outro projeto).

## Protocolo

1. **Ninguém commita nem dá push.** Cada sessão deixa os arquivos da sua fatia no working tree, **sem `git add`**. A sessão 6a integra e commita: é a única que mexe no índice, para não misturar trabalho de fatias nem quebrar o build com commits parciais.
2. **Ao concluir um item**, a sessão envia uma mensagem à 6a no formato:
   `PRONTO <item do roadmap> | arquivos: <lista> | testes: <filtro rodado e resultado>`.
3. **A 6a** roda a suíte completa (Docker swift:5.9), commita os arquivos listados com `git add <caminhos>` e marca o item no roadmap. Só então a sessão segue para o próximo item.
4. **Arquivos compartilhados** (`FootballCareer.swift`, `FootballClubModels.swift`, `FootballWorld.swift`, `FootballHome.swift`, `FootballClubHubViews.swift`, `FootballLeagueViews.swift`): edite o **mínimo** (uma linha de integração) e avise quem mais usa. Prefira arquivo novo + uma linha.
5. **Build isolado**: cada sessão usa o próprio scratch do Docker (`/tmp/mfbuild<id>`), nunca o de outra.
   `cd apps/manager-futebol && docker run --rm -v "$PWD":/pkg:ro -v /tmp/mfbuild<id>:/build -w /pkg swift:5.9 swift test --scratch-path /build [--filter <Classe>]`
6. **Roadmap**: só a 6a edita `docs/ROADMAP-FUTOS.md`, com base nas mensagens `PRONTO`.
7. **Prints e TestFlight**: só no fim, coordenados pela 6a, após suíte completa verde e build do GitHub Actions verde. O envio ao TestFlight depende da aprovação do usuário.
8. Dúvida de dono de arquivo: pergunte à 6a, não decida sozinho.

## Estado (atualizado pela 6a)

- F2: integrado (`43a0286`).
- F1/F3 Core: implementado, compilando; suíte completa em execução.
- F4 (01): projeção de caixa, reunião de diretoria e coleção implementadas; aguardam integração.
- F5 (18): análise de liga em Core pronta; UI pendente.
- Arte (82): em andamento.
