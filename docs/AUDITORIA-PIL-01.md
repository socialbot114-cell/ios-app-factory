# Auditoria PIL-01: telas do celular, Gestor e fim de jogo

Feita em 22/out/2026, 09:46 (Brasília), por leitura do código. Sem compilador e sem aparelho: as posições são estimativas pela ordem dos blocos (cerca de ±40 pt).

**Regra (ROADMAP-FUTOS.md, PIL-01):** toda tela tem uma ação principal visível sem rolar (botão, escolha ou atalho), e nenhuma é beco sem saída.

## Escopo desta passagem

- Celular: `Sources/PhoneOS/FootballPhoneHome.swift` e `FootballPhoneLockScreen.swift`.
- Gestor: `Sources/Apps/Gestor/FootballDashboardView.swift`, em cada estado.
- Partida: `Sources/Apps/Partida/FootballLiveMatchView.swift`, só o pré-jogo e o fim de jogo.
- Ainda não auditados: os outros apps (Academia, Ajustes, Elenco, Mercado e os demais).

## Tabela

| Tela (arquivo e estado) | Ação principal visível sem rolar | Beco sem saída? | Confiança e o que checar no aparelho |
|---|---|---|---|
| Celular, início | "O que fazer agora" (`phone-guide`), primeira linha da rolagem. A dock fica fixa fora da rolagem. | Não. Os apps têm "Início". | Alta. Não depende da altura. |
| Celular, tela de bloqueio, transição do dia | "Toque para pular" (`phone-unlock`), fixo fora da rolagem. | Não. | Alta. |
| Celular, tela de bloqueio, parada, com pendências da noite | "O que fazer agora" (`lock-guide`), dentro da rolagem. | Não. | Média. Pode ficar no limite em telas de 667 pt com a faixa de dias e um widget de resultado. |
| Celular, tela de bloqueio, parada, sem pendências | Cartão da próxima partida ou de folga (`lock-widget-next`). | Não. | Alta. |
| Gestor, dia de jogo | Barra fixa "próximo passo" (`next-step`). O rótulo segue o `matchdayStep`. | Não. | Alta. |
| Gestor, dia de folga | "Avançar o dia" fixo. | Não. | Alta. |
| Gestor, temporada encerrada | "Encerrar temporada" (`end-season`), depois do herói, dos avisos e do plano do dia. | Não. | Média. Pode ficar abaixo da dobra em telas pequenas com o plano do dia visível. |
| Gestor, entressafra | "Continuar" (`resume-offseason`), na mesma posição. | Não. | Média. |
| Gestor, demitido | "Aceitar" (`accept-job-*`), primeira linha depois dos avisos. | Não. | Média-alta. |
| Gestor, partida em andamento | "Voltar à partida" (`resume-match`), depois de herói, avisos, plano do dia e promessas. | Não, mas só se chega rolando. | Média. Provavelmente abaixo da dobra com três ou mais linhas no plano. |
| Partida, pré-jogo (minuto 0) | "Pausar" (`live-toggle`), depois do placar e do cartão de narração. | Não. "Sair" fica na barra. | Média. O cartão de guia da primeira carreira empurra o botão para baixo. |
| Partida, fim de jogo | "Concluir rodada" (`live-finish`), logo depois do placar e do resultado. | Não. É a saída, e confirma a rodada de propósito. | Alta. Checar em 667 pt com o cartão de guia. |

## Achados

1. **Corrigido sem compilador.** As linhas de rotina do plano do dia dentro do Gestor não faziam nada. Verificado no código: `FootballDayPlanPanel` chamava `onNavigate(.manager)`, e o Gestor já é o app aberto, então `openApp` não mudava. Agora "Jogar", "Avançar o calendário", "Encerrar a temporada" e as linhas de preparação fazem a mesma ação do botão fixo: `onPlayLive`, `requestQuickSimulation`, `beginOffseason` e o elenco. Arquivos: `FootballDayPlanPanel.swift` e `FootballDashboardView.swift` (linha 137).
2. **Aberto.** Estados sem barra fixa (partida em andamento, temporada encerrada, entressafra e demitido) deixam a única ação dentro da rolagem. Em partida em andamento, `Core/FootballMatchdayStep.swift:32` fala em uma "faixa de retomada", mas essa faixa não existe: a palavra só aparece no comentário. Sugestão: fixar uma barra nesses estados, ou criar a faixa de retomada em `FootballHome.swift`.
3. **Aberto.** Na tela de bloqueio, a ação de decisão fica dentro da rolagem, abaixo do relógio e da faixa de dias. Sugestão: pôr o primeiro item pendente acima da faixa de dias.
4. **Sem mudança.** No pré-jogo, o relógio começa sozinho e "Pausar" aparece depois do placar e da narração. "Sair" evita beco sem saída, então não há violação de PIL-01.

## O que falta

- Auditar os outros 20 apps e as telas de Mercado e Elenco.
- Confirmar no aparelho as posições da tabela, principalmente o limite de 667 pt.
- Os achados 2 e 3 pedem decisão de layout antes de mexer no código.
