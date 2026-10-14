# Pacote para o outro agente — disparar, acompanhar e relatar

Atualizado em 14/out/2026, 07:46 (Brasília). Checagem das 07:46: nenhum run novo desde as 00:48, nada em andamento. Revisão de leitura de todo o Swift de hoje (desde `c496e0d`): nenhum problema de compilação achado; `open` virou `pending` por precaução (`fba1f2d`). Continua sem compilador: o V é a primeira compilação. O TestFlight nº 30 (`38497408024`) **terminou com sucesso às 00:29** (Brasília): o 1.1 (20) está enviado e ativado no TestFlight interno, a partir de `polimento/build-20` @ `493ecef`, com o artefato `football-release-1.1-20` (ID 11867358867). Os inputs do run 30 são ref `polimento/build-20` (confirmado pela API), version 1.1 e build 20 (confirmados pelo nome do artefato). Na checagem das 22:45: a validação nº 55 (`493ecef`) do `polimento/build-20` **passou nos dois dispositivos** (iPhone e iPad). O Prompt J deste pacote apontava para `feature/entrega-a-ritmo`, mas o run 30 saiu de `polimento/build-20`. A nº 47 foi cancelada no job de testes (ver "Estado agora"). O TestFlight nº 30 (build 20) é o último build; o nº 29 é o build 19. A validação nº 55 (`38489827076`, `493ecef`) é o Prompt V deste head e passou nos dois dispositivos. O último commit de código do `feature/entrega-a-ritmo` é `e6552d4`. **O 1.1 (19) já foi enviado e ativado no TestFlight interno em 08/out às 18:50** (run `37841387343`, nº 29, commit `502af64`, artefato `football-release-1.1-19`). Ele saiu antes da janela de dois dias do 1.1 (18), que ia até 09/out às 23:34; o pacote não o autorizava sem decisão do usuário. O número 19 está consumido: não disparar de novo. A validação nº 43 (`37825748681`, mesmo commit, Prompt V) passou nos dois dispositivos: iPhone 38 min, iPad 32 min, upload concluído. A validação nº 42 tinha falhado por tempo (iPad cancelado aos 45 min). O limite dos workflows de validação e de build passou para 120 min: o run 29 levou cerca de 68 min e o run 28 cerca de 80 min, do início ao fim. O código do 1.1 (20) vai até `493ecef` (polimento), e o do feature até `e6552d4`: a virada conta como vitória grande no fim de jogo (ANI-03 v3 parcial, sem compilador). Antes dele, dois commits de outro agente (`1a8d515` e `4939c9a`, guia do primeiro uso da carreira). Nenhum deles está no 19. O run 62 (`37883740535`, capturas, head `4939c9a`, 09/out 01:56 Brasília) passou: o app compilou para simulador com o guia. O run 61 (`37883622118`, em `1a8d515`) tinha falhado no passo "Build simulator app" por nomes de arquivo duplicados no Xcode, corrigido em `4939c9a`. Artefato das capturas: `screenshots-manager-futebol` (ID 11596416811). Esse código (até `e6552d4`) foi testado depois, na validação nº 55 (`493ecef`, que o contém): passou nos dois dispositivos. **Próximo número: 1.1 (21)**, ainda sem branch escolhido pelo usuário (ver "Estado agora"). Não disparar antes de 16/out às 00:29 (Brasília), dois dias de teste do 20. Capturas: o run 60 (`37711892098`) terminou com sucesso em 07/out às 22:24; o Prompt C2 segue pendente para confirmar a revisão de telas.

## Como usar quando você acordar

1. Leia a seção "Estado agora" para saber o que já passou.
2. Hoje não há disparo a fazer: o 1.1 (20) já foi enviado (Prompt J, histórico). O próximo é o 1.1 (21). Quando você escolher o branch (ver "Estado agora"), o prompt do 21 entra aqui com o ref certo, e o **V** desse branch vem antes. **C2** repete os prints das telas novas. Os prompts A, B, E, F, G, H, I e J já foram cumpridos e ficam como histórico; C, D e V continuam válidos.
3. Jogue os roteiros da seção "O que você testa" no aparelho, quando o build chegar ao TestFlight.
4. Traga para mim o relatório do agente (modelo na seção "Relatório") e o que você achou jogando.

## Estado agora

| Item | Estado |
|---|---|
| 1.1 (10) | Aprovado e no TestFlight desde 06/out 22:29. Linha de base. |
| 1.1 (11) | **Aprovado e enviado ao TestFlight interno em 07/out às 02:53** (branch `ccr-020b52d1-16pkkp`, commit `2dfaa10`, run `37572402802`). Já dá para testar. Contém: craques eternos (pacote só no fim da temporada; no modo Fácil, convidado por partida), onboarding, ritual de virada. NÃO tem a lenda inicial nem a tela de abertura. |
| 1.1 (12) | **Aprovado e enviado ao TestFlight interno em 07/out às 09:59** (run `37615474193`, commit `23b78dd`). Testado: o menu da abertura e o onboarding saíram desproporcionais e as lendas apareciam num painel, não num app. Corrigido no 13. |
| 1.1 (13) | **Upload concluído (11:49), ativação interna NÃO confirmada.** Run `37627792257`: testes passaram (430 de domínio, UI sem falhas, 3 skips), "Upload TestFlight" com sucesso, mas "Activate internal TestFlight after Apple processing" foi cancelado às 11:51 (depois de ~2 min). Conferir no App Store Connect (TestFlight, build 13): se estiver processado, adicionar ao grupo interno à mão. O número 13 está consumido: não reenviar o 13. |
| 1.1 (14) | **Aprovado e no TestFlight interno desde 07/out às 14:22** (run `37650467959`, commit `1b11dda`; upload e ativação concluídos). Aprovado pelo usuário. Linha de base atual. |
| 1.1 (15) | **Aprovado pelo usuário às 18:37 (Brasília).** Enviado ao TestFlight interno às 16:33. Run `37663919522` (nº 25), commit `e5439a3`: todos os passos concluídos, incluindo "Activate internal TestFlight". Academia v1 liberada para teste. |
| 1.1 (16) | **Falhou no passo de testes (run `37690905790`, commit `62ed950`, terminou 19:22).** Os testes de interface passaram. Falhou só `FootballYouthBalanceTests.testYouthPipelineBalanceReport` (medição por id, corrigida em `ee481d8`). Não foi enviado ao TestFlight. Substituído pelo 1.1 (17). O artefato `football-release-1.1-16` (ID 11515456607) ficou no run 26 e não interfere no 17. |
| 1.1 (17) | **Enviado e ativado no TestFlight interno às 21:29 (Brasília): run 27 (`37700560177`, commit `73f3df1`), todos os passos verdes.** Mesmo conteúdo do 16: Academia v2 (Sub-15, parcerias de captação, campeonato de base com minutos, linha BALANCE), HUD real (bateria, sinal, data, hora e escudo vindos da carreira; a sala de espera mostra o último save de cada perfil), estados vazios da Academia, contadores que rolam, atalho "jovem pronto para decidir" no Gestor, mercado com busca, ordenação e "Mostrar mais", e a fila de desbloqueios no topo do celular. Mais a correção do teste de equilíbrio (`ee481d8`). Commits `6cf10b3`, `070e5da`, `c75c058`, `5388264`, `bdd01b8` e `ee481d8`. Artefato `football-release-1.1-17` (ID 11520219563). Linha BALANCE: o teste passou, mas o número não sai pela API (fica longe do fim do log); procure `BALANCE` na página do job: https://github.com/socialbot114-cell/ios-app-factory/actions/runs/37700560177/job/113062736648 . |
| 1.1 (18) | **Enviado e ativado no TestFlight interno às 23:34 (run `37711891690`, nº 28, commit `f7ff16f`), todos os passos verdes.** Artefato `football-release-1.1-18` (ID 11525165830, expira em 21/out 23:34). Pedido em 07/out às 21:48 (Brasília), depois de aprovar o 17; a antecipação é decisão do usuário. Vitrine da Loja Aplicativo (módulos Pro em mistério, sem cobrança; item 45 do roadmap). Commits `905c4cf` (Loja) e `4348a38` (capturas). Escrito sem compilador: a primeira compilação é o CI do 18. Capturas concluídas com sucesso às 22:24 no run `37711892098` (nº 60). Às 22:46 o build estava em "Test iPhone and iPad". |
| 1.1 (19) | **Enviado e ativado no TestFlight interno em 08/out às 18:50 (Brasília): run `37841387343` (nº 29), commit `502af64`, todos os passos verdes; artefato `football-release-1.1-19` (ID 11581676301). Número consumido: não disparar de novo.** Banco: visão geral, barras de receita e despesa, comparação entre temporadas, linha do saldo e orçamento da temporada por área (BAN-07, BAN-08 partes 1 e 2, BAN-09 v1). Ritmo Clássico ou Imersivo nos Ajustes (PIL-03 v1), com a comemoração de vitória menor no Clássico (PIL-03 v2, `7c9b45c`). Resumo da simulação rápida no Histórico de ações (FLX-02 v1, `55f682c`). Ajustes de tela da revisão das capturas (`68624aa`). Commits `17933e7` (BAN-07), `fc9e5a4` (BAN-08 parte 1), `7e12184` (BAN-08 parte 2), `a3d0bea` (BAN-09 v1), `6281d28` (PIL-03 v1), `7c9b45c` (PIL-03 v2), `55f682c` (FLX-02 v1), `1f1b403` (FLX-01 v1, só lógica, sem tela) e `ea97fd2` (FLX-03 v1, só lógica, sem tela) e `67c4b24` (ANI-03 v1, só lógica, sem tela) e `c1dbaf1` (PIL-05 v1, só lógica, sem tela) e `3bcc678` (PIL-03 v3 início, só lógica, sem tela) e `80e1abf` (PIL-03 v3 decisões, só lógica, sem tela). Ligados às telas sem captura, autorizado pelo usuário: `2ef884ad` (ANI-03 v2, faixa de vitória grande), `20665b9` (FLX-03 v2, barra Próximo passo) e `ba59b7b` (FLX-02 v2, resumo da simulação rápida numa faixa). Loja refeita no padrão da Academia (`2dc7356`, sem captura e sem compilador: três métricas no topo, cor por módulo, "O que vai ter" direto e prévia em barras). FLX-02 v3 (`506620d`, sem compilador): "Simular até a próxima decisão" mostra só o motivo quando nada avança. Guarda do "Aceitar desafio" (`02b5773`) e confirmações de troca de clube, demissão, venda e perdão de aporte (`4e12f5b`), sem compilador. Escrito sem compilador; o CI compilou e passou (run 29 e validação 43). Revisão de compilação por leitura antes do envio: sem achados. Validação nº 43 (`37825748681`, mesmo commit) verde nos dois dispositivos. |
| 1.1 (20) | **Enviado e ativado no TestFlight interno às 00:29 (Brasília) de 14/out: run `38497408024` (nº 30), a partir de `polimento/build-20` @ `493ecef`; todos os passos verdes. Artefato `football-release-1.1-20` (ID 11867358867, expira em 28/out). Validação nº 55 (`38489827076`) verde nos dois dispositivos. Número consumido: não disparar de novo.** Traz o guia do primeiro uso da carreira (`1a8d515` e `4939c9a`, de outro agente; o guia passou nos testes dos dois dispositivos na validação nº 55) e a virada como vitória grande no fim de jogo (`e6552d4`, ANI-03 v3 parcial, agora nos testes de CI) e o limite de 120 min nos workflows de validação e de build. Polimento do branch (abertura com fundo, avisos no Core, três UI tests pulados reativados, toque da liga; commits `7d65869` a `493ecef`). A janela de dois dias do 20 vai até 16/out às 00:29 (Brasília). |
| 1.1 (21) | **Não disparado.** Próximo número. Branch a escolher pelo usuário. `polimento/build-20` tem todo o código do `feature/entrega-a-ritmo` (o feature só tem commits de docs a mais) e mais os 10 commits de polimento. O `feature/entrega-a-ritmo` não tem esses 10: sem eles, falta a troca do fundo da abertura (MatchSceneV2 apontava para um PNG inexistente) e os ajustes da liga. Não disparar antes de 16/out às 00:29 (Brasília). Antes de disparar, o V do branch escolhido. No feature, já sem compilador: PIL-05 v2, lógica da faixa de resumo (`e24e918`) e a faixa "Última rodada" na tela do Gestor (`2adede5`), e a lista da tela de bloqueio no Clássico (PIL-03 v3, `c3a0499`), e a linha de escolhas que faltam no ritual de virada no Clássico (`24c755f`), e a animação do cartão de fim de jogo e do placar (ANI-02 v2 e v3, `8857393` e `377cbf2`), e a vibração de sucesso na vitória (ANI-02 v1, `564b708`). |
| polimento/build-20 (ramificado de `a3d9f3f`; ref do 1.1 (20)) | **Apareceu às 14:12 (Brasília), fora do pacote.** Validação nº 44 (`38436752441`, commit `7d65869`) falhou na compilação, não nos testes: `Filename "FootballVisitStreak.swift" used twice` (em `Sources/Abertura` e em `Core`). A etapa de testes do iPhone parou em 12 s e o iPad foi pulado. O commit `031bd90` renomeia o de `Sources` para `FootballVisitStreakRegister.swift`; a validação nº 45 (`38436983087`) com esse commit **falhou em 7 testes de UI**: `FootballFlowUITests` (calendário, abertura dos apps, guia da primeira carreira e liga) e `FootballF5UITests` (banco e configurações; estes três sem mensagem no log filtrado). O commit `fe8ceba` desliga o guia de primeira carreira nos UI tests; a validação nº 46 (`38443113417`) com esse commit **falhou em 4 testes de UI**: `FootballFlowUITests.testFirstCareerGuideLeadsFromHomeToTheLiveMatch` (botão `first-run-guide-continue` ausente), `FootballFlowUITests.testLeagueRowsOpenClubProfileMatchesAndRoundsNavigate` (`XCTAssertTrue` sem mensagem) e `FootballF5UITests.testBankSimulatorChangesProjectionAndResetRestoresIt` e `testSettingsCanCreateAndRestoreCareerSlot` (sem mensagem no log). Os outros 11 passaram. O commit `af74779` corrige a causa provável do guia (o cartão com `accessibilityElement(children: .contain)` sobrescrevia o identificador do botão Continuar) e anexa hierarquia nos testes que falham; a nº 47 (`38450703254`) foi cancelada no job de testes, e a nº 48 (`38452934620`) falhou em 3 testes (o do guia passou): `FootballFlowUITests.testLeagueRowsOpenClubProfileMatchesAndRoundsNavigate` (`XCTAssertTrue` na linha 206, sem mensagem no log) e `FootballF5UITests.testBankSimulatorChangesProjectionAndResetRestoresIt` e `testSettingsCanCreateAndRestoreCareerSlot` (sem mensagem no log). O commit `3b24b62` (painel de slots com `accessibilityElement(children: .contain)`, espera da partida da liga pelo botão de concluir e até 25 arrastos no `revealVisible`) gerou a nº 49 (`38460063704`), que falhou em 2 testes: `FootballFlowUITests.testLeagueRowsOpenClubProfileMatchesAndRoundsNavigate` (`Ficha do clube 2 não abriu`) e `FootballF5UITests.testBankSimulatorChangesProjectionAndResetRestoresIt` (sem mensagem no log). O de Ajustes passou. O commit `74a9d5f` (toque repetido na ficha do clube e identificadores do painel de caixa) gerou a nº 50 (`38466508259`), que falhou nos mesmos 2 testes. O commit `570b4bc` (simulador do banco com identificadores próprios; linha da liga como `Button` com destino explícito) gerou a nº 51 (`38473131516`), que falhou só na liga, com a mesma mensagem; o teste do banco passou. O commit `9e8bb88` (sonda de toque no segmento de seção, para separar falha da tela da liga de falha do toque na linha) gerou a nº 52 (`38478599034`), que falhou só na liga, com a mesma mensagem. O commit `69059e9` (área de toque da linha inteira da liga, com `contentShape`) gerou a nº 53 (`38483280391`), que falhou por infraestrutura: o runner não subiu no simulador (`Application ".xctrunner" is unknown to FrontBoard`), então nenhum teste rodou. A nº 54 (`38485631509`, mesmo commit) falhou só na liga, sem mensagem desta vez (a sonda de diagnóstico foi removida). O commit `493ecef` (linhas de jogador, artilharia e partidas tocáveis) gerou a nº 55 (`38489827076`), que **passou nos dois dispositivos** (iPhone e iPad). O TestFlight nº 30 (`38497408024`) foi disparado a partir deste commit e terminou com sucesso às 00:29 (Brasília). Captura nº 63 (`38436802714`, commit `7d65869`) cancelada. O `feature/entrega-a-ritmo` não tem o nome duplicado. O ref do 1.1 (20) foi `polimento/build-20`. |
| Feedback do 12 (07/out) | Testado: onboarding e tela de abertura saíram grandes e desproporcionais. Causa: a imagem de fundo alargava o layout. Corrigido no commit `9c6fa17` (fundo que não mexe no layout, largura máxima, fontes menores). Vai no **1.1 (13)**, ref `feature/entrega-a-ritmo`, junto com as próximas fatias da Entrega A. Escrito sem compilador: só o CI e o aparelho confirmam. |
| Entrega A (conteúdo do build 12) | Branch `feature/entrega-a-ritmo`, a partir do mesmo commit do 11. Já tem: uma lenda no começo da carreira e uma por temporada (sem convidado por partida), tela de abertura (carregamento, Continuar, Novo jogo, Opções). Escrito, não compilado: só o CI valida. |
| Hall das Lendas | Já unido às duas branches acima. Não entra no TestFlight do Football; validado pelo workflow "iOS app validation". |

Regras que valem para todos os prompts:
- O agente **não altera código**. Dispara, acompanha e relata. Quem corrige sou eu, a partir do relatório.
- Nunca pular, desligar ou apagar teste para ficar verde.
- O workflow "Football TestFlight" roda um de cada vez e só guarda um pedido em espera (um pedido novo substitui o que estava esperando): não disparar um novo enquanto outro estiver em andamento.
- O número do build é consumido só no upload. Se um run for barrado no gate, o mesmo número pode ser usado de novo.

---

## Prompt A — Confirmar o build 1.1 (11) no TestFlight

O run `37572402802` já terminou com sucesso (upload e ativação às 02:53). Este prompt só confirma que o build está disponível para os testadores.

```
Projeto socialbot114-cell/ios-app-factory, workflow "Football TestFlight".
Confirme o resultado do run 37572402802 (version 1.1, build 11): todos os passos devem estar em sucesso, incluindo "Upload TestFlight" e "Activate internal TestFlight after Apple processing". Se tiver acesso ao App Store Connect, confirme que o build 1.1 (11) está "Pronto para testar" no grupo interno. Responda em duas linhas: resultado e horário (Brasília, UTC-3). NÃO dispare nada e NÃO altere código.
```

---

## Prompt B — Build 1.1 (13), histórico: não usar (número consumido; ver "Estado agora")

O 1.1 (12) já foi enviado. O 13 corrige o layout do onboarding e da abertura, cria o app **Lendas** e traz a comemoração de vitória.

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 13
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento e que o build 13 ainda não foi usado (artefato football-release-1.1-13 não pode existir em runs anteriores).
Acompanhe o run até o fim. NÃO altere código.
Se passar: responda "1.1 (13) enviado" com o horário de Brasília.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro e a hierarquia anexada (procure "Hierarquia:" no log), e o número de testes que passaram. O build 13 continua livre nesse caso.
O que há de novo: fundo das telas de abertura e onboarding sem desproporção, app Lendas no celular (vitrine das seis cartas, pacote e craque da temporada), confete na vitória da partida ao vivo.
```

## Prompt E — Build 1.1 (14), vida do jogo

Só depois que o 1.1 (13) terminar e for testado.

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 14
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento e que o build 14 ainda não foi usado (artefato football-release-1.1-14 não pode existir em runs anteriores).
Acompanhe o run até o fim. NÃO altere código.
Se passar: responda "1.1 (14) enviado" com o horário de Brasília.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro e a hierarquia anexada, e o número de testes que passaram. O build 14 continua livre nesse caso.
O que há de novo: sala de espera integrada ao FutOS (papel de parede, barra de status e relógio do celular, perfis com nome do treinador e escudo, digital para desbloquear, ilha e centro de notificações com as notificações reais da carreira ativa mais avisos de ambiente), puxar do topo para baixo no celular abre as notificações, avisos que reagem aos resultados, celebração de goleada e título, números do caixa que contam, sequência de dias.
```

## Prompt F — Build 1.1 (15), Academia v1

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 15
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento e que o build 15 ainda não foi usado (artefato football-release-1.1-15 não pode existir em runs anteriores).
Acompanhe o run até o fim e NÃO cancele nenhum passo, em especial "Activate internal TestFlight after Apple processing" (ele espera a Apple processar, de 2 a 15 minutos). NÃO altere código.
Se passar: responda "1.1 (15) enviado e ativado" com o horário de Brasília.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro e a hierarquia anexada, e o número de testes que passaram. O build 15 continua livre nesse caso.
O que há de novo: app Academia (base), potencial estimado, traços, mentor, observação, foco individual, peneira por região.
```

## Prompt G — Build 1.1 (17), Academia v2, HUD real e relatório de equilíbrio

**Concluído:** o run 27 enviou e ativou o build 17 às 21:29 (Brasília). Não reenviar este prompt.

O 1.1 (15) já está aprovado. O 1.1 (16) falhou no teste de equilíbrio e foi substituído por este 17: use só este prompt.

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 17
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento e que o build 17 ainda não foi usado (artefato football-release-1.1-17 não pode existir em runs anteriores).
Acompanhe o run até o fim e NÃO cancele nenhum passo, em especial "Activate internal TestFlight after Apple processing". NÃO altere código.
Quando o passo "Test iPhone and iPad" terminar, procure no log do job a linha que começa com "BALANCE" e copie a linha inteira na resposta.
Se passar: responda "1.1 (17) enviado e ativado", o horário de Brasília e a linha BALANCE.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro, a hierarquia anexada (se houver) e o número de testes que passaram. O build 17 continua livre nesse caso.
O que há de novo: Sub-15 na base, parcerias de captação com escola e clube parceiro, campeonato de base simulado com minutos, painéis de captação e campeonatos no app Academia, o HUD real (bateria, sinal, data, hora e escudo na barra do celular e na sala de espera), o mercado com busca por nome, ordenação e "Mostrar mais", o atalho "jovem pronto para decidir" no Gestor, estados vazios que explicam o que esperar na Academia e a faixa de desbloqueios no topo do celular (conquistas e metas concluídas). Correção: o teste de equilíbrio passou a medir jovens por carreira (o 16 falhou nele).
```

## Prompt H — Build 1.1 (18), vitrine da Loja Aplicativo

**Enviado e ativado no TestFlight interno às 23:34 (Brasília), run `37711891690` (nº 28). Não reenviar.** O usuário pediu o envio em 07/out às 21:48 (Brasília), depois de aprovar o 1.1 (17). A janela de dois dias do 17 iria até 09/out às 21:29; a antecipação é decisão do usuário. Não reenviar nem substituir o 17. O código é do commit `4348a38` e foi escrito sem compilador: a primeira compilação é o CI deste run.

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 18
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento e que o build 18 ainda não foi usado (artefato football-release-1.1-18 não pode existir em runs anteriores).
Acompanhe o run até o fim e NÃO cancele nenhum passo, em especial "Activate internal TestFlight after Apple processing" (ele espera a Apple processar, de 2 a 15 minutos). NÃO altere código.
Quando o passo "Test iPhone and iPad" terminar, procure no log do job a linha que começa com "BALANCE" e copie a linha inteira na resposta.
Se passar: responda "1.1 (18) enviado e ativado", o horário de Brasília, a linha BALANCE e o nome e o ID do artefato football-release-1.1-18.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro, a hierarquia anexada (se houver) e o número de testes que passaram. O build 18 continua livre nesse caso.
O que há de novo: app Loja (ícone de sacola) na grade do celular, com a vitrine dos cinco módulos Pro (Scout, Analytics, Market, Academy e Medical) em mistério, preços propostos e "Em breve". Nada é cobrado nesta versão. Mais as capturas das telas Academia, Loja e fila de desbloqueios.
```

---

## Prompt C2 — Prints das telas novas (iPhone), para o artefato de entregas

**Concluído com sucesso às 22:24 (Brasília): run `37711892098` (nº 60), artefato `screenshots-manager-futebol` (ID 11522286457).** A revisão do usuário achou problemas de tela (faixa cobrindo títulos, rótulos cortados, captura de título errada); há ajustes no código. Repetir este prompt para confirmar. Pode rodar junto com H (workflow diferente). Estados: `academy` (Academia), `market` (mercado), `phone` (celular), `store` (Loja), `unlock` (fila de desbloqueios) e `title` (abertura). Os prints mostram o código atual (`4348a38` ou mais novo), não o binário de cada build.

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "iOS simulator screenshots" (screenshots.yml) com:
  ref: feature/entrega-a-ritmo
  app: manager-futebol
  states: academy,market,phone,store,unlock,title
  families: iphone
Acompanhe até o fim. NÃO altere código.
Quando terminar, responda o resultado do run e o nome e o ID do artefato gerado. Se conseguir baixar e abrir as imagens, diga para cada uma, em uma linha: texto cortado ou sobreposto, botão principal fora da tela, tela vazia ou cores ilegíveis. Se não conseguir baixar, diga só o resultado do run e o nome do artefato.
```

---

## Prompt V — Validação do branch antes de cada build (obrigatória com commits novos; não gasta build)

**Não gera build do TestFlight:** não consome o número do build nem o intervalo de dois dias. Roda a mesma etapa de testes (iPhone e iPad) do build, no branch escolhido. Pode rodar junto com o Prompt C2 (workflow diferente).

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "iOS app validation" (validate.yml) com:
  ref: <branch escolhido pelo usuário; ver "Estado agora">
  app: manager-futebol
Acompanhe até o fim e NÃO altere código. Quando terminar, responda, para iPhone e para iPad: passou ou falhou em cada etapa; se falhou, o nome exato de cada teste que falhou, a linha do erro e a hierarquia anexada (se houver).
```

Validação nº 43 (`37825748681`, head `502af64`) passou nos dois dispositivos e cobriu o 1.1 (19). A validação nº 55 (`38489827076`, head `493ecef` de `polimento/build-20`) passou nos dois dispositivos e cobriu o 1.1 (20). Commits só de docs não mudam o build; qualquer commit de código muda. Para o 1.1 (21), repita este Prompt V no branch escolhido e só dispare se passar em iPhone e iPad. Se falhar, o número 21 continua livre: nada foi consumido.

## Prompt I — Build 1.1 (19), histórico: não usar (número consumido; enviado em 08/out às 18:50, run `37841387343`)

**Histórico. Já enviado.** O texto abaixo fica como registro do que o 19 contém. Não usar: o número 19 está consumido.

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 19
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento, que o build 19 ainda não foi usado (artefato football-release-1.1-19 não pode existir em runs anteriores) e que já passaram dois dias da ativação do 18 (09/out, 23:34 Brasília), salvo decisão do usuário.
Acompanhe o run até o fim e NÃO cancele nenhum passo, em especial "Activate internal TestFlight after Apple processing". NÃO altere código.
Quando o passo "Test iPhone and iPad" terminar, procure no log do job a linha que começa com "BALANCE" e copie a linha inteira na resposta.
Se passar: responda "1.1 (19) enviado e ativado", o horário de Brasília, a linha BALANCE e o nome e o ID do artefato football-release-1.1-19.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro, a hierarquia anexada (se houver) e o número de testes que passaram. O build 19 continua livre nesse caso.
O que há de novo: Finanças ganha a visão geral do Banco (saldo, fôlego em meses, receitas e despesas do mês com tendência e alerta), barras de receita por origem e de despesa por categoria, comparação entre temporadas, a linha da evolução do saldo e o orçamento da temporada por área, com meta e aviso ao estourar. Em Ajustes > Avisos e movimento, o Ritmo escolhe entre Clássico e Imersivo; a escolha fica salva e já muda a comemoração de vitória (menos confete, que termina antes); o ritual de virada e a tela de bloqueio ainda não mudam. A simulação rápida deixa o resumo no Histórico de ações (Ajustes), e o aviso continua o mesmo. Por dentro, sem mudança de tela: o coordenador de apresentações (FLX-01 v1), o passo do dia de jogo (FLX-03 v1) e a classificação de vitória grande (ANI-03 v1) e as frases da faixa de resumo (PIL-05 v1) o limite da tela de bloqueio do Clássico e o painel de decisões do ritual de virada (PIL-03 v3). Ligados às telas sem captura: vitória grande no fim de jogo, barra "Próximo passo" embaixo do Gestor, o resumo da simulação rápida numa faixa que some sozinho e a Loja refeita no padrão da Academia (três números no topo, cada módulo com cor própria, "O que vai ter" aparecendo direto). Confirmações antes de trocar de clube, demitir, aceitar uma proposta de venda ou perdoar um aporte, e "Aceitar desafio" não substitui a carreira atual quando os espaços estão cheios. Nenhuma mudança de jogo.
```

---

## Prompt J — Build 1.1 (20), histórico: não usar (número consumido; enviado em 14/out às 00:29, run `38497408024`)

**Cumprido: o 1.1 (20) foi enviado e ativado no TestFlight interno às 00:29 (Brasília) de 14/out, run `38497408024` (nº 30), a partir de `polimento/build-20` @ `493ecef`, não de `feature/entrega-a-ritmo` como este prompt dizia. Não disparar de novo. A janela de dois dias do 20 vai até 16/out às 00:29 (Brasília).** Esta sessão não consegue disparar workflows.

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 20
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento, que o artefato football-release-1.1-20 não existe em runs anteriores e que o Prompt V passou no mesmo commit que você está disparando.
Acompanhe o run até o fim e NÃO cancele nenhum passo, em especial "Activate internal TestFlight after Apple processing". NÃO altere código.
Quando o passo "Test iPhone and iPad" terminar, procure no log do job a linha que começa com "BALANCE" e copie a linha inteira na resposta.
Se passar: responda "1.1 (20) enviado e ativado", o horário de Brasília, a linha BALANCE e o nome e o ID do artefato football-release-1.1-20.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro, a hierarquia anexada (se houver) e o número de testes que passaram. O build 20 continua livre nesse caso.
O que há de novo em relação ao 19: guia do primeiro uso da carreira e destaque do que pede atenção (commits `1a8d515` e `4939c9a`, de outro agente, ainda sem validação até o Prompt V passar). Virada como vitória grande no fim de jogo (`e6552d4`, ANI-03 v3 parcial, sem compilador e sem captura). Os limites de tempo dos workflows de validação e de build passam a 120 min.
```

---

## Prompt C — Capturas de tela (iPhone e iPad)

Pode rodar junto com B (workflow diferente).

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "iOS simulator screenshots" (screenshots.yml) com:
  ref: feature/entrega-a-ritmo
  app: manager-futebol
  states: onboarding,onboarding-mode,loading,title,title-new,title-shade,offseason-recap,offseason-contracts,offseason-review,offseason-pack,offseason-holiday,offseason-sponsor,offseason-preseason,offseason-kickoff
  families: iphone,ipad
Acompanhe até o fim. NÃO altere código.
Quando terminar, liste os nomes e IDs dos artefatos gerados. Se conseguir baixar e abrir as imagens, para cada uma diga em uma linha: texto cortado ou sobreposto, botão principal fora da tela, tela vazia ou cores ilegíveis. Se não conseguir baixar, diga só o resultado do run e os nomes dos artefatos.
```

## Prompt D — Hall das Lendas (validação do app novo)

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "iOS app validation" (validate.yml) com:
  ref: feature/entrega-a-ritmo
  app: hall-das-lendas
Acompanhe até o fim. NÃO altere código.
Relate: iPhone e iPad separadamente, quantos testes de domínio e de interface passaram, e para cada falha o nome do teste, a linha do arquivo e a mensagem de erro.
```

---

## Já dá para testar agora: build 1.1 (11)

Este build está no TestFlight interno desde 07/out às 02:53. Teste o que ele tem:
1. **Onboarding:** instalar limpo (ou apagar o app). Esperado: cinco páginas, escolha de dificuldade, depois as propostas de clube.
2. **Ritual de fim de temporada:** simular até o fim e tocar "Encerrar temporada". Passar por todas as etapas (apito, contratos, balanço, pacote, férias, patrocinador, pré-temporada, estreia); fechar o app no meio e voltar pelo painel "Entre temporadas".
3. **Craque eterno:** no ritual chega o pacote da primeira lenda; abrir e conferir no elenco. No modo Fácil (Ajustes), o Gestor mostra "Convidar um craque" para uma partida. Isso muda no build 12: lá a lenda vem no começo da carreira e o convidado deixa de existir.
4. **Qualquer erro ou travada:** anotar o que estava fazendo e tirar captura de tela.

## O que você testa (builds 11 a 17, conforme o item)

Roteiros completos em `docs/PLANO-DE-TESTES.md`, seção 5. Resumo para a primeira noite:

1. **Abertura (build 13, layout corrigido):** abrir o app. Esperado: carregamento com dica, depois a tela com Continuar, Novo jogo e Opções. Tocar em Opções e abrir "Reduzir movimento" e as carreiras salvas.
2. **Primeira abertura limpa:** apagar o app e instalar de novo. Esperado: Novo jogo, onboarding de cinco páginas, escolha de dificuldade, proposta de clube.
3. **Lenda inicial (build 12):** aceitar um clube. Esperado: o pacote de craque eterno abre sozinho na primeira visita ao Gestor; abrir e tocar "Escalar o craque". Fechar o app antes de abrir o pacote e reabrir: o pacote continua esperando.
4. **Jornada diária:** abrir o Gestor, jogar uma rodada ao vivo, ver o resultado. Contar toques. Anotar onde ficou perdido.
5. **Fim de temporada (ritual):** simular até o fim (ou usar um save perto do fim) e tocar "Encerrar temporada". Passar por todas as etapas, inclusive fechar o app no meio e voltar pelo painel "Entre temporadas". Esperado: um novo pacote de lenda chega no ritual.
6. **App Lendas (novo no 13):** abrir o app "Lendas" (coroa dourada) na grade do celular. Esperado: seis cartas (as ainda não ganhas aparecem bloqueadas), o pacote esperando no topo e a lenda da temporada. Tocar numa carta abre o detalhe com os números. No Gestor, só um atalho pequeno.
7. **Vitória:** ganhar uma partida ao vivo. Esperado: confete curto no banner de vitória (não aparece com "Reduzir movimento").
8. **Build 14, sala de espera:** abrir o app. Esperado: relógio, perfis com escudo, digital (segurar 0,7 s para entrar), espaço livre tracejado, ilha no topo trocando de aviso, arrastar do topo para baixo abre o centro. Abrir de novo no dia seguinte: selo "2 dias seguidos".
9. **Build 14, vida:** no celular, abrir o centro de notificações e ver a seção "No celular hoje". Depois de ganhar, perder ou empatar, os avisos devem reagir. Goleada (3 gols de diferença) mostra "Goleada!" com mais confete. Título ou acesso mostra confete no resumo da temporada. O caixa muda contando os números.
10. **HUD real (build 17):** na sala de espera, tocar num perfil com carreira. Esperado: data e hora do jogo, escudo do clube, barras de sinal e bateria com o percentual da energia do treinador (verde acima de 60, amarela de 30 a 59, vermelha abaixo de 30). Perfil vazio: data do aparelho, bateria apagada e traço no lugar do percentual. Entrar na carreira: a bateria do celular mostra a mesma energia. Gastar energia (uma conversa ou uma ação), mandar o app para o segundo plano (isso salva a carreira) e abrir de novo: a bateria da sala deve mostrar o novo valor. Carreira salva antes do 16: traços até o próximo save.
11. **Academia v2 (build 17):** no app Academia, conferir Sub-15 na lista, o painel de Captação e parcerias (contratar uma escola ou clube e ver o aviso de caixa), o painel de Campeonatos (resultado no meio da temporada) e, na ficha de um jovem, os minutos de jogo.
12. **Academia (build 15):** no celular, abrir o app Academia (capelo azul). Esperado: nível, ações e jovens; programa de formação; peneira; jovens por categoria com "Potencial 72–84" (faixa, não número exato). Tocar num jovem: ficha com faixa de potencial, perfil, foco, mentor, observar, promover, dispensar. Observar gasta 1 ação e R$ 15 mil e estreita a faixa; os traços aparecem aos poucos (6 e 12 semanas de observação). Uma ação volta a cada dia de jogo.
13. **Mercado (build 17):** abrir o Transfer, aba Livres e aba Clubes. Esperado: o campo "Buscar por nome" acha "joao" e "João" e ignora maiúscula e acento; "Ordenar por" troca entre Geral, Potencial, Idade, Valor e Fim de contrato; "Mostrar mais (N restantes)" soma 30 atletas por toque e some no fim da lista; mudar a busca, a ordenação ou o filtro de posição volta ao começo da lista. Na aba Livres, quem não tem contrato aparece no fim em "Fim de contrato".
14. **Academia e Gestor (build 17):** na Academia, cada faixa vazia (parcerias, campeonato, categorias) diz o que esperar. Nível, Ações e Jovens rolam para o novo número ao mudar (com "Reduzir movimento", trocam direto). No Gestor, em "Precisa da sua atenção", aparece "N jovem(ns) pronto(s) para decidir na Academia" quando um jovem já teve todos os traços revelados (de 6 a 12 semanas de observação, conforme o jovem); tocar leva à Academia.
15. **Fila de desbloqueios (build 17):** ganhar uma conquista ou concluir uma meta. Esperado: uma faixa no topo do celular, logo abaixo da barra de status, com o nome e o detalhe; some sozinha em uns 4 segundos; tocar abre Troféus ou Metas; arrastar para cima fecha; puxar para baixo abre o centro de notificações. Se houver mais de um aviso, aparecem um de cada vez. Com "Reduzir movimento" ligado, sem confete e sem animação de entrada.
16. **Loja (build 18, e depois 19):** abrir o app Loja (ícone de sacola na grade do celular). Esperado: cinco módulos Pro (Scout, Analytics, Market, Academy e Medical), com prévia borrada, "Em breve" em cada um e preços propostos. A partir do 19, há também três números no topo (Comprados 0/5, A partir de R$ 4,90, Até R$ 14,90), cada módulo com cor própria, e "O que vai ter" aparece direto em cada cartão, sem tocar em nada (no 18 ficava recolhido). No Market Pro, os seis sinais aparecem listados e a prévia mostra três, com barras borradas. Não deve haver cobrança, cartão nem botão de compra.
17. **Banco (build 19):** abrir Finanças. Esperado: painel "Visão geral" com saldo, fôlego em meses, receitas e despesas do mês e, quando houver risco, um aviso em destaque. Depois, "Receita por origem", "Despesas por categoria", "Temporadas em comparação" e "Evolução do saldo" aparecem em barras e em linha, com "Início" e "Agora" embaixo da linha. Com menos de dois meses fechados, a linha diz que aparece depois. Em "Orçamento da temporada", cada área (Transferências, Folha, Estrutura e Base) mostra gasto e meta, com "Perto do limite" a 80% e "Estourou" ao passar da meta. Em Ajustes > Avisos e movimento, troque o Ritmo entre Clássico e Imersivo, feche o app e abra de novo: a escolha deve continuar. Depois, com o Ritmo em Clássico, ganhe uma conquista (item 15): o confete da faixa deve ser menor e acabar antes; no Imersivo, deve ser igual ao build 18. Em seguida, use a Simulação rápida no Gestor: o resumo deve aparecer também em Ajustes > Histórico de ações.
18. **Qualquer erro, travada ou texto estranho:** anotar o que estava fazendo e tirar captura de tela.

**Ligados às telas sem captura (build 19): o layout não foi visto, então conferir com atenção.**

a) **Simulação rápida (Gestor):** tocar em "Simulação rápida". Esperado: uma faixa no topo do painel com o resumo ("N dia(s) de calendário simulado(s)..."), que some sozinha em uns 4 segundos ou quando você toca nela. Não deve abrir alerta. O mesmo resumo deve aparecer em Ajustes > Histórico de ações. Se a faixa cobrir o título ou o cartão do clube, anotar. "Simular até a próxima decisão" continua em alerta de propósito, porque para numa decisão do treinador: se nada avançar, o alerta deve mostrar só o motivo, sem "0 dia(s) simulado(s)". Conferir o texto do alerta.

b) **Próximo passo (Gestor):** uma barra fixa embaixo do painel, com uma ação só: "Responder a coletiva", "Revisar a escalação", "Jogar a partida" ou "Avançar o dia". Tocar deve levar à ação certa. Durante uma partida em andamento a barra não aparece. Anotar se ela cobre o último cartão do painel ou fica perto do indicador do celular.

c) **Vitória grande (fim de jogo):** só aparece num clássico ganho por um ou dois gols. Se acontecer, a faixa deve dizer "Vitória grande! Três pontos que pesam." e a chuva de confete deve ser maior que a de uma vitória comum. Se não acontecer neste build, dizer que não apareceu.

d) **Loja no padrão da Academia (`2dc7356`, sem captura):** esperado: três números no topo (Comprados 0/5, A partir de R$ 4,90, Até R$ 14,90), cartões com cor própria, ícone num quadrado colorido, "O que vai ter" aparecendo direto e, no Market Pro, a prévia com cadeado e barras borradas. Se o R$ 14,90 encolher demais nos números, se algum texto de cartão ficar cortado ou se alguma barra sair do lugar, anotar o módulo e o aparelho.

e) **Confirmações novas (`4e12f5b`, sem captura):** antes de aceitar um convite (Clube > História), demitir um membro (Clube > Comissão técnica), aceitar uma proposta de venda (Mensagens) ou perdoar um aporte (Banco), aparece uma pergunta com o efeito. Esperado: Cancelar não muda nada; confirmar faz a ação. Se o texto estiver cortado ou o diálogo não aparecer, anotar qual deles.

f) **Aceitar desafio (`02b5773`, sem captura):** em Ajustes > Modos de jogo, com os três espaços de carreira ocupados, o aviso deve aparecer e a carreira atual não pode ser trocada. Com espaço livre, o desafio funciona como antes. Testar com os três espaços cheios, se possível.

g) Se algo estiver cortado, sobreposto ou fora da tela, tirar captura e anotar a faixa ou a barra.

## Relatório que o agente devolve para mim

```
Run:
Workflow e ref:
Versão e build:
Resultado (sucesso/falha/em andamento) e horário (Brasília):
Testes: N passaram, M falharam
Falhas (para cada uma): nome do teste, arquivo:linha, mensagem, hierarquia anexada (sim/não e o texto)
Artefatos (nome e ID):
Observações:
```

Quando você me trouxer isso, eu corrijo na branch certa e preparo o próximo build; o que ficar pendente entra no roadmap com data e hora.
