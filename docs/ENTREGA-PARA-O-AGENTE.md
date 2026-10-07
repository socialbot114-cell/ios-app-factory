# Pacote para o outro agente — disparar, acompanhar e relatar

Atualizado em 07/out/2026, 16:35 (Brasília; 1.1 (15) aprovado e enviado; 1.1 (16) pronto para disparar) em validação; 1.1 (16) pronto na branch) em validação) aprovado; Academia v1 pronta para o 15) aprovado; próxima frente: Academia) em validação) enviado ao App Store Connect, ativação interna a confirmar) enviado) em andamento) enviado; 1.1 (13) pronto para disparar). A rotina horária mantém este arquivo em dia; o estado real dos builds está na tabela de builds do `docs/ROADMAP-FUTOS.md`.

## Como usar quando você acordar

1. Leia a seção "Estado agora" para saber o que já passou.
2. Cole no outro agente, na ordem, os prompts A, B, C e D (cada um é independente; B só faz sentido se A estiver resolvido).
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
| 1.1 (15) | **Aprovado e enviado ao TestFlight interno (16:33 Brasília).** Run `37663919522` (nº 25), commit `e5439a3`: todos os passos concluídos, incluindo "Activate internal TestFlight". Academia v1 liberada para teste. |
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

## Prompt G — Build 1.1 (16), Academia v2 e relatório de equilíbrio

Só depois que o 1.1 (15) terminar e for testado.

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 16
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento e que o build 16 ainda não foi usado (artefato football-release-1.1-16 não pode existir em runs anteriores).
Acompanhe o run até o fim e NÃO cancele nenhum passo, em especial "Activate internal TestFlight after Apple processing". NÃO altere código.
Quando o passo "Test iPhone and iPad" terminar, procure no log do job a linha que começa com "BALANCE" e copie a linha inteira na resposta.
Se passar: responda "1.1 (16) enviado e ativado", o horário de Brasília e a linha BALANCE.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro, a hierarquia anexada (se houver) e o número de testes que passaram. O build 16 continua livre nesse caso.
O que há de novo: Sub-15 na base, parcerias de captação com escola e clube parceiro, campeonato de base simulado com minutos, painéis de captação e campeonatos no app Academia.
```

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

## O que você testa (build 13, quando chegar ao TestFlight)

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
11. **Academia v2 (build 16):** no app Academia, conferir Sub-15 na lista, o painel de Captação e parcerias (contratar uma escola ou clube e ver o aviso de caixa), o painel de Campeonatos (resultado no meio da temporada) e, na ficha de um jovem, os minutos de jogo.
12. **Academia (build 15):** no celular, abrir o app Academia (capelo azul). Esperado: nível, ações e jovens; programa de formação; peneira; jovens por categoria com "Potencial 72–84" (faixa, não número exato). Tocar num jovem: ficha com faixa de potencial, perfil, foco, mentor, observar, promover, dispensar. Observar gasta 1 ação e R$ 15 mil e estreita a faixa; os traços aparecem aos poucos (6 e 12 semanas de observação). Uma ação volta a cada dia de jogo.
13. **Qualquer erro, travada ou texto estranho:** anotar o que estava fazendo e tirar captura de tela.

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
