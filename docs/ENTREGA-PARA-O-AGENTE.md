# Pacote para o outro agente — disparar, acompanhar e relatar

Atualizado em 08/out/2026, 00:45 (Brasília). Checagem horária das 00:45: nenhum run novo desde o 1.1 (18). Revisão das capturas do run 60 (usuário): há ajustes de tela no código (faixa de desbloqueio, fila, grade do celular, ilha); falta repetir o run de capturas (Prompt C2). O 1.1 (19) está preparado (Prompt I) e não deve ser disparado antes de 09/out às 23:34 (Brasília). O 1.1 (18) foi enviado e ativado no TestFlight interno às 23:34 (run `37711891690`, nº 28, commit `f7ff16f`), com todos os passos verdes; artefato `football-release-1.1-18` (ID 11525165830). As capturas do run `37711892098` (nº 60) terminaram com sucesso às 22:24 (artefato `screenshots-manager-futebol`, ID 11522286457); não repetir. O próximo número é o 19, e não antes de 09/out às 23:34 (dois dias de teste do 18 a partir da ativação), salvo decisão do usuário. BAN-07 e BAN-08 (parte 1) estão na `feature/entrega-a-ritmo` depois de `f7ff16f`: não entram no 18. 1.1 (15) aprovado pelo usuário às 18:37. 1.1 (16) falhou no teste de equilíbrio (run 26, 19:22) e foi substituído pelo 1.1 (17), disparado pelo usuário às 20:09 (run 27, `37700560177`, commit `73f3df1`): passou em todos os passos e foi enviado e ativado no TestFlight interno às 21:29 (artefato `football-release-1.1-17`). Próximo: 1.1 (18), vitrine da Loja (item 45), só depois de dois dias de teste do 17 (até 09/out às 21:29), salvo decisão do usuário. A rotina horária mantém este arquivo em dia; o estado real dos builds está na tabela de builds do `docs/ROADMAP-FUTOS.md`.

## Como usar quando você acordar

1. Leia a seção "Estado agora" para saber o que já passou.
2. Cole no outro agente o prompt do que você quer agora: **H** dispara o 1.1 (18), e **C2** tira os prints das telas novas para o artefato. Os prompts A, B, E, F e G já foram cumpridos e ficam como histórico; C e D continuam válidos.
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
| 1.1 (19) | **Preparado, NÃO disparar antes de 09/out às 23:34 (Brasília).** Banco: visão geral, barras de receita e despesa, comparação entre temporadas e linha do saldo (BAN-07, BAN-08 partes 1 e 2, e BAN-09 v1). Commits `17933e7` (BAN-07), `fc9e5a4` (BAN-08 parte 1) e o commit da parte 2 desta checagem. Escrito sem compilador: o CI do build é a primeira compilação. Prompt I. |
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

## Prompt B — Próximo build: 1.1 (13), com as correções de tela e o app Lendas

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

## Prompt I — Build 1.1 (19), Banco (visão geral, gráficos e comparação)

**Preparado, não disparar antes de 09/out às 23:34 (Brasília).** O 1.1 (18) foi enviado e ativado às 23:34 de 07/out. O build 19 só deve sair depois de dois dias de teste do 18 a partir da ativação, salvo decisão do usuário. Esta sessão não consegue disparar workflows.

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
O que há de novo: Finanças ganha a visão geral do Banco (saldo, fôlego em meses, receitas e despesas do mês com tendência e alerta), barras de receita por origem e de despesa por categoria, comparação entre temporadas, a linha da evolução do saldo e o orçamento da temporada por área, com meta e aviso ao estourar. Nenhuma mudança de jogo.
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
16. **Loja (build 18):** abrir o app Loja (ícone de sacola na grade do celular). Esperado: cinco módulos Pro (Scout, Analytics, Market, Academy e Medical), com prévia borrada, "Em breve" em cada um e preços propostos. Abrir "O que vai ter" em um módulo e conferir o texto. No Market Pro, os seis sinais aparecem listados. Não deve haver cobrança, cartão nem botão de compra.
17. **Banco (build 19):** abrir Finanças. Esperado: painel "Visão geral" com saldo, fôlego em meses, receitas e despesas do mês e, quando houver risco, um aviso em destaque. Depois, "Receita por origem", "Despesas por categoria", "Temporadas em comparação" e "Evolução do saldo" aparecem em barras e em linha, com "Início" e "Agora" embaixo da linha. Com menos de dois meses fechados, a linha diz que aparece depois. Em "Orçamento da temporada", cada área (Transferências, Folha, Estrutura e Base) mostra gasto e meta, com "Perto do limite" a 80% e "Estourou" ao passar da meta.
18. **Qualquer erro, travada ou texto estranho:** anotar o que estava fazendo e tirar captura de tela.

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
