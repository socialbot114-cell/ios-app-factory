# Roadmap — Manager de Futebol Brasileiro (100% offline)

> Plano geral do zero até o app completo, incluindo o plano mais ousado de redes sociais simuladas.
> Princípios inegociáveis: **100% offline, local no iPhone, clubes/atletas fictícios, sem dinheiro real, sem servidor, sem licenças reais.**

## 0. Visão de chegada

Um manager de bolso onde o jogador:

1. Escolhe um clube fictício e inicia uma carreira local.
2. Vive o ciclo **calendário → preparação → partida → relatório → tabela → próxima rodada**.
3. Toma decisões que mudam resultados: escalação, formação, instruções por setor, mentalidade, treino, substituições.
4. Gerencia elenco, contratos, base, empréstimos, finanças e relação com diretoria/torcida.
5. Disputa pontos corridos, copa mata-mata, acesso/rebaixamento e, no plano ousado, continentais.
6. Acompanha carreira, notícias e redes sociais **geradas no aparelho** a partir do que realmente aconteceu no save.
7. Joga sessões curtas ou temporadas completas, com autosave, modo escuro, haptics e acessibilidade.

Referências usadas como “bíblia” (ideias e padrões, não cópia de código):

- [OpenFoot Manager](https://github.com/openfootmanager/openfootmanager) — [Visão](https://github.com/openfootmanager/openfootmanager/blob/develop/VISION.md) e [roadmap](https://github.com/openfootmanager/openfootmanager/issues/11): jogo local, profundidade ajustável, construir por etapas.
- [Bygfoot](https://github.com/kashifsoofi/bygfoot): liga + copa + transferências + promoção/rebaixamento com escopo enxuto.
- [Open Football](https://github.com/ZOXEXIVO/open-football): mundo simulado onde outros clubes também evoluem; dados separados do motor.
- [OpenEngine](https://github.com/atas76/openengine): coerência entrada → evento → resultado; começar pequeno e explicável.
- [Football Probability Models](https://github.com/Victor-DS/FootballProbabilityModels): Elo/Poisson e simulação massiva para balancear placares e tabelas.
- Tópicos [soccer-manager](https://github.com/topics/soccer-manager), [football-manager](https://github.com/topics/football-manager) e [football + Java](https://github.com/topics/football?l=java): descoberta; misturam jogos, motores, mods e trabalhos antigos.
- Exemplos Java [FootballManagerSimulator](https://github.com/ElliotJBall/FootballManagerSimulator) e [FM2017](https://github.com/man0s/FM2017): conceitos pontuais, não arquitetura-alvo.

Licenças variam (GPL-2.0/3.0, Apache-2.0, MIT). Não copiar implementação sem revisão de licença.

## 1. Ponto de partida — Fase 0 (estado atual local)

Implementado em `apps/manager-futebol/Sources/`:

- Liga de **8 clubes, 14 rodadas, turno e returno**, 4 jogos por rodada (`FootballGame.swift:188-201,251-276`).
- Tabela com pontos, vitórias, saldo, gols e desempate (`FootballGame.swift:337-380`).
- Atletas com posição, idade, atributos e condição; formações **4-3-3, 4-4-2, 3-5-2**; 3 abordagens; escalação manual + sugestão automática (`FootballGame.swift:21-106,278-335`).
- Simulação determinística por seed, com mando de campo, condição e rating tático (`FootballGame.swift:432-481,531-589`).
- Orçamento, 8 agentes livres, compra/venda de reservas, bônus anual, envelhecimento/evolução simples (`FootballGame.swift:382-429,483-529`).
- Save local `Codable` versionado em `UserDefaults`, com validação (`FootballCareerStore.swift:3-91`).
- UI SwiftUI: Painel, Tabela, Elenco/Tática, Mercado e relatório da rodada (`ManagerFutebolApp.swift:68-361,557-642`).
- Brief atual em `specs/product-briefs.md:10`.

Limite atual: uma liga curta, sem calendário navegável completo, sem banco/substituições, sem cartões/lesões/suspensões, sem transferências entre clubes, sem copa/divisões, sem estatísticas por atleta, sem notícias/redes locais.

## 2. Mapa das fases

| Fase | Nome | Objetivo jogável |
|---|---|---|
| 1 | Série A jogável | 20 clubes, 38 rodadas, calendário, tabela completa, artilharia, prévia do adversário, 2 ritmos de partida |
| 2 | Partida viva | Banco, 5 substituições, instruções por setor, eventos/estatísticas, cartões/suspensões, lesões, IA adversária adaptativa |
| 3 | Elenco brasileiro | Geração regional, potencial, base, empréstimos, moral, contratos/empresários, ídolos, vendas ao exterior |
| 4 | Clube e dinheiro | Receitas/despesas, salários/teto, patrocínios, TV, dívidas, SAF vs tradicional, metas da diretoria |
| 5 | Brasil completo | Copa mata-mata ida/volta, Série B com acesso/rebaixamento, estaduais fictícios, continentais, temporada relâmpago/expressa |
| 6 | Mídia procedural | Manchetes, coletiva, comentaristas, rumores, crise narrativa, arquivo de carreira |
| 7 | Técnico e torcida | Reputação, currículo, múltiplos clubes, energia mental, demissão, seleção, torcida/protestos/mando/clássicos |
| 8 | Plano ousado: social + iPhone | Rede social local, bolão/fichas fictícias, reputação como “ação do técnico”, conquistas, widgets, haptics, modo escuro, exportar imagem, temporada expressa |

Regra de sequência: não iniciar Fase 5 sem Fase 1 estável; não iniciar Fase 8 sem Fase 6 estável. Cada fase precisa passar em iPhone + iPad, modo claro/escuro e texto ampliado antes de avançar.

## 3. Fase 1 — Série A jogável (MVP de campeonato)

Ideias cobertas: 2, 3, 4, 6, 10, 17, 75, 91, 92, 95.

- Escolha de clube no início da carreira; Aurora FC deixa de ser fixo.
- **20 clubes fictícios, 38 rodadas, turno e returno.** Calendário como dado próprio, não lista fixa na UI.
- Tabela completa: J/V/E/D/GP/GC/SG/P + forma recente (últimos 5).
- Tela Calendário: passados com placar; futuros com data fictícia da temporada, local e adversário.
- Página do clube adversário: posição, forma, artilheiro, pontos fortes/fracos.
- Artilharia, assistências, estatísticas por atleta e por clube.
- Registro estruturado de lances: gol, finalização, posse, cartão. Tudo que alimenta relatório, tabela, notícias e social nasce desse log.
- Dois ritmos:
  - **Resultado rápido:** simula e mostra relatório.
  - **Lances em texto:** feed cronológico simples, sem 2D pesado nesta fase.
- Autosave a cada partida + retomada local.
- Modo uma mão: ação principal sempre alcançável, botão primário grande.

Aceite:

- Temporada completa jogável de 38 rodadas sem travar save.
- Tabela e artilharia sempre consistentes com os logs.
- Testes de calendário, desempates, artilharia e migração de save.
- UI test: escolher clube → escalar → jogar → relatório → tabela.

## 4. Fase 2 — Partida viva

Ideias cobertas: 1 parcial, 3, 4, 5, 6, 7, 9, 43 parcial.

- Banco de reservas por posição; **até 5 substituições** com efeito em rating e eventos futuros.
- Instruções por setor (defesa/meio/ataque) em vez de microgestão por jogador.
- Mentalidade: retranca / equilíbrio / pressão, com custo de energia e risco.
- Editor tático simples primeiro (setores + mentalidade); drag-and-drop em campo fica para refinamento pós-MVP.
- Fadiga por posição e minutagem; lesão por overuse em calendário apertado; suspensão por cartões.
- IA adversária com plano por rodada e adaptação leve ao estilo do jogador ao longo da temporada.
- Treino semanal com foco (físico, tático, finalização): consome semana, desenvolve atributos, altera recuperação.
- Relatório com finalizações, posse, cartões, substituições e lances-chave.

Aceite:

- Trocar 5 atletas muda rating e eventos subsequentes de forma testável.
- Cartão → suspensão impede escalação; lesão gera retorno em rodadas.
- Simulação continua determinística por seed + decisões.

## 5. Fase 3 — Elenco brasileiro e ciclo do atleta

Ideias cobertas: 61, 62, 63, 64, 65, 66, 67, 68, 69, 70.

- Geração procedural com nomes/sobrenomes por região fictícia.
- Atributos com identidade: criatividade/passe compensando físico em perfis brasileiros.
- Potencial (POT) + overall (GER) + curva por idade.
- Base: juvenis promovidos, minutagem e treino aceleram desenvolvimento.
- Empréstimos com clubes-parceiros fictícios.
- Moral: sequência, minutagem, salário em dia, status de queridinho/ídolo.
- Contratos com duração, salário, luvas e empresário; renovação com pressão.
- Venda ao exterior como receita relevante; atraso salarial derruba moral.
- Aposentadoria de ídolos como evento de carreira.

Aceite:

- Nenhum clube fica sem condição de preencher formação após vendas/aposentadorias.
- Mercado valida vaga, saldo, contrato e elenco mínimo por posição.

## 6. Fase 4 — Diretoria, finanças e gestão

Ideias cobertas: 55, 71, 72, 73, 74, 75, 76, 77, 78, 79.

- Plano de contas simples e visível: bilheteria, patrocínio master/2, TV por divisão, vendas, salários, operação.
- Dívida herdada opcional no início de carreira.
- Teto salarial, multa e alerta antes de estourar folha.
- SAF vs clube tradicional com regras distintas de orçamento/autonomia.
- Metas com prazo: classificar, evitar queda, revelar base, equilibrar caixa.
- Conselho vota decisões grandes; barra de confiança da diretoria.
- Crise extrema permite vender patrimônio com consequências esportivas.
- Corrupção/escândalo apenas como evento opcional e claramente fictício.

Aceite:

- Todo movimento financeiro tem origem visível no extrato da temporada.
- Meta vencida/estourada altera confiança e narrativa da carreira.

## 7. Fase 5 — Brasil completo e calendário realista

Ideias cobertas: 11, 12, 13, 14, 15, 16, 18, 19, 20, 100.

> Nomes licenciados reais ficam fora. Usar equivalentes fictícios com regras parecidas.

- Copa nacional mata-mata com ida/volta, gol fora/sorteio/prorrogação/pênaltis conforme regra escolhida.
- **Série B jogável** com acesso/rebaixamento; depois avaliar C/D apenas se a base aguentar 40+ clubes.
- Estaduais fictícios por região no início da temporada como pré-temporada competitiva.
- Calendário com Data FIFA fictícia, pausas, clássicos regionais e janelas em janeiro/julho.
- Continentais como progressão: classificação via liga/copa leva a torneio paralelo.
- Clássicos com moral/pressão e efeito real na simulação.
- Eventos sazonais leves (festas, carnaval fictício) afetando foco/energia, sem caricatura.
- Temporada relâmpago/expressa: calendário comprimido de 15–20 minutos.

Aceite:

- Um clube pode jogar liga + copa na mesma semana sem corromper calendário, elenco ou save.
- Acesso/rebaixamento troca divisões e receitas na temporada seguinte.

## 8. Fase 6 — Notícias e mídia procedural offline

Ideias cobertas: 41, 42, 43, 44, 45, 46, 47, 48, 49, 50.

- Gerador local de manchetes a partir do log real: placar, virada, estreia, artilharia, crise.
- Jornal fictício semanal com capa conforme resultados.
- Coletiva com 2–3 respostas possíveis e efeito em moral/confiança.
- Painel de comentaristas pós-jogo em texto, citando tática e lances do log.
- Rumores de mercado: parte verdadeiros, parte falsos; revelados na janela seguinte.
- Sequência de derrotas gera arco de crise; sequência de vitórias gera arco de favoritismo.
- Jogador insatisfeito pode pedir saída; resposta afeta moral e mercado.
- Arquivo relê a carreira como linha do tempo de manchetes.

Aceite:

- Nenhuma notícia contradiz placar, tabela ou evento registrado.
- Textos marcados como fictícios; nenhum nome/veículo real.

## 9. Fase 7 — Carreira do técnico e torcida

Ideias cobertas: 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 81, 82, 83, 84, 85, 86, 88, 89.

- Currículo com clubes, títulos, aproveitamento e fama regional/nacional.
- Múltiplos clubes por carreira; imprensa local lembra passagens e fracassos.
- Personalidade do técnico altera eventos e respostas disponíveis.
- Energia mental: crises consomem, vitórias/férias recuperam.
- Demissão com efeito cascata em ofertas futuras; hall da fama ao aposentar.
- Objetivo final: seleção fictícia nacional.
- Modo sandbox sem pressão para testar táticas.
- Torcida separada da diretoria: aprovação, protestos, faixas procedurais com nome do técnico, pedidos de organizada, recepção após título/fracasso, mosaicos em decisivos, mando/clima e clássicos hostis.

Aceite:

- Demissão/renúncia não corrompe save; nova oferta respeita reputação.
- Protesto/mosaico nunca bloqueia a partida; são camada narrativa + bônus/penalidade explícita.

## 10. Fase 8 — Plano mais ousado: social simulado, previsão e UX iPhone

Ideias cobertas: 21–40, 87, 90, 93, 94, 96, 97, 98, 99.

### 10.1 Redes sociais 100% locais

- Feed estilo timeline com NPCs fixos: torcedor, jornalista, ex-jogador, perfil de estatística.
- Posts nascem de regras sobre o log: gol nos acréscimos, virada, pênalti polêmico, estreia da base, recorde.
- Memes textuais automáticos após vexame/heroísmo, sem imagem externa.
- Seguidores do técnico sobem/descem com desempenho.
- Enquetes fictícias com efeito em pressão/moral.
- DM de empresários oferecendo atletas vira lead real para o mercado local.
- Trending local pós-jogo como notificação local, sem rede.
- Comentários sobre escalação antes/depois da partida.
- Polêmica da rodada quando o log marca lance duvidoso.
- Perfil público do técnico com histórico e reações acumuladas.
- Hashtags viram conquistas escondidas.

Regras duras:

- Tudo procedural e fictício; nenhum usuário real, nenhum dado externo.
- Conteúdo moderado por templates: sem ódio, sem aposta real, sem desinformação sobre mundo real.
- Social nunca decide resultado sozinho; ele altera pressão/moral/confiança dentro de limites testados.

### 10.2 Previsão e fichas fictícias

- Moeda apenas fictícia, ganha jogando; sem compra, sem saque, sem odds reais.
- Aposta no próprio jogo antes de simular, com odds do motor local.
- Bots torcedores “apostam” em demissão/título; bolão da comissão sobre próximos resultados.
- Odds dinâmicas pelo retrospecto; histórico de acertos vira estatística de perfil.
- Reputação do técnico exibida como gráfico tipo ação, sem valor financeiro.
- Desafios opcionais com recompensa cosmética, por exemplo vencer por 2+ gols.
- Clássicos têm volatilidade maior, explicitamente indicada.

### 10.3 UX final de iPhone

- Save automático por partida; retomar em segundos.
- Notificações locais para treino/decisão pendente, sem rede.
- Widget com próximo jogo e status.
- Modo escuro nativo, haptics em gol/decisão, exportar carreira como imagem.
- Zero microtransação real; cosméticos desbloqueados jogando.
- Game Center apenas como camada opcional de conquistas; se conflitar com offline estrito, manter desligado por padrão e deixar explícito que sincronização exige rede.
- Áudio curto de rádio de torcedor apenas opcional e gerado com assets locais.

## 11. Mapa completo das 100 ideias → fases

| Bloco | Ideias | Destino |
|---|---|---|
| 1. Núcleo tático | 1–10 | Fase 1: 2,3,6,10 · Fase 2: 1,3,4,5,6,7,8,9 |
| 2. Ligas/calendário | 11–20 | Fase 1: 17 · Fase 5: 11,12,13,14,15,16,18,19,20 |
| 3. Previsão offline | 21–30 | Fase 8.2 |
| 4. Social offline | 31–40 | Fase 8.1 |
| 5. Notícias/mídia | 41–50 | Fase 6 |
| 6. Vida do técnico | 51–60 | Fase 7 |
| 7. Elenco | 61–70 | Fase 3 |
| 8. Diretoria/finanças | 71–80 | Fase 4 |
| 9. Torcida/ambiente | 81–90 | Fase 7; 87 e 90 na Fase 8.3 |
| 10. Progressão iPhone | 91–100 | Fase 1: 91,92,95 · Fase 8.3: 93,94,96,97,98,99,100 · Fase 5: 100 |

Detalhamento por número:

- 1 editor tático: Fase 2, começar por setores; drag-and-drop depois.
- 2 perfis/variações brasileiras: Fase 1 + expansão na Fase 2.
- 3 instruções por setor: Fase 2.
- 4 texto/2D leve: Fase 1 texto; 2D simples somente Fase 2 tardia.
- 5 substituições/ajustes ao vivo: Fase 2.
- 6 mentalidade: Fase 1 básica, Fase 2 com custo/benefício completo.
- 7 fadiga/lesão: Fase 2.
- 8 treinos semanais: Fase 2.
- 9 IA adaptativa: Fase 2.
- 10 decisão rápida: Fase 1.
- 11 Séries A–D: Fase 5, começando por A+B.
- 12 Copa ida/volta: Fase 5.
- 13 estaduais: Fase 5 como fictícios.
- 14 calendário/Data FIFA: Fase 5.
- 15 continentais: Fase 5 tardia.
- 16 clássicos: Fase 5 + efeitos na Fase 7.
- 17 pontos corridos vs mata-mata: Fase 1 + Fase 5.
- 18 janelas janeiro/julho: Fase 5.
- 19 eventos sazonais: Fase 5, efeito pequeno e transparente.
- 20 temporada relâmpago: Fase 5.
- 21–30 previsão/fichas: Fase 8.2, sempre fictício.
- 31–40 social: Fase 8.1, sempre local e moderado.
- 41–50 mídia: Fase 6.
- 51–60 técnico: Fase 7, sandbox em 7.
- 61–70 elenco: Fase 3.
- 71–80 finanças: Fase 4.
- 81–86,88,89 torcida: Fase 7.
- 87 fan tokens: Fase 8.3, colecionável sem valor.
- 90 rádio: Fase 8.3 opcional.
- 91 save automático: Fase 1.
- 92 uma mão: Fase 1.
- 93 widget: Fase 8.3.
- 94 notificações locais: Fase 8.3.
- 95 modo escuro: Fase 1.
- 96 haptics: Fase 8.3.
- 97 exportar imagem: Fase 8.3.
- 98 Game Center: Fase 8.3 opcional, desligado por padrão se exigir rede.
- 99 zero microtransação real: regra global.
- 100 temporada expressa: Fase 5 + refinamento na Fase 8.3.

## 12. Arquitetura-alvo offline

- `FootballGame`: regras puras e determinísticas; calendário, simulação, mercado, mídia/social como funções testáveis.
- `FootballCareer`: um save versionado por carreira; múltiplos saves locais na Fase 4+.
- `FootballMatchLog`: evento canônico que alimenta placar, stats, notícias e social.
- `FootballWorld`: clubes, competições, finanças e reputações como dados, não código espalhado na UI.
- Persistência local primeiro: `UserDefaults`/JSON para saves pequenos; migrar para arquivo/SQLite quando histórico, notícias e feed crescerem.
- Seeds por competição + temporada para reproduzir resultados e facilitar QA.
- Acessibilidade desde a Fase 1: VoiceOver, texto dinâmico, contraste, navegação por teclado onde aplicável.

## 13. Riscos e limites

- Escopo: 4 divisões + continentais + social completo é projeto grande; entregar por fases evita jogo pesado e confuso.
- Licenças: nada de nomes, escudos, ligas ou veículos reais.
- Apostas: nunca envolver dinheiro real, odds externas ou rede; deixar “fictício” visível.
- Social: templates fechados e moderados; sem conteúdo gerado livremente sem filtro.
- Performance: simulação de 20 clubes precisa continuar instantânea no iPhone; perfilar antes de adicionar 2D/áudio.
- Saves: cada fase com novos campos exige migração versionada e teste de save antigo.

## 14. Critérios de pronto por fase

1. Temporada jogável de ponta a ponta sem perda de save.
2. Testes de domínio + UI para o fluxo principal da fase.
3. Capturas iPhone + iPad dos estados novos.
4. Sem regressão nas fases anteriores.
5. Texto, modo escuro e acessibilidade verificados.
6. Roadmap atualizado com o que realmente foi entregue.

## 15. Diário de implementação (comentários do progresso)

### 27/09/2026 — Fase 1 parte 1: partida com estatísticas + cara de campeonato
- **Motor (`FootballGame.swift`):** `FootballMatchResult` ganhou `homeShots`, `awayShots` e `homePossession`
  com defaults para não quebrar saves/testes antigos. Geração determinística a partir do mesmo seed
  da partida + diferença de rating (comentário `Fase 1` no `simulateMatch`).
- **Agregações novas:** `fixturesForRound`, `upcomingFixtures`, `recentForm` (V/E/D) e `topScorers`
  calculados do log real de `goalEvents`. Isso prepara o `FootballMatchLog` canônico da arquitetura-alvo.
- **Persistência (`FootballCareerStore.swift`):** validação estendida para finalizações (0–30)
  e posse (20–80). Saves antigos sem esses campos continuam válidos via `Codable` + defaults.
- **UI (`ManagerFutebolApp.swift`):**
  - Tabela agora mostra J/V/E/D/P + GP/GC/SG na linha do clube e forma recente.
  - Novo painel Artilharia (top 5) e painel Próximos jogos (3).
  - Painel do último resultado e `FootballReportView` exibem finalizações e posse,
    com `accessibilityIdentifier("match-report-stats")` para o teste de UI.
- **Testes (`FootballSeasonTests.swift`):**
  - `testSimulatedMatchesRecordShotsAndPossessionDeterministically`: limites + determinismo.
  - `testFormTopScorersAndCalendarHelpersStayConsistent`: calendário, próximos jogos, forma e soma da artilharia.
- **Pendente Fase 1:** escolha de clube na UI, expansão 8→20 clubes / 14→38 rodadas,
  calendário navegável por rodada, prévia do adversário e 2 ritmos (rápido vs lances em texto).
  Expansão da liga quebrará contagens de fixtures/saves: planejar migração versionada (save v3).
