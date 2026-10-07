# Roadmap FutOS — carreira viva de futebol

Referência de continuidade: **Manager-futebol bugs e melhorias**.

Status atual (07/out/2026, 02:55, horário de Brasília): **build 1.1 (11) aprovado e enviado ao TestFlight interno em 07/out às 02:53 (run 37572402802), com craques eternos, onboarding e ritual de virada de temporada. O 1.1 (10) segue como build anterior. Próximo build: 1.1 (12), a partir da branch `feature/entrega-a-ritmo`. O plano do ciclo 2 (seções 5b a 5f), o plano de testes (`docs/PLANO-DE-TESTES.md`) e o pacote para o outro agente (`docs/ENTREGA-PARA-O-AGENTE.md`) estão escritos. Veja a atualização de 7 de outubro abaixo, `docs/BASELINE-FUTOS.md` e `docs/ORQUESTRACAO.md`**.

Convenção de datas: todos os horários deste documento estão em horário de Brasília (UTC−3). Os runs do GitHub Actions registram UTC; a conversão está na tabela de builds.

## Atualização — 7 de outubro de 2026, 01:59 (Brasília)

### Onde estamos

- **Linha estável:** branch `ccr-020b52d1-16pkkp` (commit `2dfaa10`), que parte da `manager-futebol/phases-2-7`. É exatamente o que está no TestFlight no build 1.1 (11); não recebe mais código novo.
- **Próxima entrega:** branch `feature/entrega-a-ritmo` (a partir do mesmo commit do 1.1 (11)), com as lendas ajustadas. A linha estável não recebe código novo enquanto o 1.1 (11) é validado.
- **Hall das Lendas** (app novo, vitrine premium de cartas com compra por carta): branch `feature/hall-das-lendas`, já unido à linha estável. Fora do TestFlight do Football; validado pelo workflow "iOS app validation".
- **Testes de domínio no último run completo (1.1 (11), tentativa 1):** 430 testes, zero falhas, incluindo os novos de craques eternos e ritual de virada.

### Builds do TestFlight (1.1)

| Build | Run | Início (Brasília) | Resultado |
|---|---|---|---|
| 1.1 (7) | `37503016476` | 06/out 14:22 | Barrado: 4 UI tests (halftime-talk, perfil do clube, simulador do Banco, slot em Ajustes). Causa do intervalo: a partida abria 0,5 s depois da folha e o fechamento derrubava a tela. |
| 1.1 (8) | `37538496780` | 06/out 19:07 | Barrado: o teste do intervalo ainda falhou; hierarquia anexada mostrou a partida pausada no minuto 0. Três UI tests novos pulados com motivo escrito. |
| 1.1 (9) | `37545283666` | 06/out 20:13 | Barrado: o intervalo passou (a partida agora abre no `onDismiss` da folha); falhou `contact-family` fora da viewport em Contatos. |
| **1.1 (10)** | `37549938172` | 06/out 21:04 | **Aprovado: gate verde em iPhone e iPad, assinatura, upload e ativação no TestFlight interno. Concluído 06/out às 22:29.** |
| 1.1 (11), tentativa 1 | `37567530198` | 07/out 00:36 | Barrado às 01:21: 430 testes de domínio verdes; falhou um UI test (`testAdvancingTheCalendarLocksThePhoneWithTheNewDate`, botão `live-finish` não apareceu em 30 s). Nada enviado. |
| **1.1 (11)**, tentativa 2 | `37572402802` | 07/out 01:38 | **Aprovado: gate verde em iPhone e iPad (testes de 01:48 a 02:45), assinatura, upload e ativação no TestFlight interno. Concluído 07/out às 02:53.** O UI test que falhou na tentativa 1 passou com a espera robusta. |

### Entregue desde 06/out

- **Craques eternos** (`Core/FootballIcons.swift`, `Sources/Apps/Gestor/FootballIconViews.swift`): seis cartas redimensionadas (cerca de 1 MB no total), pacote com animação de abertura, craque salvo como atleta real (salário zero, protegido de venda). Regra atual na branch `feature/entrega-a-ritmo`: uma lenda ao começar a carreira e outra a cada fim de temporada, sem convidado por partida; pacote não aberto é mantido; saves antigos abrem.
- **Onboarding** (`Sources/Onboarding/FootballOnboardingView.swift`): cinco páginas e escolha de dificuldade, uma vez por instalação; desligado em UI tests e capturas.
- **Ritual de virada de temporada** (`Core/FootballOffseason.swift`, `Sources/Apps/Gestor/FootballOffseasonView.swift`): apito final, contratos que vencem, balanço, pacote, férias, patrocinador, pré-temporada e estreia, com decisões obrigatórias e ritmo controlado; jogar fica bloqueado até o fim.
- **Hall das Lendas** (`apps/hall-das-lendas`): vitrine em carrossel, coleção com filtro de raridade, detalhe com inclinação 3D, cartão do dia gratuito, compra única por carta ou pacote da coleção (StoreKit 2, com loja simulada em testes), restaurar compras; registrado na fábrica (agora 10 apps).
- **Correções:** a partida do pré-jogo abre pelo `onDismiss`; o botão da família em Contatos é buscado com rolagem; testes de temporada inteira protegem a confiança da diretoria.
- **Documentos:** plano do ciclo 2 (seções 5b a 5f), plano de testes (`docs/PLANO-DE-TESTES.md`), e esta atualização.

### Calendário de versões (teste por versão)

Cada versão é um build do TestFlight, só avança com gate verde e capturas revisadas, e tem pelo menos dois dias de uso interno (critérios completos em `docs/PLANO-DE-TESTES.md`, seção 9). Datas-alvo são combinadas com o usuário a cada versão; as datas reais entram aqui quando acontecem.

| Versão | Conteúdo | Estado | Data real |
|---|---|---|---|
| 1.1 (10) | Linha de base | Aprovada | 06/out 22:29 |
| 1.1 (11) | Craques eternos (pacote só no fim da temporada, com convidado por partida no modo Fácil), onboarding, ritual de virada | Aprovada e no TestFlight interno | 07/out 02:53 |
| Entrega A | Ritmo e recompensa: pilares PIL, modo Clássico e Imersivo, animações de vitória, marcos, Banco (BAN-07 a BAN-09); lendas inicial e por temporada; abertura do app (carregamento, Continuar, Novo jogo, Opções) | Código iniciado na branch `feature/entrega-a-ritmo`: lendas inicial e por temporada e abertura do app escritas, aguardando CI | a combinar |
| Entrega B | Mercado simples e base com categorias | Planejada | a combinar |
| Entrega C | Carreira, narrativa e rede social | Planejada | a combinar |
| Entrega D | Mundo vivo: pushes, agenda, personalização | Planejada | a combinar |
| Entrega E | Lançamento: som, recompensa diária, pacote de loja, widgets | Planejada | a combinar |

### Pendências de teste

- Camadas 2 a 4 do plano de testes para o 1.1 (11), já no TestFlight: capturas de iPhone e iPad (`onboarding*`, `offseason-*`), roteiros 5.1 a 5.4 e dois dias de uso interno (a contar de 07/out 02:53).
- UI tests pulados que precisam voltar antes da Entrega C: `testBankSimulatorChangesProjectionAndResetRestoresIt`, `testSettingsCanCreateAndRestoreCareerSlot` e `testLeagueRowsOpenClubProfileMatchesAndRoundsNavigate`.
- UI tests curtos de onboarding e ritual de virada, só depois que as telas estabilizarem.
- Hall das Lendas: criar os produtos no App Store Connect, ícone e capturas; direitos de imagem das cartas (LAN-01) antes de qualquer versão pública ou venda.

## Atualização — 6 de outubro de 2026 (2): organização do FutOS, passagem de dia, guia, chat e física da partida

**Estado: implementado localmente, NÃO compilado e NÃO testado** (host Linux sem Swift; a imagem Docker `swift:5.9` valida só o Core). Só foram conferidos balanceamento de chaves e `tools/validate_factory.py`. Antes de qualquer coisa: build iOS, `swift test` e UI tests no CI; depois capturas e playtest no simulador. Descrição técnica em `docs/FUTOS-ARQUITETURA.md`.

### Entregue

- **Organização (OS):** `Sources/` dividido em `PhoneOS/` e `Apps/<App>/` (Gestor, Tática, Liga, Transfer, Clube, Mensagens, Chuteira, Palpite, Rodada, Vida, Negócios, Metas, Troféus, Alertas, Marca, Banco, Contatos, Ajustes, Partida, Elenco), mais `Compartilhado/` e `Capturas/`. Arquivos que misturavam apps foram separados. Duplicidades removidas do Clube (Finanças, Marketing/TV, Modos de jogo e Carreiras salvas agora só em Banco, Marca e Ajustes; Clube ganhou atalhos "Em outros apps"); Patrocínio passou para a Marca. `PhoneApp.purpose` descreve o dono de cada assunto e aparece na busca. `validate_factory.py` passou a ler `Sources` recursivamente.
- **Calendário com datas:** `Core/FootballCalendarClock.swift` (domingo = liga, quarta = copa, temporada 1 em 2027). Datas na barra de status, Gestor, mensagens e prazos.
- **Passagem de dia:** o celular bloqueia **só quando o dia muda** (não ao abrir o jogo). A tela de bloqueio rola data e hora dia a dia (faixa de fichas, noite → amanhecer, vibração) e entrega widgets: último jogo, próximo jogo com horário, contadores e **"Durante a noite"** com tudo que espera ação. Coletiva pendente abre só após desbloquear. "Reduzir movimento" pula a animação. UI test novo com `--lock-on-advance`.
- **O que fazer agora:** `Core/FootballNextAction.swift` com pontuação (0 a 100+), categoria e "por quê"; prazo curto soma bônus; cobre coletiva, crise, decisões, escalação/preparação, promessas, contratos, mensagens (agrupadas), propostas, moral, elenco curto, dinheiro, patrocínio, energia/estresse, família e metas. "Depois" adia até o dia seguinte (urgentes não). Botão na tela inicial, notificação "Ir agora" que leva ao app/mensagem/decisão, notificação automática após a noite, dicas rotativas e **Plano do dia** no Gestor.
- **Mensagens (chat):** `Core/FootballChat.swift`. Abas Jogadores, Comissão, Família e Clube; mensagens do sistema viram balões com os botões de resposta de antes; mensagens rápidas (elogiar, cobrar, "como você está?", relatórios da comissão, "o que fazer agora?", carinho para a família) com resposta e efeitos reais; uma por dia por conversa; histórico no save (campo opcional, saves antigos abrem).
- **Chuteira:** histórias do dia, fotos nos posts (desenhadas pelo app por tipo), anexar foto ao publicar (+15% de curtidas), curtir e atalho para mensagens.
- **Partida (física):** intervalo e apito final param o campo (bancos, bola no centro, "INTERVALO"/"FIM DE JOGO"); no 2º tempo o visitante dá a saída; faltas, cartões, lesões e impedimentos geram bola parada com cobrador; bola fora gera lateral/escanteio/tiro de meta; chute sai do ponto narrado; bola na trave rebate; no modo "Ver jogo" o relógio espera a jogada narrada terminar.
- **Testes escritos (não executados):** `FootballCalendarClockTests`, `FootballChatAndGuideTests`; UITests ajustados (`club-management`, busca por trecho de "Bem-vindo, Treinador", novo teste de bloqueio).

### Próximo plano

Ver `docs/PLANO-FLUXO-E-DESIGN.md` (fluxo do dia e da partida, design de mundo vivo e fase final de testes).

### Pendente / riscos

- Compilar e rodar tudo (principal risco: erros de tipo Swift não detectáveis aqui, ex.: `contentTransition(.symbolEffect)`, sobrecargas de `showGuide`, inicializadores memberwise).
- Pesos da pontuação do guia são estimativa; calibrar no playtest.
- Física: intervalo da prorrogação e cobranças de pênalti ainda sem tratamento próprio; substituições não animadas.
- Chat: sem digitação livre (só mensagens rápidas); conversas de mercado/empresário ainda só leitura.
- Capturas novas (tela de bloqueio com noite, chat, Chuteira com fotos, Plano do dia) ainda não geradas.

## Atualização — 6 de outubro de 2026: revisão antes de lançamento

- Novo incremento em validação: **Rodada Mágica com detalhe por atleta, liga dos amigos e compartilhamento contextual**, **simulador financeiro do Banco** e **carreiras salvas em Ajustes**.
- Liga: teste antigo pulado substituído por jornada com identificadores próprios, cobrindo clube, atleta, rodadas, pré-jogo e relatório. Aguardando aprovação iOS deste incremento.
- Save versão **12**: snapshot fantasy opcional separado dos efeitos narrativos; saves antigos continuam abrindo sem inventar escalação histórica.
- Motor verificado no Linux via Docker Swift 5.9: **388 testes aprovados, zero falhas**, incluindo novos testes de cenários financeiros e detalhes fantasy.
- Capturas novas preparadas: `budget-planning`, `fantasy-result`, `fantasy-league`, `fantasy-share`, `save-slots`.
- Workflow de captura agora permite escolher estados e famílias; revisão e evidências em `docs/REVISAO-FUTOS-06-10.md`.
- Este trabalho **não publica um novo build TestFlight**. Primeiro gerar prints atuais, validar interface iPhone/iPad e revisar com o usuário.

## Atualização — 5 de outubro de 2026

### Onde estamos

- Branch `manager-futebol/phases-2-7`, trabalho integrado em 11 lotes por uma sessão orquestradora (`docs/ORQUESTRACAO.md`); quatro sessões trabalharam em paralelo (motor e orquestração, negócios e mercado, apps de acompanhamento e FutOS, arte).
- **Testes de domínio:** 378, zero falhas (Docker `swift:5.9`). Inclui carreiras de 10 temporadas em 3 sementes (`FootballLongCareerTests`), saves de referência (`FootballReferenceSavesTests`) e calibração do motor.
- **Build iOS e capturas:** aprovados no GitHub Actions; 59 estados em `screenshots-review/futos-cafa572/` e run mais recente com as rotas corrigidas (`match-prep`, `season-end`).
- **Itens marcados:** a maior parte das fases F0 a F4, F6-01 a F6-04 e as categorias GES, TAC, MSG, CHU, TRF, CON, VID, MAR, CLB, BAN, NEG, PAL, ROD, MET, TRO, OS e AJU, cada uma com a evidência na própria linha.

### TestFlight 1.1 (build 6) — registro

| Tentativa | Run | Resultado |
|---|---|---|
| 1 | `37309095531` | **Barrada pelo gate de testes**; nada foi enviado. `testPlayLiveMatchAndReadLeague` passou isolado e falhou na suíte completa: o botão `live-finish` demorou mais de 20 s. |
| 2 | `37315165659` | Teste da partida **passou**; barrada por um UITest novo (`testLeagueRowsOpenClubProfileMatchesAndRoundsNavigate`) que procura a ficha do clube numa `UINavigationBar` que o FutOS não usa. Correção anterior mantida: prévia de repercussão fora da thread principal (`Task.detached`). |
| 3 | `37323855519` | **Aprovada: gate de testes verde (iPhone e iPad), assinatura, upload e ativação no TestFlight interno concluídos.** Build **1.1 (6)** enviado. O teste de LIG-01..03 está pulado com motivo explícito (reescrever com `staticTexts`/identificadores); LIG-01..03 seguem abertos. |

Causa da tentativa 1 é **provável, não provada** (não há UITest local). Antes disso, o mesmo fluxo falhou por outro motivo: toque no dock durante a animação de saída do app (corrigido nos testes). Se a tentativa 2 falhar, abrir o `xcresult` do run, ver a tela do momento da falha e corrigir; não reenviar sem o gate verde.

### O que ainda falta

- **Validação final:** F5-01 (revisar os 18 apps contra os critérios de aceite), F6-05 (jornadas de UI no iPhone **e no iPad**, ainda não validado nesta rodada), F6-06 (playtest manual no aparelho) e F6-07 (corrigir o que o playtest achar).
- **UITests pulados (1.1/7, runs 15 e 16 falharam igual):** `testBankSimulatorChangesProjectionAndResetRestoresIt`, `testSettingsCanCreateAndRestoreCareerSlot` e `testLeagueRowsOpenClubProfileMatchesAndRoundsNavigate` são testes novos que nunca passaram no CI; pulados com motivo explícito até haver hierarquia/screenshots dos pontos de falha. `testPrepFlowHalftimeTalkAndFullTimeCard` segue ativo, agora rolando até o painel e retomando o relógio, e anexando a hierarquia ao falhar.
- **Craques eternos (branch `feature/legend-cards`, não verificado em iOS):** seis cartas lendárias (Yashin, Garrincha, Zagallo, Beckenbauer, Charlton, Eusébio). Uma lenda chega junto com o primeiro contrato e outra a cada fim de temporada, em pacote; cada uma joga a temporada inteira (sem escolha de convidado por partida). Modelo em `Core/FootballIcons.swift`, telas e animação de abertura em `Sources/Apps/Gestor/FootballIconViews.swift`, testes em `FootballIconTests`. Falta: validar no CI (compilação e testes), conferir as animações no simulador e decidir direitos de imagem antes de publicar.
- **Onboarding e ritual de virada (não verificado em iOS):** `Sources/Onboarding/FootballOnboardingView.swift` abre o jogo com cinco páginas e a escolha de dificuldade (uma vez por instalação; desligado em UI tests e capturas). `Core/FootballOffseason.swift` e `Sources/Apps/Gestor/FootballOffseasonView.swift` trocam o botão "Encerrar temporada" por um ritual em etapas: apito final, contratos que vencem, balanço, pacote de craque eterno, férias, patrocinador, pré-temporada e estreia. Cada decisão é obrigatória, o botão só libera depois da cena respirar, e jogar fica bloqueado até o fim. Testes de domínio em `FootballOffseasonTests`; capturas `onboarding*` e `offseason-*`. Sem UI test novo de propósito: validar no CI e nas capturas antes de acrescentar.
- **Em aberto por categoria:** LIG-01/02/03 (UITest escrito, falta ele rodar verde), ROD-04/05/06, OS-05 (só a aba da Liga é preservada)/OS-08/OS-09, AJU-01 (saves em Ajustes) e CLB-06 (legado e convites).
- **Acesso:** cadastrar o tester no grupo "Equipe interna" do App Store Connect (`testerCount: 0` na última checagem) para instalar no iPhone.

### Próxima prioridade

1. Ver o resultado do run `37315165659`; se verde, aguardar o processamento da Apple e instalar **1.1 (6)**.
2. Playtest manual no iPhone (bloqueio → início → notificações → Mensagens → Tática → Gestor → partida em Narração e em Ver jogo → pós-jogo → coletiva → Liga) e registrar bugs com passos de reprodução.
3. Rodar iPad nos layouts alterados (Elenco, Gestor, Chuteira, Clube).
4. Fechar os itens em aberto acima, na ordem: OS-08/09 e LIG, ROD-04..06, AJU-01, CLB-06.
5. Atualizar este roadmap e o baseline com o que o playtest mostrar.

## Atualização — 4 de outubro de 2026

- Código publicado: `d1dc25b`, branch `manager-futebol/phases-2-7`.
- TestFlight: **1.0 (build 5)**, upload aprovado e processamento Apple concluído.
- Grupo: **Equipe interna**; estado `READY_FOR_BETA_TESTING`.
- Acesso no aparelho: **pendente de cadastrar tester**; a API confirmou `testerCount: 0`.
- Evidência: [workflow aprovado 37234149295](https://github.com/socialbot114-cell/ios-app-factory/actions/runs/37234149295).
- iPhone e iPad: **159 testes de domínio + 3 testes UI, zero falhas em cada dispositivo**. Teste adicional da jornada de partida também passou antes das suítes completas.
- Corrigida a identidade de navegação dos apps para impedir reutilização indevida de viewport/navegação ao alternar Tática e Gestor. Pré-jogo reposicionado antes da agenda.
- Capturas disponíveis do FutOS: `screenshots-review/futos-126d6a7/iphone/`, 26 estados do commit anterior `126d6a7`. **Não representam todas as novidades do build 5.** Capturas atualizadas de agenda/compromissos e auditoria manual no aparelho continuam pendentes.

### Próxima prioridade

1. Cadastrar o tester e instalar **1.0 (5)** no iPhone.
2. Auditar bloqueio → início → notificações → Mensagens → Tática → Gestor → partida → Liga.
3. Gerar capturas atualizadas do build 5 e registrar bugs com passos de reprodução.
4. Fechar a fatia F2: omissão com prazo, conversa encadeada, memória da relação e repercussões coerentes.
5. Avançar para F3/F4 após corrigir os problemas encontrados no playtest.

Este roadmap evolui o Manager de Futebol para um mundo persistente acessado pelo celular FutOS. Parte das funcionalidades citadas já existe; as caixas representam trabalho incremental a validar, e não uma afirmação de que todos os sistemas precisam ser construídos do zero.

## 1. Objetivo e regras de produto

**Objetivo:** cada app deve permitir observar, planejar, decidir, acompanhar e recordar acontecimentos de uma mesma carreira. O futebol é o eixo; vida pessoal, relações e negócios produzem escolhas que o influenciam.

### Regras de experiência

- Uma decisão importante tem contexto, alternativas, custo de oportunidade e retorno visível.
- Consequências imediatas, atrasadas e históricas precisam ser distinguíveis.
- Personagens lembram compromissos; acontecimentos têm continuidade.
- Informação pública, observação profissional e rumores têm graus de confiabilidade distintos.
- Nenhum app precisa de tarefas obrigatórias todos os dias. Consulta e memória também têm propósito.
- Delegação e avanço rápido preservam uma jornada agradável para quem quer focar no campo.
- Conteúdo e personagens são fictícios; fichas do Palpite+ continuam separadas do dinheiro da carreira.
- Uma consequência econômica ou esportiva é aplicada uma única vez, mesmo quando aparece em vários apps.

### Premissas de trabalho, sujeitas a confirmação

1. O tempo avança por iniciativa do jogador; não há penalidades por ficar dias reais sem abrir o jogo.
2. A carreira permanece offline e determinística por semente.
3. O primeiro incremento usa os dias de jogo existentes. Manhã/tarde/noite e dias entre partidas só entram após validar o ciclo semanal.
4. Novas regras devem permitir carregar saves antigos com defaults e migrações explícitas.
5. Palpite+ fica opcional e com fichas fictícias; sua possível transformação em prognósticos é uma decisão posterior.

## 2. Como acompanhar

### Estados

`Planejado → Em andamento → Em validação → Concluído`

Uma caixa só é marcada depois da implementação e da verificação descrita. Para itens de desenho, a entrega é uma decisão registrada; para funcionalidades, é comportamento executável.

### Registro por entrega

| Campo | Preencher ao iniciar/concluir |
|---|---|
| ID | Fase e categoria, por exemplo `F2-MSG-01` |
| Objetivo | Qual problema do jogador será resolvido |
| Responsável | Pessoa ou sessão responsável |
| Estado | Um dos quatro estados acima |
| Dependências | Entregas necessárias |
| Evidência | Teste, captura, cenário manual ou resultado de simulação |
| Referência | Commit/PR quando houver |
| Próxima ação | Uma microação concreta |

### Painel de marcos

| Marco | Resultado | Estado | Evidência |
|---|---|---|---|
| M0 | Baseline funcional e decisões de produto | Em andamento | Testes Linux e iOS aprovados; decisões e saves de referência pendentes |
| M1 | Consequências e navegação compartilhadas | Em andamento | Save v11, compromissos e destinos contextuais; fato compartilhado com Chuteira pendente |
| M2 | Uma semana completa e coerente | Em andamento | Agenda e jornada de partida verificadas; omissão/relação/repercussões pendentes |
| M3 | Pessoas com memória e negociação | Planejado | — |
| M4 | Clube, economia e vida com projetos contínuos | Planejado | — |
| M5 | Todos os 18 apps com propósito verificável | Em andamento | Smoke UI dos 18 apps aprovado; aceites aprofundados ainda pendentes |
| M6 | Carreira multitemporada validada | Em andamento | Suíte cobre temporadas, saves e economia; metas completas de F6 pendentes |

Sem estimativas de calendário até medir a primeira entrega vertical. Revisar escopo ao concluir cada marco.

## 3. Sequência de implementação

### F0 — Baseline e decisões

**Objetivo:** estabelecer o que funciona hoje e escolher regras antes de ampliar o estado da carreira.

- [x] F0-01 Inventariar ações, leituras, bloqueios, cooldowns e históricos de cada app. Inventário por app em `docs/BASELINE-FUTOS.md`.
- [x] F0-02 Rodar os testes atuais do motor no Linux e registrar versão/resultado. Swift 5.9 via Docker: 159 testes aprovados.
- [x] F0-03 Verificar build e UI tests iPhone no macOS/GitHub Actions. Build 5: iPhone e iPad aprovados.
- [x] F0-04 Capturar uma carreira nova, uma em andamento e uma no fim da temporada. Rotas `select`, `home` e `season-end` cobrem carreira nova, em andamento e fim de temporada.
- [x] F0-05 Classificar problemas confirmados por severidade e reprodução; separar ideias de bugs. Problemas classificados por severidade em `docs/BASELINE-FUTOS.md`.
- [x] F0-06 Confirmar ritmo de tempo, foco esportivo/narrativo e papel do Palpite+. Decisões de ritmo, foco, Palpite+ e delegação registradas em `docs/BASELINE-FUTOS.md`.
- [x] F0-07 Selecionar saves de referência para testar migração e retomada. Seis saves de referência e um save legado testados (`FootballReferenceSavesTests`).

**Meta M0:** baseline reproduzível, decisões registradas e nenhuma falha crítica conhecida sem encaminhamento.

### F1 — Fundação compartilhada

**Objetivo:** um fato do mundo pode gerar vários retornos, sem duplicar sua consequência.

- [x] F1-01 Modelar fatos importantes com ID estável, origem, data de jogo e entidades envolvidas. `WorldFact` com ID estável, origem, dia, atletas/clubes envolvidos e confiabilidade (`FootballFacts`). Suíte 218/218 no Docker.
- [x] F1-02 Definir resultado de decisão: efeitos aplicados, compromissos criados e próximos acontecimentos. `WorldFact` guarda efeitos, compromissos criados e próximos acontecimentos; usado em promessas. Suíte 235/235 no Docker.
- [x] F1-03 Definir compromissos e ações agendadas com prazo, estado e conclusão única. `Commitment` com prazo, estado e conclusão única (`FootballCommitments`); aparece na agenda. Suíte 218/218 no Docker.
- [x] F1-04 Processar vencimentos em uma ordem explícita ao avançar o calendário. Ordem explícita `CalendarStep` e `processDueItems()`; repetir não muda nada. Suíte 218/218 no Docker.
- [x] F1-05 Criar destinos de navegação que incluam app, seção e entidade específica. Itens da agenda carregam `entityID` e `section`; compromisso abre o atleta direto. Suíte 218/218 no Docker.
- [x] F1-06 Persistir novidade lida, resolvida e dispensada sem confundir esses estados. Estados lida/resolvida/dispensada separados (`messageState`, `dismissMessage`). Suíte 218/218 no Docker.
- [x] F1-07 Definir retenção de históricos para não crescer indefinidamente. Retenção: 150 fatos, 12 memórias por atleta, 60 compromissos. Suíte 218/218 no Docker.
- [x] F1-08 Introduzir versão de save e migração para os campos realmente implementados. Versão 11, campos opcionais e testes de compatibilidade aprovados.
- [x] F1-09 Verificar reabertura, repetição de comando, salto de calendário e determinismo. Testes de reabertura, repetição de comando, salto de calendário e determinismo. Suíte 218/218 no Docker.

**Meta M1:** um evento piloto chega a Mensagens, Chuteira e Notificações com o mesmo ID de origem; sua consequência ocorre uma única vez após salvar/carregar.

### F2 — Primeira entrega vertical: semana de jogo

**Objetivo:** dar profundidade ao ciclo principal antes de expandir todos os sistemas.

- [x] F2-01 Escolher um cenário: reserva pede minutos antes de uma partida importante.
- [x] F2-02 Mostrar pedido em Mensagens e necessidade de decisão no Gestor.
- [x] F2-03 Permitir resposta com alternativas e prazo de compromisso. Prometer ou recusar; resposta persistente.
- [x] F2-04 Acessar diretamente o atleta e a escalação pela conversa. Botões Ver atleta e Escalação na mensagem de pedido de minutos.
- [x] F2-05 Preparar a partida usando relatório do rival e condição dos atletas. Jornada UI aprovada.
- [x] F2-06 Contabilizar presença e resultado usando dados da partida efetivamente jogada. Testes de partida e promessas aprovados.
- [x] F2-07 Avaliar promessa, moral e relação ao vencer o prazo. Veredito cumprida/parcial/quebrada/justificada; moral por profissionalismo, relação com o empresário, lesão não pesa. `FootballPromiseOutcomeTests`.
- [x] F2-08 Produzir resposta do atleta, resumo do Gestor e repercussão pública somente quando justificável. Fala do atleta e consequências na mensagem; notícia pública só para craque (top 5) com profissionalismo baixo.
- [x] F2-09 Mostrar pendências que expiram antes de confirmar avanço rápido. Agenda com prazos e confirmação integrada.
- [x] F2-10 Verificar cumprir, quebrar, recusar e ignorar o pedido, inclusive após reabrir o app. Pedido ignorado por 3 dias de jogo cobra moral -4 uma vez; testes de save/reabertura. Suíte 177/177 no Docker swift:5.9.

**Meta M2:** uma jornada conectada entre Gestor, Mensagens, Tática e relatório pós-jogo, com retorno compreensível e persistente.

### F3 — Pessoas, memória e mercado

**Objetivo:** substituir relações genéricas e acordos instantâneos por processos com continuidade.

- [x] F3-01 Acrescentar memória de conversas e compromissos aos personagens do piloto. Memória por atleta e confiança derivada (`FootballMemory`). Suíte 218/218 no Docker.
- [x] F3-02 Introduzir interesses e preferências observáveis, sem personalidade aleatória a cada conversa. Interesses estáveis e observáveis por atleta (`interests(of:)`). Suíte 218/218 no Docker.
- [x] F3-03 Criar negociação em etapas: consulta, proposta, contraproposta, acordo/recusa/expiração. Negociação em etapas consulta/proposta/contraproposta/acordo/recusa/expiração (`FootballNegotiation`). Suíte 218/218 no Docker.
- [x] F3-04 Integrar interesse do atleta, papel no elenco e condições financeiras. Confiança, interesse principal, papel no elenco e caixa entram na pedida. Suíte 218/218 no Docker.
- [x] F3-05 Adicionar concorrência por uma contratação e alternativas de recrutamento. Rival disputa o alvo com prazo, alternativas da mesma posição e memória `lostToRival` (`FootballRivalCompetition`, sessão 01); 5 testes.
- [x] F3-06 Conectar imprensa e rede social a fatos públicos, com fonte e confiabilidade. Fatos públicos viram post na Chuteira com fonte e confiabilidade (confirmado/boato). Suíte 218/218 no Docker.
- [x] F3-07 Implementar follow-up de uma crise e de uma promessa quebrada. Promessa quebrada gera conversa de acompanhamento com prazo, memória e pedido de saída; crise genérica ainda pendente. Suíte 218/218 no Docker.

**Meta M3:** contratar um atleta e resolver uma relação exigem escolhas contextualizadas; os participantes lembram o acordo.

### F4 — Projetos, economia e vida

**Objetivo:** criar decisões de médio prazo e fazer dinheiro, tempo e energia terem usos concorrentes.

- [x] F4-01 Exibir projeção de caixa incluindo compromissos já assumidos. Projeção de caixa com compromissos (`FootballCashProjection`); sessão 01, 6 testes. Suíte 218/218 no Docker.
- [x] F4-02 Criar um projeto comercial com briefing, duração e avaliação posterior. Coleção da loja como projeto com briefing, duração e avaliação (`FootballCommercialProjects`); sessão 01, 6 testes. Suíte 218/218 no Docker.
- [x] F4-03 Criar uma reunião de diretoria com pedido e resposta futura. Reunião de diretoria com pedido e resposta futura (`FootballBoardMeetings`); sessão 01, 7 testes. Suíte 218/218 no Docker.
- [x] F4-04 Integrar atividades pessoais numa agenda com conflitos claros. Plano de até 6 dias com conflitos e avisos (`FootballPersonalAgenda`, sessão 01); domínio 8 testes, UI aguarda build iOS. Verificado em captura (`personal-plan`, `project-ledger`).
- [x] F4-05 Permitir delegar uma rotina com custo, limite e relatório. Delegação ao gerente comercial (`FootballCommercialDelegation`, sessão 01); domínio 6 testes.
- [x] F4-06 Balancear retornos para evitar combinações de ações sem custo que dominem a carreira. Balanceamento: promoção da loja, aportes repetidos e atividades pagas (`FootballBalance`, sessão 01); 6 testes.
- [x] F4-07 Verificar comportamento em troca de clube, demissão e nova temporada. Troca de clube, demissão e nova temporada sem herdar projetos do clube antigo (`FootballClubTransition`, sessão 01).

**Meta M4:** jogador consegue planejar um projeto, acompanhar custos e observar efeitos durante vários dias de jogo.

### F5 — Amplitude dos 18 apps

**Objetivo:** completar as categorias abaixo com identidade própria e integração.

- [ ] F5-01 Revisar apps contra seus critérios de aceite individuais.
- [ ] F5-02 Completar Liga, Rodada e Palpite+ como experiências de análise e acompanhamento.
- [ ] F5-03 Completar Metas e Troféus como planejamento e memória da carreira.
- [ ] F5-04 Refinar FutOS: busca, notificações, retomada e acessibilidade.
- [ ] F5-05 Remover caminhos redundantes que confundam a função de cada app.

**Meta M5:** 18 apps revisados; cada um tem um propósito demonstrável e o jogador não precisa visitar todos para avançar.

### F6 — Estabilização e carreira longa

**Objetivo:** verificar coerência, balanceamento e usabilidade ao longo das temporadas.

- [x] F6-01 Simular pelo menos 10 temporadas em múltiplas sementes e dificuldades. Teste de 3 sementes × 10 temporadas em dificuldades diferentes (`FootballLongCareerTests`), sem fato/compromisso duplicado.
- [x] F6-02 Cobrir troca de clube, demissão, aposentadorias, contratos e projetos vencidos. Carreiras de 10 temporadas com demissão, troca de clube, contratos e conversas vencidas (`FootballLongCareerTests`).
- [x] F6-03 Testar migração, round-trip de save e retomada nos pontos de decisão. Round-trip de save e saves antigos sem os campos novos testados em cada sistema.
- [x] F6-04 Verificar limites de histórico, tempo de processamento e tamanho de save. Save de ~520 KB após 10 temporadas; retenção de fatos (150), memórias (12/atleta), compromissos (60) e caixa de entrada (80).
- [ ] F6-05 Executar jornadas UI no iPhone e revisar capturas reais; validar iPad para layouts alterados.
- [ ] F6-06 Fazer playtest e registrar decisões entendidas, confusas e repetitivas.
- [ ] F6-07 Corrigir falhas críticas e atualizar baseline, backlog e próximos marcos.

**Meta M6:** carreira multitemporada sem consequência duplicada, compromisso órfão ou falha crítica confirmada pendente.

## 4. Categorias e microações por app

As fases indicam quando começar. Concluir uma fase não implica concluir automaticamente todas as expansões de um app.

### 01 — Gestor | F2

**Objetivo:** ajudar o treinador a priorizar a semana.

- [x] GES-01 Organizar pendências por prazo, importância e responsável. Agenda ordenável por prazo, importância e responsável (`FootballManagerBoard`); testes de domínio.
- [x] GES-02 Exibir compromissos e preparação do próximo jogo numa agenda. Preparação do próximo jogo com checklist (rival, escalação, condição, estilo, promessas, coletiva).
- [x] GES-03 Mostrar o que vence antes do próximo avanço de calendário. Itens que vencem antes do próximo avanço, do mais importante ao menos.
- [x] GES-04 Criar resumo pós-jogo com mudanças e causas, não apenas números finais. Resumo pós-jogo com mudanças, causas, números do jogo e atenção (`FootballPostMatchSummary`); verificado em captura.
- [x] GES-05 Permitir avanço rápido até decisões escolhidas pelo jogador. O avanço rápido para só onde o jogador escolheu (pausas de decisões, lesões, coletiva e propostas em Ajustes); `FootballAdvancePausesTests`.

**Aceite:** jogador identifica o que exige atenção agora e consegue abrir o assunto específico em um toque.

### 02 — Tática | F2, expansão F4

**Objetivo:** preparar, executar e avaliar um plano de jogo.

- [x] TAC-01 Salvar planos A/B com escalação e instruções. Planos A/B salvos, aplicados antes do jogo e trocados ao vivo (`FootballTacticalPlans`); verificado em captura.
- [x] TAC-02 Comparar preparo físico, funções e ameaças observadas do rival. Comparativo do rival com ameaças observadas ou estimadas (`FootballMatchPreparation`, sessão 01).
- [x] TAC-03 Relacionar treino e rotação ao calendário e às promessas aos atletas. Desgaste projetado, promessas com prazo e foco de treino sugerido (sessão 01).
- [x] TAC-04 Implementar um conjunto inicial de bolas paradas com efeito no motor. Rotinas de bola parada com efeito no motor, calibração preservada (`FootballSetPieces`, sessão 01); 5 testes.
- [x] TAC-05 Vincular explicações pós-jogo aos dados reais; evitar atribuir causalidade que o motor não registra. Resumo traz só números e sequências registrados; mudanças táticas aparecem como sequência, não causa.

**Aceite:** duas escolhas táticas plausíveis têm trade-offs verificáveis; nenhum controle novo é apenas decorativo.

### 03 — Liga | F5

**Objetivo:** transformar números do campeonato em informação útil.

- [ ] LIG-01 Abrir ficha do clube ao tocar na tabela ou na busca.
- [ ] LIG-02 Abrir relatório de uma partida e ficha do atleta na artilharia.
- [ ] LIG-03 Navegar por rodadas anteriores e futuras.
- [x] LIG-04 Exibir confronto direto, forma e dificuldade do calendário. Domínio testado (`FootballLeagueAnalysis`, sessão 18); UI aguarda build iOS. Verificado em captura (`league-insight`).
- [x] LIG-05 Mostrar cenários matemáticos de acesso, título e rebaixamento quando aplicáveis. Domínio testado (sessão 18); UI aguarda build iOS. Verificado em captura (`league-insight`).

**Aceite:** analisar o próximo rival e localizar uma partida histórica sem sair para uma lista genérica.

### 04 — Transfer | F3

**Objetivo:** recrutar por necessidade e negociar com informação imperfeita.

- [x] TRF-01 Criar briefing de contratação: posição, perfil, orçamento e papel esperado. Transfer (sessão 01): briefing, relatórios e negociação em etapas; captura verificada.
- [x] TRF-02 Salvar filtros e listas comparativas de candidatos. Transfer (sessão 01): briefing, relatórios e negociação em etapas; captura verificada.
- [x] TRF-03 Mostrar conhecimento, data e confiabilidade dos relatórios. Transfer (sessão 01): briefing, relatórios e negociação em etapas; captura verificada.
- [x] TRF-04 Negociar taxa, duração, salário e papel por etapas. Transfer (sessão 01): briefing, relatórios e negociação em etapas; captura verificada.
- [x] TRF-05 Processar contrapropostas, concorrência e expiração pelo calendário. Transfer (sessão 01): briefing, relatórios e negociação em etapas; captura verificada.
- [x] TRF-06 Validar custo total no Banco e registrar acordo no histórico. Transfer (sessão 01): briefing, relatórios e negociação em etapas; captura verificada.

**Aceite:** contratação completa atravessa observação, negociação e registro; orçamento e folha nunca são cobrados duas vezes.

### 05 — Clube | F4

**Objetivo:** governar um projeto esportivo com a diretoria.

- [x] CLB-01 Separar avaliação esportiva, financeira e institucional. Clube/Banco (sessão 01): testes de domínio e build iOS.
- [x] CLB-02 Criar reunião contextual com pedido de verba ou revisão de meta. Reunião contextual com a diretoria (sessão 01). Suíte 218/218 no Docker.
- [x] CLB-03 Registrar resposta, condições e prazo da diretoria. Resposta, condições e prazo da diretoria (sessão 01). Suíte 218/218 no Docker.
- [x] CLB-04 Acompanhar obra por etapas com custos e impacto durante execução. Clube/Banco (sessão 01): testes de domínio e build iOS.
- [x] CLB-05 Dar tarefas e relatórios à comissão; incluir delegação inicial. Tarefas e relatórios da comissão técnica (`FootballStaffTasks`, sessão 01); testes de domínio.
- [ ] CLB-06 Consolidar legado e convites; mover gestão de saves para Ajustes.

**Aceite:** uma promessa à diretoria é acompanhada e avaliada, inclusive ao trocar de temporada.

### 06 — Mensagens | F2/F3

**Objetivo:** ser a interface de conversas e acordos da carreira.

- [x] MSG-01 Agrupar mensagens por conversa, pessoa e assunto. Mensagens agrupadas por pessoa ou assunto (`FootballConversations`); seletor Por conversa verificado em captura.
- [x] MSG-02 Abrir conversa específica por notificação. Assunto individual acionável; threads completas ainda pertencem a MSG-01/04.
- [x] MSG-03 Marcar leitura por conversa em vez de ler toda a inbox ao abrir o app. Leitura individual por mensagem; UI contextual e teste de domínio aprovados.
- [x] MSG-04 Adicionar respostas contextuais e follow-ups agendados. Responder pedido marcando conversa (compromisso na agenda, cobrança se esquecida) e botão Ter a conversa.
- [x] MSG-05 Distinguir lida, respondida, resolvida e expirada. Estados nova, lida, respondida, resolvida, sem resposta e dispensada.
- [x] MSG-06 Consultar promessas e anexos: ficha, proposta, relatório ou contrato. Anexos de ficha, escalação, proposta, contrato, compromisso e origem; verificado em captura.

**Aceite:** retomar uma conversa preserva respostas, prazo e compromisso; o histórico explica o desfecho.

### 07 — Chuteira | F3

**Objetivo:** simular uma esfera pública que reage ao mundo.

- [x] CHU-01 Criar perfis persistentes de personagens e clubes. Perfis persistentes de clubes, jornalistas, comentaristas, torcida e craques (`FootballPublicSphere`).
- [x] CHU-02 Associar postagens a fatos, rumores e fontes. Posts ligados a fatos com fonte e confiabilidade (confirmado, boato, desmentido); credibilidade do veículo muda com o desfecho.
- [x] CHU-03 Compor publicação escolhendo assunto, alvo e tom com prévia. Compor por assunto, alvo e tom com prévia determinística de texto, alcance, risco e efeitos.
- [x] CHU-04 Implementar respostas em thread e reações persistentes. Comentários em thread e resposta do treinador (calma ou rebater) persistidos.
- [x] CHU-05 Atualizar engajamento por etapas, sem sortear novamente ao abrir a tela. Engajamento por etapas (inicial, parcial, final) sem novo sorteio ao abrir a tela.
- [x] CHU-06 Conectar crises e publis a consequências futuras e memória pública. Memória pública: post polêmico antigo pode voltar numa crise; excesso de publis reduz propostas de marca.

**Aceite:** uma fala repercute de forma coerente em público, diretoria ou elenco; não há resposta repetível para farmar bônus.

### 08 — Palpite+ | F5

**Objetivo:** oferecer prognósticos opcionais com análise e acompanhamento.

- [x] PAL-01 Confirmar papel do app antes de ampliar suas regras. Palpite+ (sessão 18, `FootballBettingInsight`): domínio testado e tela capturada (`betting-insight`).
- [x] PAL-02 Exibir dados públicos de forma, desfalques e confrontos. Palpite+ (sessão 18, `FootballBettingInsight`): domínio testado e tela capturada (`betting-insight`).
- [x] PAL-03 Persistir rascunho do bilhete e mostrar fechamento do mercado. Palpite+ (sessão 18, `FootballBettingInsight`): domínio testado e tela capturada (`betting-insight`).
- [x] PAL-04 Abrir detalhe do bilhete com partidas e justificativa da liquidação. Palpite+ (sessão 18, `FootballBettingInsight`): domínio testado e tela capturada (`betting-insight`).
- [x] PAL-05 Criar perfis de palpiteiros e histórico comparável de acertos. Palpite+ (sessão 18, `FootballBettingInsight`): domínio testado e tela capturada (`betting-insight`).
- [x] PAL-06 Preservar separação entre fichas, dinheiro pessoal e caixa do clube. Palpite+ (sessão 18, `FootballBettingInsight`): domínio testado e tela capturada (`betting-insight`).

**Aceite:** cada resultado é rastreável ao jogo real da carreira e liquidado uma vez; participação é opcional.

### 09 — Rodada | F5

**Objetivo:** montar uma estratégia fantasy a cada rodada.

- [x] ROD-01 Mostrar prazo de fechamento, jogos e disponibilidade dos atletas. Rodada (sessão 18, `FootballFantasyInsight`): domínio testado e tela capturada (`fantasy-insight`).
- [x] ROD-02 Filtrar por preço, forma, confronto e risco de ausência. Rodada (sessão 18, `FootballFantasyInsight`): domínio testado e tela capturada (`fantasy-insight`).
- [x] ROD-03 Persistir rascunho e permitir comparar escolhas de capitão. Rodada (sessão 18, `FootballFantasyInsight`): domínio testado e tela capturada (`fantasy-insight`).
- [ ] ROD-04 Exibir pontuação por atleta e componente após a rodada.
- [ ] ROD-05 Criar liga privada fictícia com personagens recorrentes.
- [ ] ROD-06 Compartilhar resultado no Chuteira sem duplicar recompensas.

**Aceite:** jogador entende como cada atleta pontuou e por que sua decisão teve resultado diferente dos rivais.

### 10 — Vida | F4

**Objetivo:** dar significado a tempo, energia e trajetória pessoal.

- [x] VID-01 Planejar atividades com duração, energia e conflitos. Vida (sessão 01): agenda pessoal e continuidade; testes de domínio e build iOS.
- [x] VID-02 Criar continuidade para curso, livro e compromissos de mídia. Vida (sessão 01): agenda pessoal e continuidade; testes de domínio e build iOS.
- [x] VID-03 Associar descanso e apoio pessoal ao contexto da semana. Vida (sessão 01): agenda pessoal e continuidade; testes de domínio e build iOS.
- [x] VID-04 Mostrar custos recorrentes dos bens e uso contextual de suas vantagens. Vida (sessão 01): agenda pessoal e continuidade; testes de domínio e build iOS.
- [x] VID-05 Manter Vida disponível em períodos sem clube e revisar restrições atuais. Vida (sessão 01): agenda pessoal e continuidade; testes de domínio e build iOS.
- [x] VID-06 Exibir histórico de decisões pessoais e bem-estar. Vida (sessão 01): agenda pessoal e continuidade; testes de domínio e build iOS.

**Aceite:** escolher um compromisso deixa explícito o que será adiado ou sacrificado; ficar desempregado não paralisa a vida.

### 11 — Negócios | F4

**Objetivo:** gerir projetos comerciais com acompanhamento.

- [x] NEG-01 Definir coleção com público, preço, investimento e duração. Coleção com público, preço, investimento e duração (sessão 01). Suíte 218/218 no Docker.
- [x] NEG-02 Exibir demanda e relatório de vendas ao longo dos jogos. Demanda e relatório de vendas ao longo dos jogos (sessão 01). Suíte 218/218 no Docker.
- [x] NEG-03 Negociar naming rights com condições financeiras e reação da torcida. Naming rights negociado (sessão 01, `FootballBusinessDeals`); testes de domínio.
- [x] NEG-04 Transformar projeto social em etapas com resultados registrados. Projeto social em etapas com balanço (sessão 01); testes de domínio.
- [x] NEG-05 Agendar amistoso/turnê antes da execução, incluindo desgaste e receita. Amistoso e excursão agendados com receita e desgaste previstos (sessão 01); testes de domínio.
- [x] NEG-06 Mostrar retorno realizado versus previsto de cada projeto. Verificado em captura (`personal-plan`, `project-ledger`).

**Aceite:** pelo menos um projeto exige planejamento, acompanhamento e avaliação final; receita não é bônus instantâneo sem contexto.

### 12 — Metas | F5

**Objetivo:** apoiar prioridades escolhidas e compromissos do mundo.

- [x] MET-01 Identificar origem: jogador, diretoria, atleta ou personagem. Metas (sessão 18, `FootballGoals`): domínio testado e tela capturada (`goals-origin`).
- [x] MET-02 Permitir escolher e acompanhar um conjunto limitado de metas pessoais. Metas (sessão 18, `FootballGoals`): domínio testado e tela capturada (`goals-origin`).
- [x] MET-03 Abrir a ação contextual que ajuda a cumprir cada meta. Metas (sessão 18, `FootballGoals`): domínio testado e tela capturada (`goals-origin`).
- [x] MET-04 Exibir eventos que contribuíram para o progresso. Metas (sessão 18, `FootballGoals`): domínio testado e tela capturada (`goals-origin`).
- [x] MET-05 Registrar conclusão, falha e substituição sem perder histórico. Metas (sessão 18, `FootballGoals`): domínio testado e tela capturada (`goals-origin`).

**Aceite:** progresso corresponde a ações reais; recompensas são únicas e metas não incentivam cliques sem propósito.

### 13 — Troféus | F5

**Objetivo:** preservar memória afetiva e legado.

- [x] TRO-01 Registrar data, clube, partida e participantes do desbloqueio. Troféus (sessão 18, `FootballLegacy`): domínio testado e tela capturada (`trophy-legacy`).
- [x] TRO-02 Abrir o contexto histórico da conquista. Troféus (sessão 18, `FootballLegacy`): domínio testado e tela capturada (`trophy-legacy`).
- [x] TRO-03 Exibir progresso verificável de conquistas em andamento. Troféus (sessão 18, `FootballLegacy`): domínio testado e tela capturada (`trophy-legacy`).
- [x] TRO-04 Criar linha do tempo de títulos, recordes e temporadas. Troféus (sessão 18, `FootballLegacy`): domínio testado e tela capturada (`trophy-legacy`).
- [x] TRO-05 Permitir escolher destaques do perfil e compartilhar um marco. Troféus (sessão 18, `FootballLegacy`): domínio testado e tela capturada (`trophy-legacy`).

**Aceite:** uma conquista pode ser revisitada com seu contexto original mesmo após mudança de clube.

### 14 — Alertas | F3

**Objetivo:** acompanhar acontecimentos com continuidade.

- [x] ALE-01 Criar um arco piloto com início, atualização, decisão e encerramento. Arco piloto de boato (`FootballArcs`): início, atualização, decisão e encerramento.
- [x] ALE-02 Mostrar participantes, origem, confiabilidade e prazo. Participantes, origem, confiabilidade e prazo visíveis no painel de arcos.
- [x] ALE-03 Permitir pedir informação ou delegar quando o contexto comportar. Pedir informação ao empresário (uma vez) e delegar, com efeito dependente da relação.
- [x] ALE-04 Fazer a omissão gerar um desfecho registrado. Omissão no prazo gera desfecho registrado (atleta pede para sair se o boato era verdadeiro).
- [x] ALE-05 Consultar cadeia de acontecimentos e efeitos posteriores. Cadeia de acontecimentos de cada arco consultável.

**Aceite:** o arco tem ao menos dois desfechos significativos e comportamento definido se o jogador não responder.

### 15 — Marca | F4

**Objetivo:** gerir reputação, torcida e acordos de comunicação.

- [x] MAR-01 Separar imagem do treinador, força da marca e humor da torcida. Marca (sessão 01, `FootballBrandImage`): testes de domínio e build iOS.
- [x] MAR-02 Definir campanha com objetivo, público, orçamento e prazo. Marca (sessão 01, `FootballBrandImage`): testes de domínio e build iOS.
- [x] MAR-03 Negociar contrato comercial com obrigações verificáveis. Marca (sessão 01, `FootballBrandImage`): testes de domínio e build iOS.
- [x] MAR-04 Mostrar evolução por período e fatos que contribuíram para ela. Marca (sessão 01, `FootballBrandImage`): testes de domínio e build iOS.
- [x] MAR-05 Avaliar campanha e refletir resultado em demanda e propostas futuras. Marca (sessão 01, `FootballBrandImage`): testes de domínio e build iOS.

**Aceite:** jogador consegue explicar a mudança de imagem por acontecimentos observáveis, não por um número opaco.

### 16 — Banco | F4

**Objetivo:** planejar obrigações futuras e separar patrimônios.

- [x] BAN-01 Separar conta do clube e conta pessoal, com extratos completos. Clube/Banco (sessão 01): testes de domínio e build iOS.
- [x] BAN-02 Exibir recebíveis, despesas contratadas e vencimentos. Recebíveis, despesas contratadas e vencimentos na projeção (sessão 01). Suíte 218/218 no Docker.
- [x] BAN-03 Simular contratação/obra antes de assumir compromisso. Clube/Banco (sessão 01): testes de domínio e build iOS.
- [x] BAN-04 Mostrar cenários e premissas da projeção, distinguindo garantido de estimado. Cenários e premissas, garantido × estimado (sessão 01). Suíte 218/218 no Docker.
- [x] BAN-05 Formalizar empréstimo do treinador com saldo e condições de devolução. Clube/Banco (sessão 01): testes de domínio e build iOS.
- [x] BAN-06 Abrir o fato ou contrato associado a cada lançamento. Clube/Banco (sessão 01): testes de domínio e build iOS.

**Aceite:** saldo e extrato reconciliam; nenhuma transferência entre contas cria ou elimina dinheiro indevidamente.

### 17 — Contatos | F3

**Objetivo:** construir relações recíprocas com pessoas persistentes.

- [x] CON-01 Abrir ficha específica pela busca e por mensagens. Mensagens do empresário abrem o cartão de contato; ficha por busca já existia.
- [x] CON-02 Registrar temas, histórico, interesses e promessas. Contatos (sessão 01, `FootballContactRelations`): testes de domínio e captura gerada.
- [x] CON-03 Oferecer conversa contextual em vez de uma única ação genérica por papel. Contatos (sessão 01, `FootballContactRelations`): testes de domínio e captura gerada.
- [x] CON-04 Permitir que o contato proponha oportunidade ou peça ajuda. Contatos (sessão 01, `FootballContactRelations`): testes de domínio e captura gerada.
- [x] CON-05 Integrar confiança a preço, conselho e resposta institucional de forma explicável. Contatos (sessão 01, `FootballContactRelations`): testes de domínio e captura gerada.
- [x] CON-06 Tratar mudança de presidente/empresário e continuidade de família/amigo ao trocar de clube. Contatos (sessão 01, `FootballContactRelations`): testes de domínio e captura gerada.

**Aceite:** relação evolui por acontecimentos e compromissos; não basta repetir o mesmo almoço para obter todos os benefícios.

### 18 — Ajustes | F1/F5

**Objetivo:** controlar a experiência do FutOS e da simulação.

- [ ] AJU-01 Centralizar saves, nova carreira, importação/exportação se incluídas no escopo.
- [x] AJU-02 Configurar notificações por prioridade e tipo. Ajustes (sessão 18): preferências testadas e tela capturada (`settings-phone`).
- [x] AJU-03 Configurar pausas do avanço rápido e níveis de delegação. Ajustes (sessão 18): preferências testadas e tela capturada (`settings-phone`).
- [x] AJU-04 Adicionar preferências de acessibilidade e reduzir movimento. Ajustes (sessão 18): preferências testadas e tela capturada (`settings-phone`).
- [x] AJU-05 Separar ferramentas de configuração de tarefas de gestão do clube. Ajustes (sessão 18): preferências testadas e tela capturada (`settings-phone`).
- [x] AJU-06 Mostrar regras ativas dos desafios e mudanças de dificuldade. Ajustes (sessão 18): preferências testadas e tela capturada (`settings-phone`).

**Aceite:** preferências sobrevivem à reabertura e não alteram silenciosamente as regras de um desafio.

## 5. FutOS — integração transversal

- [x] OS-01 Permitir abrir o destino específico ao tocar em aviso da tela de bloqueio. FutOS (sessão 18): estado persistente testado e telas conferidas; UITests F5 passando no iPhone.
- [x] OS-02 Ordenar notificações por prioridade e vencimento reais. FutOS (sessão 18): estado persistente testado e telas conferidas; UITests F5 passando no iPhone.
- [x] OS-03 Fazer busca abrir clube, contato, atleta e seção exatos. FutOS (sessão 18): estado persistente testado e telas conferidas; UITests F5 passando no iPhone.
- [x] OS-04 Distinguir selos de novidade de contadores de tarefas ativas. FutOS (sessão 18): estado persistente testado e telas conferidas; UITests F5 passando no iPhone.
- [ ] OS-05 Preservar aba, rolagem e rascunho ao alternar apps quando relevante.
- [x] OS-06 Oferecer feedback contextual de ação e histórico persistente do resultado. FutOS (sessão 18): estado persistente testado e telas conferidas; UITests F5 passando no iPhone.
- [x] OS-07 Explicar bateria/energia e sinal/humor com acessibilidade equivalente. FutOS (sessão 18): estado persistente testado e telas conferidas; UITests F5 passando no iPhone.
- [ ] OS-08 Verificar retorno de sheets, partida ao vivo e destinos aninhados.
- [ ] OS-09 Padronizar estados vazios úteis: informar quando e como haverá conteúdo.

**Meta:** navegar no celular parece acompanhar uma carreira; uma notificação não obriga a procurar novamente o assunto dentro do app.

## 5b. Ciclo 2 — Mercado, Base, Banco e Narrativa

Pontos de partida levantados no código em outubro de 2026. Cada bloco é uma frente independente: abrir uma branch por frente e validar no CI antes de unir.

### 19 — Mercado | ciclo 2

**Objetivo:** comprar e vender com informação, escolha e risco, sem gargalos de tela.

Hoje: cinco abas (Livres, Clubes, Olheiros, Base, Histórico), proposta direta, negociação em etapas, empréstimos, olheiros e briefings. Faltam busca e ordenação; a aba Clubes mostra só os 30 melhores e a Livres só 40; o bônus por gols é fixo em 10; o empréstimo custa 8% fixos; há dois caminhos de compra que se sobrepõem.

- [ ] MER-01 Busca por nome e ordenação por geral, potencial, idade, valor e fim de contrato nas abas Livres e Clubes, com paginação no lugar dos tetos de 30 e 40.
- [ ] MER-02 Filtros por idade, faixa de valor, fim de contrato, região e divisão, salvos por aba.
- [ ] MER-03 Cláusulas de contrato: multa rescisória, percentual de revenda, direito de recompra e bônus por jogos e por gols configuráveis.
- [ ] MER-04 Empréstimo negociado: taxa, divisão de salário, opção ou obrigação de compra, em vez dos 8% fixos.
- [ ] MER-05 Unificar o caminho de compra: o toque único da aba Livres e a proposta direta seguem as mesmas etapas, ou deixam claro quando pulam alguma.
- [ ] MER-06 Concorrência real: clubes rivais disputam o mesmo alvo, o jogador compara propostas e existe comissão de agente.
- [ ] MER-07 Ficha de transferência: histórico de valor, comparação lado a lado e custo real (taxa, salário, bônus e agente) antes de fechar.
- [ ] MER-08 Venda ativa: listar atleta com preço pedido, receber ofertas com contraproposta e prazo.

**Aceite:** achar um alvo em menos de três toques; o custo total mostrado é exatamente o que o Banco lança; nenhuma cláusula cria ou apaga dinheiro sem lançamento.

### 20 — Base (categorias) | ciclo 2

**Objetivo:** a base vira uma história própria, com categorias, jogos e promessas que crescem.

Hoje: jovens são atletas com um marcador de base; há um único grupo de até 12 com divisão apenas de exibição entre Sub-17 e Sub-20, entrada anual de 3 a 5, peneira uma vez por temporada, Copinha simulada por força média, e a tela vive dentro do Transfer. Não há Sub-15, jogos de base, empréstimo ou venda de jovens.

- [ ] BAS-01 Tela dedicada à Academia no app Clube: visão geral, nível, treinadores, orçamento e melhorias.
- [ ] BAS-02 Categorias reais Sub-15, Sub-17 e Sub-20, cada uma com elenco, treinador e capacidade próprios.
- [ ] BAS-03 Competições de base: campeonato por categoria e Copinha jogável; jovens ganham minutos e evoluem pelos jogos.
- [ ] BAS-04 Promoção entre categorias com avaliação periódica e decisão do treinador: promover, manter, emprestar ou dispensar.
- [ ] BAS-05 Contratos e bolsas de base, empréstimo a clubes menores e venda com percentual de revenda.
- [ ] BAS-06 Relatórios individuais e olheiros da base: potencial estimado com ruído, traços e perfil do jovem; as joias ganham narrativa própria.
- [ ] BAS-07 Peneiras em várias regiões e parcerias com escolas e clubes, com custo e retorno visíveis.
- [ ] BAS-08 Saída com compensação no lugar da remoção instantânea; o destino do jovem reaparece no futuro, como rival ou ídolo.

**Aceite:** acompanhar um jovem de 15 a 20 anos até a promoção, a venda ou a dispensa, com histórico legível; ninguém passa de categoria sem registro.

### 21 — Banco | refinamento, ciclo 2

**Objetivo:** o Banco deixa de ser uma lista de linhas e passa a responder "estou bem ou mal, e por quê?".

Hoje: projeção com gráfico, simulador de contratação ou obra, extratos do clube e do treinador, empréstimos do treinador, juros e bloqueio de contratações no vermelho, teto salarial. Os painéis de categoria e de mês são texto simples, o ícone de pizza não tem gráfico, o patrocínio fica fora do Banco, não há empréstimo bancário nem fair play, e o extrato não tem busca.

- [ ] BAN-07 Visão geral redesenhada: saldo, fôlego em meses, receitas e despesas do mês com tendência e alerta de risco.
- [ ] BAN-08 Gráficos reais: receita por origem em rosca, despesas por categoria, evolução do saldo e comparação entre temporadas.
- [ ] BAN-09 Orçamento dividido entre transferências, folha, estrutura e base, com meta e aviso ao estourar.
- [ ] BAN-10 Receitas por fonte (TV, bilheteria, sócios, patrocínio, naming, marca e vendas) com projeção e comparação com o ano anterior.
- [ ] BAN-11 Produtos financeiros: empréstimo bancário e cheque especial com juros, garantia e nota de crédito do clube ligada à diretoria.
- [ ] BAN-12 Fair play financeiro: limite de prejuízo e relação folha por receita, com aviso antes da punição.
- [ ] BAN-13 Extrato com busca e filtros por categoria, período e valor; resumo mensal para além de 700 lançamentos.
- [ ] BAN-14 Simulador em linguagem simples: modo básico ("posso contratar?") com resposta direta antes dos números, e modo detalhado.
- [ ] BAN-15 Estados vazios e textos refinados; gráficos com leitura por voz.

**Aceite:** em dez segundos o jogador diz se o clube está saudável e o que mais pesa; saldos e gráficos reconciliam com o extrato.

### 22 — Narrativa e viralização | ciclo 2

**Objetivo:** cada temporada deixa história para lembrar e motivo para mostrar a alguém.

- [ ] NAR-01 Treinador rival com nome, declarações na imprensa e rivalidade entre confrontos.
- [ ] NAR-02 Livro da carreira: gols decisivos, viradas, títulos e rebaixamentos viram cartões com uma linha de narração.
- [ ] NAR-03 Cartão de compartilhar com a carreira, os troféus e o craque eterno, reaproveitando o compartilhamento do Palpite+.
- [ ] NAR-04 Arcos de temporada: promessa da diretoria e cenas curtas ao longo das rodadas.
- [ ] NAR-05 Dilemas com consequência de longo prazo, que voltam temporadas depois.
- [ ] NAR-06 Evento do dia e gancho entre dias na tela de bloqueio.
- [ ] NAR-07 Desafio da semana com semente comum (exige servidor; avaliar antes de começar).

**Aceite:** ao fim de uma temporada o jogador gera um cartão que conta o que aconteceu, sem texto genérico.

### Sequência sugerida

1. Banco: BAN-07, BAN-08 e BAN-09 (alta visibilidade, risco baixo, só leitura).
2. Base: BAS-01, BAS-02 e BAS-04 (a tela dedicada e as categorias abrem o resto da frente).
3. Mercado: MER-01, MER-02 e MER-07 antes das cláusulas (MER-03 a MER-06), que mexem em regras e no Banco.
4. Narrativa: NAR-01, NAR-02 e NAR-03.

Frentes 2 e 3 alteram regras centrais e saves: cada mudança de modelo precisa de `decodeIfPresent` e teste de save antigo, como nas demais.

## 5c. Ciclo 2 — Organização dos apps, recompensas visuais e tela de bloqueio

Pontos de partida levantados no código em outubro de 2026.

### 23 — Pastas de apps e telas paginadas

**Objetivo:** o celular fica mais limpo e o app do time deixa de ser uma rolagem infinita.

Hoje: 18 apps em uma grade plana de 4 colunas, sem noção de pasta; o Gestor tem 766 linhas e cerca de 14 painéis empilhados; Tática junta escalação, plano, instruções, papéis e treino em uma só rolagem; a ficha do atleta tem 8 painéis; a galeria de Metas e as listas de agenda, mensagens e relatório de partida mostram tudo de uma vez.

- [ ] GRP-01 Criar o conceito de pasta no FutOS (`PhoneFolder`): ícone com miniaturas dos apps, abertura animada e selo que soma os avisos de todos os apps dentro dela.
- [ ] GRP-02 Pasta "Equipe": Tática e Clube, com Elenco como seção própria (hoje o elenco só existe dentro da Tática e da ficha do atleta).
- [ ] GRP-03 Demais pastas, a revisar com o jogador: Dinheiro (Banco, Negócios, Marca e Vida), Social (Chuteira, Contatos e Mensagens), Metas e Troféus, Jogos (Palpite+ e Rodada) e Mercado (Transfer e Liga). Apps de uso diário continuam soltos no dock.
- [ ] GRP-04 A busca do FutOS e os avisos continuam abrindo o destino exato dentro de uma pasta.
- [ ] GRP-05 Dividir o Gestor em abas ou páginas (Hoje, Agenda, Clube, Histórico), deixando no topo só o estado do dia e a próxima ação.
- [ ] GRP-06 Dividir a Tática em abas: Escalação, Plano de jogo, Papéis e Treino.
- [ ] GRP-07 Paginar ou agrupar listas longas: agenda, relatório de partida (resumo e "ver todos os lances"), galeria de Metas por categoria, atributos da ficha do atleta e listas do ritual de virada.
- [ ] GRP-08 Preservar a aba e a rolagem ao trocar de app (fecha o item OS-05).

**Aceite:** cada app abre mostrando o essencial sem rolar mais de duas telas; nenhum atalho existente perde o destino.

### 24 — Animações e recompensas visuais

**Objetivo:** vitórias, títulos e marcos dão uma pequena dose de prazer imediata, sem atrasar quem quer jogar.

Hoje: não há confete nem partículas em lugar nenhum. A vitória aparece só como o rótulo verde "VITÓRIA" na tela de bloqueio e nos cartões de fim de jogo, sem animação. O resumo da temporada é uma rolagem estática. As conquistas são calculadas, mas o resultado não chega à tela: não há aviso nem vibração. O pacote de craque eterno é o único reveal rico que existe.

- [ ] ANI-01 Componentes compartilhados de comemoração: confete e faíscas, brilho passando, contador numérico animado, pulso de ícone e vibração, todos respeitando "reduzir movimento" (o confete do app Hall das Lendas serve de base).
- [ ] ANI-02 Vitória: cartão de fim de jogo com entrada animada, placar que sobe, vibração de sucesso e confete leve.
- [ ] ANI-03 Goleada e vitória grande (saldo de 3 ou mais, virada, clássico ou título): versão maior, com confete, faixa "GOLEADA" e narração de uma linha.
- [ ] ANI-04 Derrota e rebaixamento sem comemoração, mas com transição própria, para o contraste valer.
- [ ] ANI-05 Resumo da temporada em cenas reveladas aos poucos (posição, prêmios, artilheiro, troféu), como o ritual de virada, com ápice no título ou no acesso.
- [ ] ANI-06 Encerrar temporada: transição própria ao fechar a temporada e ao abrir a nova.
- [ ] ANI-07 Microanimações de interface: botões com mola, listas que entram em cascata, números que contam, selos que pulsam ao ganhar aviso.
- [ ] ANI-08 Orçamento de movimento: nenhuma animação passa de 2,5 s sem poder ser tocada para pular; UI tests e capturas usam o estado final.

**Aceite:** qualquer animação pode ser pulada com um toque, nada trava o jogo, e a opção "reduzir movimento" troca tudo por estados finais.

### 25 — Marcos e conquistas

**Objetivo:** completar uma meta ou conquista é um acontecimento visível.

Hoje: `checkAchievements` devolve as conquistas novas ao fechar uma partida ou uma temporada, mas nada as mostra; Troféus é uma lista estática e as Metas só mudam de cor ao concluir.

- [ ] MRC-01 Fila de desbloqueios: guardar as conquistas e metas recém-concluídas e exibir uma faixa no topo do celular, uma por vez, com vibração e confete leve.
- [ ] MRC-02 Cartão de conquista com ícone, raridade e texto de uma linha; toque abre a conquista na galeria.
- [ ] MRC-03 Barras de progresso animadas nas Metas e contagem regressiva visual para o próximo marco.
- [ ] MRC-04 Marcos de carreira (primeira vitória, 10 vitórias, primeiro título, 100 jogos, craque eterno) com tela de comemoração própria e entrada no Livro da carreira (NAR-02).
- [ ] MRC-05 Galeria de Troféus com estados: bloqueado em silhueta, a meio caminho com progresso, desbloqueado com brilho; filtro por categoria.
- [ ] MRC-06 Recompensas concretas e pequenas por marco (energia, bônus de moral, cartão do dia extra), sem criar compra.

**Aceite:** nenhuma conquista é desbloqueada sem o jogador ver; a fila nunca empilha mais de um aviso ao mesmo tempo.

### 26 — Tela de bloqueio e ações diretas

**Objetivo:** responder e resolver pequenas coisas sem sair da tela de bloqueio.

Hoje: a tela mostra relógio, data, resumo da noite, próximo jogo, contadores, dica e as três primeiras notificações. Qualquer toque desbloqueia e abre o app; as notificações são calculadas a partir do estado (não há ação, resposta, adiar nem marcar como lida), e o Centro de Notificações é uma lista simples.

- [ ] TLB-01 Modelo de ação na notificação: cada aviso passa a carregar suas ações possíveis (responder, aceitar, recusar, adiar, marcar como lida).
- [ ] TLB-02 Resposta rápida a mensagens com as opções que o chat já tem, direto no aviso, e confirmação visual de que foi enviada.
- [ ] TLB-03 Ofertas e eventos com aceitar e recusar no próprio aviso quando a decisão é simples; decisões grandes continuam abrindo o app.
- [ ] TLB-04 Deslizar para adiar ou dispensar, e pressionar e segurar para ver o detalhe sem desbloquear.
- [ ] TLB-05 Marcar como lida sem abrir o app; selos e contadores se atualizam na hora.
- [ ] TLB-06 Revisar a lógica de prioridade e agrupamento: agrupar por assunto, mostrar o que vence primeiro, limitar o ruído e reaproveitar o resumo da noite.
- [ ] TLB-07 Mesmas ações disponíveis no Centro de Notificações com deslizar.
- [ ] TLB-08 Desfazer curto (alguns segundos) depois de uma ação direta, para evitar toque errado.

**Aceite:** responder uma mensagem e aceitar uma oferta simples sem sair da tela de bloqueio; toda ação direta registra o mesmo efeito de fazê-la dentro do app.

### Sequência sugerida (ciclo 2, em conjunto)

1. Recompensas visuais: ANI-01, ANI-02, ANI-03 e MRC-01 (os componentes compartilhados já servem à Narrativa e ao Hall das Lendas).
2. Tela de bloqueio: TLB-01, TLB-02 e TLB-05, que mudam o modelo de aviso uma vez só.
3. Pastas e abas: GRP-01, GRP-02 e GRP-05, antes de mexer nas telas de Mercado, Base e Banco para não redesenhá-las duas vezes.

## 5d. Ciclo 2 — Realismo do celular, personalização, agenda e fluxo

Pontos de partida levantados no código em outubro de 2026.

### 27 — Notificações e vida do celular

**Objetivo:** o celular parece usado por uma pessoa de verdade, com coisas acontecendo enquanto ela joga.

Hoje: o conteúdo é gerado uma vez por dia de jogo (eventos com 30% de chance, posts após a partida do clube); contatos só reagem, nunca puxam conversa; nada acontece em tempo real; não há banner de mensagem recebida com o celular em uso (só a dica "o que fazer agora"); a barra de status mostra a data do jogo, a torcida como sinal e a energia como bateria.

- [ ] REA-01 Motor de "pushes" aleatórios: durante o dia de jogo, em intervalos reais de segundos, chegam mensagens de contatos, posts, notícias, propostas e lembretes com banners no topo, som opcional e vibração. Quantidade e tom controlados por preferências e por energia.
- [ ] REA-02 Contatos puxam conversa sozinhos (família pergunta do jogo, o vice avisa de um problema, o agente traz uma proposta), com resposta rápida no próprio banner.
- [ ] REA-03 Reações ao jogo em tempo quase real: depois de gol, derrota ou lesão, chegam mensagens, prints e posts nos minutos seguintes.
- [ ] REA-04 Banner no topo com toque para abrir, deslizar para dispensar e agrupamento por conversa; nunca mais de um banner por vez e nunca durante a partida ao vivo, só depois.
- [ ] REA-05 Barra de status viva: hora do dia, wifi e operadora fictícios, bateria que cai e carrega, modo economia de energia e modo não perturbe (silencia tudo menos contatos favoritos).
- [ ] REA-06 Aplicativos de rotina para dar vida ao aparelho: tempo e clima do dia do jogo, galeria com fotos de momentos marcantes, e chamadas e mensagens de voz curtas em cenas importantes.
- [ ] REA-07 Ruído de realidade: mensagem de grupo, boato, notícia falsa para desmentir, sequestro de atenção por uma polêmica e spam de patrocinador, tudo com limite diário e sempre ignorável.
- [ ] REA-08 Notificações locais reais do iOS (UserNotifications) opcionais, para lembrar prazos e avisar que o clube precisa do técnico; desligadas por padrão e sem pedir permissão no primeiro uso.

**Aceite:** em dois minutos de uso o jogador vê pelo menos uma mensagem chegar sem ter provocado nada; nenhum push interrompe uma decisão ou a partida ao vivo; tudo respeita o modo não perturbe.

### 28 — Personalização do celular

**Objetivo:** o jogador sente o aparelho como seu.

Hoje: o papel de parede é um degradê gerado com a cor do clube e uma atmosfera automática (manhã, tarde de jogo, noite de jogo); não dá para escolher outro; não existe ajuste de tema claro ou escuro (só o que o sistema dita, com partes fixas no escuro); a posição dos ícones e o dock são fixos; os widgets não mudam; os recursos de imagem de estádio existem, mas não são usados.

- [ ] PER-01 Seletor de papel de parede nos Ajustes: degradê do clube, estádios do jogo, momentos (manhã, tarde, noite), cores sólidas e fotos próprias do usuário, com prévia ao vivo.
- [ ] PER-02 Papel de parede separado para a tela de bloqueio e para a tela inicial.
- [ ] PER-03 Tema claro, escuro ou automático, com cor de destaque à escolha (cores do clube e algumas fixas). Todas as telas respeitam o tema; as que hoje forçam o escuro passam a ter versão clara.
- [ ] PER-04 Reorganizar ícones: segurar e arrastar para mudar de lugar, esconder, mover para o dock e criar pastas (usa GRP-01), com a disposição salva na carreira.
- [ ] PER-05 Várias páginas na tela inicial com indicador, e uma pasta de apps escondidos que a busca ainda encontra.
- [ ] PER-06 Widgets configuráveis: escolher quais aparecem na tela inicial e na de bloqueio (próximo jogo, caixa, diretoria, pressão, agenda, artilharia) e o tamanho de cada um.
- [ ] PER-07 Nome do aparelho, toque e vibração por tipo de aviso, tamanho de fonte e ajustes de acessibilidade.
- [ ] PER-08 Restaurar o padrão com um toque e desfazer a última mudança.

**Aceite:** escolhas de tema, fundo e ícones sobrevivem a fechar o app e à troca de temporada; nenhuma tela fica ilegível em tema claro ou escuro.

### 29 — Agenda clara e útil

**Objetivo:** saber o que fazer hoje e o que vence em breve, num app só.

Hoje: não existe um app de agenda; a agenda é um painel dentro do Gestor, no meio de uma rolagem longa, ordenada por prazo, importância ou responsável, sem dias de calendário, sem badge na tela inicial, sem completar, adiar ou dispensar um item, e sem ação direta.

- [ ] AGD-01 Novo app Agenda no celular, com ícone e badge de itens que vencem hoje.
- [ ] AGD-02 Visão "Hoje": o que fazer agora, o que vence amanhã e o que está atrasado, em cartões grandes e com cores de urgência.
- [ ] AGD-03 Visão semana e mês com datas de verdade do calendário do jogo: jogos, prazos de contrato, janelas de transferência, eventos de patrocinador e compromissos pessoais.
- [ ] AGD-04 Ações no próprio item: abrir, aceitar ou recusar quando simples, adiar e marcar como feito (usa o modelo de ação TLB-01).
- [ ] AGD-05 Criar lembretes e compromissos próprios e vinculá-los a um jogador, contrato ou jogo.
- [ ] AGD-06 Linha do tempo da temporada com marcos e fases (pré-temporada, janela, mata-mata, reta final), com destaque do dia atual.
- [ ] AGD-07 Filtros (jogos, contratos, mercado, pessoal) e preferência de visão salva.
- [ ] AGD-08 Atalho no widget da tela de bloqueio e na tela inicial.

**Aceite:** em cinco segundos o jogador responde "o que eu preciso resolver hoje?"; nenhum prazo vence sem ter aparecido na Agenda e no badge.

### 30 — Variedade visual dos apps

**Objetivo:** cada app tem personalidade, sem perder a coerência do FutOS.

- [ ] VIS-01 Guia de linguagem visual por app: cor, densidade e tipo de componente principal (Banco com gráficos e números grandes, Agenda com calendário, Social com feed estilo rede, Mercado com cartas de jogador, Tática com campo).
- [ ] VIS-02 Diagramações diferentes por app: grade de cartas (Mercado, Elenco), feed vertical (Social, Mensagens), calendário (Agenda), painéis métricos (Banco, Negócios) e mapa ou campo (Tática), em vez de listas de painéis em todos.
- [ ] VIS-03 Cabeçalhos próprios, transições de entrada e ícones de seção por app.
- [ ] VIS-04 Componentes compartilhados revisados (cartão de jogador, linha de dado, gráfico) para servir a todas as diagramações.
- [ ] VIS-05 Revisão de contraste e legibilidade em tema claro e escuro, com captura de tela por app.

**Aceite:** dois apps lado a lado são reconhecíveis só pelo layout; a revisão de captura não aponta texto ilegível.

### 31 — Melhorias gerais no fluxo

**Objetivo:** menos toques entre o jogador e o que importa, sem perder o ritmo e a imersão.

Hoje: depois de cada dia o celular bloqueia e a animação leva até 3,1 s, com a necessidade de deslizar; simulação rápida termina em um alerta bloqueante; há vários modais sem coordenação (partida, resumo, coletiva, avisos, busca, ficha, mensagem e alerta); o banner de guia aparece cerca de 0,9 s depois do desbloqueio e pode cobrir o topo do app; avançar um dia custa quatro toques.

- [ ] FLX-01 Fila única de apresentação: um coordenador decide a ordem e evita modais empilhados (coletiva, resumo, mensagem, alerta e guia entram um por vez).
- [ ] FLX-02 Substituir o alerta bloqueante da simulação rápida por um resumo que se desfaz sozinho e pode ser reaberto no histórico.
- [ ] FLX-03 Dia de jogo em menos toques: botão "Próximo passo" fixo que leva ao que falta (preparar, jogar, coletiva, avançar), em vez de cada decisão exigir abrir apps.
- [ ] FLX-04 Tela de bloqueio opcional ao virar o dia: modo rápido que mostra só o resumo e some sozinho, mantendo a versão completa para quem gosta.
- [ ] FLX-05 Guia de próxima ação que não cobre conteúdo, aparece uma vez por situação e some ao se resolver.
- [ ] FLX-06 Retomar de onde parou: ao abrir o jogo, voltar ao app, à aba e à rolagem em que o jogador estava (fecha OS-05 e OS-08).
- [ ] FLX-07 Confirmações só para ações irreversíveis; o resto ganha "desfazer" curto.
- [ ] FLX-08 Medição simples de toques por jornada (avançar dia, jogar partida, contratar) nas capturas de revisão, com meta máxima por jornada.

**Aceite:** avançar um dia e jogar uma partida custam o menor número de toques acordado, sem modais empilhados e sem perder decisão importante.

### Sequência sugerida (realismo e fluxo)

1. Fluxo: FLX-01, FLX-02 e FLX-03, que tiram atrito antes de acrescentar mais conteúdo.
2. Agenda: AGD-01, AGD-02 e AGD-04 (depende do modelo de ação TLB-01).
3. Personalização: PER-01, PER-03 e PER-04 (as pastas GRP-01 vêm junto).
4. Realismo: REA-01, REA-02 e REA-04; as notificações do iOS (REA-08) ficam por último, porque exigem permissão e cuidado de produto.

## 5e. Lançamento — widgets, recompensa diária e preparação de loja

### 32 — Widgets reais do iOS e Live Activity | diferencial

**Objetivo:** o jogo aparece na tela inicial do iPhone e no dia a dia do jogador, e dá motivo para voltar.

Hoje: os widgets existem só dentro do FutOS (tela inicial e de bloqueio do celular do jogo). Não há extensão de widget, Live Activity nem compartilhamento de dados com o sistema.

- [ ] WID-01 Extensão de widget com dados compartilhados por App Group: um resumo gravado pelo jogo (próximo jogo, adversário, data, caixa, confiança da diretoria, posição na tabela) que o widget lê sem abrir o app.
- [ ] WID-02 Widgets pequeno, médio e de tela de bloqueio: "Próximo jogo", "Situação do clube" e "Agenda de hoje", com atualização quando o jogo muda de dia ou de estado.
- [ ] WID-03 Toque no widget abre o destino exato (jogo, agenda, mercado), reaproveitando a navegação por busca e avisos do FutOS.
- [ ] WID-04 Live Activity durante a partida ao vivo: placar, minuto e último lance na tela de bloqueio e na Dynamic Island, atualizados pelo próprio app enquanto a partida roda; encerra no apito final com o resultado.
- [ ] WID-05 Widget ou Live Activity do ritual de virada ("Pré-temporada: falta escolher o patrocinador"), como lembrete de decisão pendente.
- [ ] WID-06 Preferências para ligar e desligar cada widget e a Live Activity nos Ajustes, e respeito ao modo não perturbe do FutOS (REA-05).
- [ ] WID-07 Dados do widget sem informação sensível além do que a tela do jogo já mostra, e limpos ao apagar a carreira.

Dependências e riscos:
- O pipeline de assinatura (`tools/football_signing.py` e o workflow do TestFlight) hoje assina um único bundle. Uma extensão de widget precisa de bundle id próprio, perfil de provisionamento próprio, a capacidade de App Group nos dois perfis e entradas novas no `ExportOptions`. Isso exige segredos novos e uma etapa nova no workflow.
- Live Activity exige a chave `NSSupportsLiveActivities` no `Info.plist` e só atualiza enquanto o app está ativo ou com tempo de fundo curto. Como a partida é simulada no aparelho, o desenho funciona; atualizações com o app fechado não são possíveis sem servidor de push.
- Testar widgets e Live Activity só é possível em simulador ou aparelho; os UI tests atuais não cobrem isso.

**Aceite:** com o app fechado, o widget mostra o próximo jogo correto e abre o destino certo; a Live Activity acompanha a partida e termina no resultado final.

### 33 — Recompensa diária e sequência | retenção

**Objetivo:** dar um motivo leve para abrir o jogo todo dia, sem castigar quem pula um dia.

Hoje: só existe o bônus diário de apostas, liberado a cada 4 dias do mundo do jogo (`claimDailyBonus`), e a conquista "Embalado" para cinco vitórias seguidas. Não há conceito de dia real, sequência de acessos ou evento diário.

- [ ] DIA-01 Recompensa diária por dia real do calendário, com um cartão ao abrir o jogo (uma vez por dia), animação curta de coleta e vibração.
- [ ] DIA-02 Sequência de dias com marcos (3, 7, 14 e 30 dias), com recompensas crescentes e visuais: energia, moral do grupo, cartão do dia extra, moldura de perfil.
- [ ] DIA-03 Perdão: um dia perdido não zera a sequência, ele usa "folga" (uma por semana); quebrar a sequência só reinicia o contador, sem remover o que já foi ganho.
- [ ] DIA-04 Evento do dia (NAR-06) integrado: a recompensa diária e o evento do dia aparecem juntos, em um minuto de jogo.
- [ ] DIA-05 Integração com o Hall das Lendas: o cartão do dia gratuito entra como parte da sequência, sem criar compra nem sorteio pago.
- [ ] DIA-06 Painel de sequência no celular (e widget WID-01) com o próximo prêmio e a contagem.
- [ ] DIA-07 Preferência para desligar lembretes e a própria sequência, e nenhum texto de pressão ("não perca", "última chance").
- [ ] DIA-08 Hora e dia reais vêm do relógio do aparelho com proteção contra mudar a data para trás; mudança suspeita só pausa a coleta do dia, sem punir.

**Aceite:** abrir o jogo em dias seguidos entrega a recompensa uma única vez por dia; pular um dia usa a folga e não zera a sequência; nenhuma recompensa é paga nem aleatória por dinheiro.

### 34 — Preparação para publicar

Itens levantados na conversa de lançamento. Os marcados como obrigatórios bloqueiam a publicação.

- [ ] LAN-01 Obrigatório antes de qualquer versão pública ou venda: direitos de imagem e nome. Decisão do MVP: as cartas atuais ficam como estão nos builds internos do TestFlight; antes de publicar na App Store ou vender no Hall das Lendas, licenciar (inclusive junto aos herdeiros) ou trocar por lendas fictícias inspiradas nelas.
- [ ] LAN-02 Obrigatório: pacote de loja. Ícone do Hall das Lendas, screenshots finais, política de privacidade, classificação etária, descrição e revisão do tema de apostas (Palpite+) e das compras.
- [ ] LAN-03 Obrigatório: salvar na nuvem. Backup no iCloud ou exportar e importar a carreira.
- [ ] LAN-04 Obrigatório: estabilidade e métricas. Relatório de falhas e métricas básicas (abandono no onboarding, temporadas jogadas, uso das recompensas), sem dados pessoais.
- [ ] LAN-05 Diferencial: som e música. Torcida, apito, som de aviso, trilha leve nos menus e narração curta em gols, com controle de volume e modo silencioso.
- [ ] LAN-06 Alcance: acessibilidade (texto maior, leitura por voz dos gráficos, contraste).
- [ ] LAN-07 Depois do lançamento: inglês e espanhol, e desafio da semana com ranking de amigos (NAR-07, exige servidor).

### Sequência sugerida (lançamento)

1. LAN-01 a LAN-04, em paralelo às frentes de jogabilidade, porque dependem de decisões e de contas, não de código.
2. DIA-01 a DIA-03: baixo risco, alto retorno de retenção.
3. LAN-05 (som): custo baixo para a imersão.
4. WID-01 a WID-04: só depois de resolver a assinatura da extensão no workflow do TestFlight.

## 5f. Ciclo 2 — Pilares de design, carreira, mercado simples, rede social e movimento

### 35 — Pilares de design (herança Elifoot e Brasfoot)

**Objetivo:** o jogo parece leve e direto, com profundidade só para quem quer. Estas regras valem para todas as outras frentes.

- [ ] PIL-01 Toda tela leva a uma decisão útil: auditoria de cada app e tela; cada uma tem uma ação principal visível sem rolar (botão, escolha ou atalho) e nenhuma é beco sem saída.
- [ ] PIL-02 Ritmo: nada de menus lentos, onboarding longo ou burocracia. Chegar a uma decisão custa no máximo dois toques; confirmações só para ações irreversíveis; o onboarding continua curto e pulável.
- [ ] PIL-03 Modo de ritmo nos Ajustes e na escolha de dificuldade: "Clássico" (rápido: animações curtas, ritual de virada resumido em um painel de decisões, tela de bloqueio resumida) e "Imersivo" (cenas completas, como hoje). O padrão é decidido em playtest. Isso resolve a tensão entre imersão e leveza.
- [ ] PIL-04 Sessão curta: em poucos minutos o jogador abre o app, resolve duas ou três pendências, joga uma rodada e sente progresso. Jornada de referência: tela "Hoje" (AGD-02), botão "Próximo passo" fixo (FLX-03) e resumo ao fim da rodada.
- [ ] PIL-05 Sensação de progresso a cada rodada: faixa de resumo ("subiu uma posição, caixa +R$, meta da diretoria em 60%") na volta ao Gestor.
- [ ] PIL-06 Nostalgia de manager raiz: tabelas densas e legíveis, classificação com cores de zona (título, acesso, rebaixamento), ranking, histórico de temporadas, notícias curtas de uma linha e janelas simples de decisão (sim ou não).
- [ ] PIL-07 Orçamento de toques por jornada, medido nas capturas (FLX-08): avançar uma rodada em no máximo 3 toques; contratar em no máximo 5; vender em no máximo 3.
- [ ] PIL-08 Toda animação nova é pulável com um toque e respeita o modo de ritmo e "reduzir movimento" (ANI-08).

**Aceite:** um jogador novo termina uma rodada completa em menos de cinco minutos sem consultar ajuda; a auditoria PIL-01 não encontra tela sem ação.

### 36 — Ranking e carreira

**Objetivo:** dar vontade de subir de time, ganhar títulos, bater recordes e virar lenda.

Hoje já existem histórico de temporadas, lendas do clube, reputação e conquistas; faltam telas que reúnam isso como carreira e dêem metas longas.

- [ ] CAR-01 Hall da fama do treinador: títulos, acessos, temporadas, recordes e pontos de carreira em uma tela.
- [ ] CAR-02 Recordes do treinador e do clube (maior goleada, maior sequência, artilheiro histórico, maior público), com aviso e comemoração ao bater um.
- [ ] CAR-03 Histórico de temporadas em tabela (ano, divisão, posição, copa, artilheiro, campeão), legível como as tabelas antigas.
- [ ] CAR-04 Ranking de treinadores por reputação, comparando com treinadores fictícios da liga e com os próprios recordes; patamares do Aprendiz à Lenda.
- [ ] CAR-05 Subir de clube: propostas melhores conforme a reputação e um mapa da trajetória (clubes por onde passou, anos e resultados).
- [ ] CAR-06 Metas de carreira longas (ganhar a Série A, cinco títulos, treinar três clubes, virar lenda) com progresso sempre visível, integradas aos marcos (MRC-01).
- [ ] CAR-07 Tela "Lenda" no fim de uma carreira ou aposentadoria: resumo, recordes e cartão de compartilhar (NAR-03).

**Aceite:** depois de três temporadas o jogador consegue dizer onde está na carreira e qual é a próxima meta, sem abrir mais de uma tela.

### 37 — Mercado simples, prazeroso e movimentado

**Objetivo:** entender um jogador de relance e sentir o mercado vivo. Soma-se à frente 19.

- [ ] MER-09 Linha de jogador padrão com os cinco dados que importam: força, idade, valor, salário e potencial de revenda, com selo ("bom negócio", "caro") e ordenação por qualquer um.
- [ ] MER-10 Potencial de revenda explícito: projeção do valor em uma, duas e três temporadas, com seta de alta ou queda.
- [ ] MER-11 Comprar e vender em dois toques ("Comprar por X", "Vender por X") com janela simples de decisão; negociação detalhada só em camada opcional.
- [ ] MER-12 Janela de transferências com clima: contagem regressiva, dia final com negócios acelerados e rumores no celular, sendo alguns falsos.
- [ ] MER-13 Mundo que negocia sozinho: clubes da liga compram, vendem e emprestam entre si, com notícias de uma linha e "cláusula paga" por seus alvos.
- [ ] MER-14 Leilões e disputas com decisão do jogador por salário, projeto ou torcida; chegada e despedida com cerimônia curta.
- [ ] MER-15 Pressão no mercado: torcida pede reforço, diretoria pede venda e jogador pede para sair, sempre com uma decisão clara.

**Aceite:** comparar dois jogadores e fechar uma compra custa no máximo cinco toques; em uma janela completa o jogador vê pelo menos cinco negócios de outros clubes.

### 38 — Rede social integrada ao jogo

**Objetivo:** o app social vira um segundo palco do jogo, e o que o jogador faz nele tem consequência.

- [ ] SOC-01 Feed que reage a tudo (gol, expulsão, entrevista, transferência, crise, título) com torcedores, jornalistas, jogadores e rivais de personalidades diferentes.
- [ ] SOC-02 Perfil que cresce: seguidores, engajamento e "fase" (querido, polêmico, discreto), afetando patrocinadores, pressão da torcida e diretoria.
- [ ] SOC-03 Respostas e polêmicas: provocações do rival e da imprensa com tom à escolha (humor, firme, ironia) e consequência.
- [ ] SOC-04 Trends, hashtags do clube e memes que viram campanhas de patrocinador.
- [ ] SOC-05 Mensagens diretas e grupo do vestiário, cujo clima muda com os resultados.
- [ ] SOC-06 Ligação com o resto: patrocinadores reagem ao perfil, a diretoria cobra declarações e o Livro da carreira (NAR-02) guarda os posts marcantes.
- [ ] SOC-07 Por último: stories e vídeos curtos de gols e comemorações.

**Aceite:** depois de uma partida, o feed mostra pelo menos três reações ligadas ao que aconteceu; nenhuma decisão social é sem efeito.

### 39 — Movimento, carregamentos e recursos visuais

**Objetivo:** tudo mais fluido, bonito e coerente.

- [ ] MOV-01 Biblioteca única de movimento (durações, molas, curvas) e de componentes (cartão, número animado, esqueleto, transições), usada por todas as telas.
- [ ] MOV-02 Carregamentos com personalidade: dica de jogo, curiosidade do clube e frase do rival no lugar do spinner, sempre curtos.
- [ ] MOV-03 Esqueletos que brilham em listas e gráficos enquanto os dados chegam.
- [ ] MOV-04 Transições a partir do elemento tocado (a carta cresce até a ficha, a linha abre o detalhe).
- [ ] MOV-05 Campo mais rico: replay curto do gol, linha de passes e mapa de calor ao fim da partida.
- [ ] MOV-06 Cartas e fichas animadas: brilho conforme a forma, moral com rosto e barras que enchem com mola.
- [ ] MOV-07 Tema do clube com fundo animado leve nas telas principais, em tema claro e escuro (PER-03).
- [ ] MOV-08 Desempenho: 60 quadros por segundo em iPhone e iPad de gerações anteriores, medido em capturas, e nenhuma animação sem opção de pular.

**Aceite:** nenhuma tela mostra spinner sem texto ou esqueleto; a rolagem das listas principais não perde quadros em aparelho antigo.

### 40 — Abertura do app (experiência de jogo) | Entrega A

**Objetivo:** abrir o app tem cara de jogo: carregamento, uma tela de entrada e as opções de sempre.

Hoje (antes desta frente): o app abria numa tela preta com a barra "FutOS" e entrava direto na carreira ou nas propostas de clube.

- [ ] TIT-01 Carregamento com logo, barra de progresso dourada e uma dica de jogo (implementado em `FootballLoadingView`; aguardando CI).
- [ ] TIT-02 Tela de entrada com fundo animado, logo com brilho e três botões em cascata: Continuar (mostra clube e temporada), Novo jogo e Opções (implementado em `FootballTitleScreen`; aguardando CI).
- [ ] TIT-03 Novo jogo sem perder a carreira atual: usa o primeiro espaço de save livre, com confirmação, e avisa se os três espaços estão ocupados (implementado; aguardando CI).
- [ ] TIT-04 Opções da abertura: carreiras salvas (carregar, nova, apagar) e "Reduzir movimento" (implementado; aguardando CI).
- [ ] TIT-05 UI tests e capturas entram direto no jogo; capturas `loading`, `title` e `title-new` para revisão visual (implementado).
- [ ] TIT-06 Som de abertura e música da tela de entrada (depende de LAN-05).
- [ ] TIT-07 Continuar mostra o último dia jogado e a próxima ação sugerida ("Próximo jogo: domingo contra o Aurora").
- [ ] TIT-08 Opções completas: dificuldade, modo de ritmo (PIL-03), tema (PER-03) e rever a introdução.

**Aceite:** do toque no ícone até o primeiro jogo em no máximo três toques (Continuar, Gestor, Jogar); quem não tem carreira cai no onboarding.

### Ordem de entrega proposta

Cada entrega é uma versão do TestFlight e só avança com CI verde e capturas revisadas.

1. **Entrega A — Ritmo e recompensa:** PIL-01 a PIL-05 e PIL-07, FLX-01 a FLX-03, ANI-01 a ANI-03, MRC-01 e BAN-07 a BAN-09.
2. **Entrega B — Mercado e base:** MER-01, MER-02, MER-07, MER-09 a MER-11, BAS-01, BAS-02 e BAS-04.
3. **Entrega C — Carreira e história:** CAR-01 a CAR-04, NAR-01 a NAR-03 e SOC-01 a SOC-03.
4. **Entrega D — Mundo vivo:** REA-01 a REA-04, MER-12 e MER-13, AGD-01, AGD-02 e AGD-04, PER-01, PER-03 e PER-04.
5. **Entrega E — Lançamento:** LAN-01 a LAN-05, DIA-01 a DIA-03 e MOV-01 a MOV-04; widgets (WID) só depois de resolver a assinatura da extensão.

Regra de corte: se uma entrega ficar grande demais, o que sair vai para a seguinte; os pilares PIL-01 a PIL-08 não saem de nenhuma entrega.

## 6. Critérios globais de conclusão

Para cada incremento funcional:

- [ ] Há uma jornada descrita antes da implementação, incluindo alternativa e omissão quando aplicável.
- [ ] Custo, bloqueio, prazo e retorno são compreensíveis na interface.
- [ ] Estado relevante é persistido e retomado.
- [ ] Decisão e liquidação são idempotentes quando podem ser repetidas.
- [ ] Consequências cruzadas usam o mesmo fato de origem.
- [ ] Testes de domínio cobrem invariantes novas; UI tests cobrem jornadas críticas alteradas.
- [ ] Capturas reais demonstram novos estados no iPhone para mudanças visuais.
- [ ] Não há novo botão de gestão sem efeito no motor ou função de consulta clara.
- [ ] Há caminho de delegação ou omissão para conteúdo opcional.
- [ ] Marco e evidência foram atualizados neste roadmap.

### Indicadores para revisão

| Indicador | Meta inicial |
|---|---|
| Apps revisados contra aceite | 18/18 em M5 |
| Jornada vertical conectada | 1 completa em M2, depois ampliar |
| Consequências duplicadas nos cenários verificados | 0 |
| Compromissos sem conclusão/expiração definida | 0 |
| Saves de referência migrando | 100% dos selecionados em F0 |
| Falhas críticas confirmadas pendentes | 0 para M6 |
| Histórico financeiro reconciliado | 100% dos cenários econômicos verificados |
| Compreensão das decisões | Registrar no playtest; definir alvo após primeira amostra |
| Desempenho e tamanho do save | Medir baseline em F0; fixar limites antes de F6 |

Essas metas representam critérios futuros, não resultados já obtidos.

## 7. Próximo passo concreto

**Começar por F0 e depois pela fatia F2 do reserva que pede minutos.** Implementar somente a fundação F1 necessária para essa jornada, mantendo possibilidade de extensão.

Ordem das primeiras microações:

1. Medir baseline e verificar testes atuais.
2. Escrever os quatro desfechos do pedido: cumprir, quebrar, recusar e ignorar.
3. Identificar quais modelos existentes de mensagens e promessas podem ser reaproveitados.
4. Definir destino específico de conversa/atleta/escalação.
5. Implementar consequência, prazo e retomada.
6. Construir a experiência da conversa e o resumo de repercussões.
7. Verificar save/load e uma semana completa no simulador.
8. Registrar evidências e revisar o escopo da próxima entrega.

## 8. Diário de progresso

| Entrega | Estado | Evidência/referência | Próxima ação |
|---|---|---|---|
| Roadmap inicial | Concluído | Este arquivo | Iniciar F0 |
| F0 — baseline | Em andamento | 159 testes Linux; 159 + 3 por dispositivo no iOS | Registrar decisões e saves de referência |
| F1 — fundação mínima | Em andamento | Save v11, resultados de promessas e navegação | Unificar fatos e completar ciclo de vida |
| F2 — pedido de minutos | Em andamento | Compromissos, agenda e Mensagens integrados | Omissão com prazo e repercussões |
| TestFlight 1.0 (5) | Concluído | Run 37234149295; READY_FOR_BETA_TESTING | Cadastrar tester e realizar playtest |
| Auditoria em aparelho físico | Planejado | Grupo interno sem testers | Confirmar e-mail e acesso |
| Organização FutOS, passagem de dia, guia, chat, Chuteira com fotos, física da partida | Implementado, não compilado | Seção "6 de outubro (2)" e `docs/FUTOS-ARQUITETURA.md` | Build + testes no CI, capturas e playtest |

Atualizar este diário e as caixas a cada entrega verificada. Registrar mudanças de direção e itens adiados com motivo, preservando o histórico da jornada.

### Incremento inicial — implementação local em validação

Implementado, ainda sem aprovação de build Swift/iOS:

- Respostas persistentes aos pedidos de minutos, com progresso do compromisso em Mensagens e Gestor.
- Proteção contra substituir a mesma promessa repetidamente para ganhar moral e renovar prazo.
- Recusa explícita e idempotente, restrita a pedidos abertos do elenco atual.
- Resultado de promessa com ID de origem e detalhes de titularidades e efeitos.
- Encerramento da promessa quando atleta deixa o clube e tratamento de prazo de temporada anterior.
- Leitura individual de mensagem; abrir Mensagens não marca toda a inbox como lida.
- Avisos da tela de bloqueio abrem o app correspondente.
- Busca de contatos destaca a pessoa encontrada no app Contatos.
- Save versão 11, com novos campos opcionais para leitura de saves legados.
- Testes de domínio adicionados em `FootballCommitmentTests.swift`.

Verificações executadas: `python3 tools/validate_factory.py` passou; `git diff --check` passou.

Atualização de validação: Swift não está instalado no host, mas a imagem Docker local `swift:5.9` permitiu compilar e testar o motor. A suíte completa em Release passou: **159 testes, zero falhas**. Todos os arquivos `Sources/*.swift` passaram pelo parser `swiftc -frontend -parse`. Isso não substitui a checagem de tipos com o SDK iOS nem os UI tests. Não foram disparados workflows remotos nesta etapa.

Próximas ações: validar o incremento no macOS; detalhar conversa encadeada, omissão com prazo e destinos específicos por mensagem; verificar encerramento de compromissos ao trocar de clube/temporada. O roadmap completo permanece em andamento.

### Segundo incremento — entregas concorrentes integradas

- Agenda consultiva no motor: promessas, propostas, acontecimentos e contratos ordenados por prazo absoluto.
- Gestor mostra prioridades e confirma avanço rápido quando há itens próximos de vencer.
- Avanço até decisão considera a agenda antes de consumir um prazo importante.
- Liga permite navegar por rodadas, abrir partidas, consultar clubes e atletas da artilharia.
- Busca do FutOS normaliza acentos, caixa e espaços; clubes abrem ficha consultiva específica.
- Contatos abrem ficha específica e mensagens não lidas geram notificações individuais.
- Notificações são ordenadas por proximidade do prazo e prioridade; Metas usa indicação de tarefas ativas.
- Novos testes de agenda: ordenação, consulta pura, limites de vencimento e avanço de calendário.

Estado atualizado: motor e interface passaram por compilação/testes iOS no workflow do build 5. Cenários e comandos em `docs/AUDITORIA-FUTOS-INCREMENTO-02.md`. Não marcar M2/M5 completos: conversa encadeada, omissão contextual e demais expansões continuam pendentes.

### Integração FutOS — navegação e captura

Notificação passou a abrir a mensagem com ações no componente real de Mensagens. Agenda passou a abrir atleta/contrato ou mensagem de proposta específica. Busca de atleta aguarda o dismiss antes de apresentar outra ficha. Rotas de captura `agenda`/`commitment` e jornada UI contextual adicionadas. Parser, checks locais e execução UI no iPhone/iPad aprovados. Geração das novas capturas e playtest físico permanecem pendentes.
