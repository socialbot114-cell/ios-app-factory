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
2. **Corrigido sem compilador, exceto demitido.** Estados sem barra fixa (partida em andamento, temporada encerrada e entressafra) agora têm uma barra com a mesma ação do botão do painel. Demitido continua sem barra de propósito: "Aceitar" escolheria um dos três clubes pelo usuário. A tabela acima é de antes desta correção. Em partida em andamento, `Core/FootballMatchdayStep.swift:32` fala em uma "faixa de retomada", mas essa faixa não existe: a palavra só aparece no comentário. A barra fixa cobre esse caso; a faixa de retomada em `FootballHome.swift` continua sem ser criada.
3. **Aberto.** Na tela de bloqueio, a ação de decisão fica dentro da rolagem, abaixo do relógio e da faixa de dias. Sugestão: pôr o primeiro item pendente acima da faixa de dias.
4. **Sem mudança.** No pré-jogo, o relógio começa sozinho e "Pausar" aparece depois do placar e da narração. "Sair" evita beco sem saída, então não há violação de PIL-01.

## Lote 2: mercado e academia

Mesmo método (leitura do código, sem aparelho). Dois achados foram conferidos no código; posições são estimativas (cerca de ±50 pt).

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Mercado, aba Livres, sem resultados | Filtro de posição e busca. Sem botão para limpar o filtro. | Não |
| Mercado, aba Livres, elenco cheio | "Seção" e "Novo briefing". Todos os "+" desabilitados, e o motivo só aparece no rodapé. | Não, mas a compra fica bloqueada |
| Mercado, aba Clubes, Olheiros e Base | Seletores, "Enviar olheiro" e "Fazer peneira". | Não. "Enviar olheiro" fica perto da dobra em telas de 6,1 pol. |
| Mercado, aba Histórico | Nenhuma na seção. O seletor "Seção" fica acima. | Não, no nível da tela |
| Recrutamento, briefing sem sugestões | Só o ícone de lixeira. Nenhuma ação para afrouxar critérios. | Não, mas o bloco não tem ação para frente |
| Recrutamento, conversas abertas | "Aceitar", "Assinar" e "Desistir" por etapa. | Não |
| Academia, sem jovens | "Fazer peneira", sempre habilitado, com explicação ao toque. | Não |
| Academia, folha de um jovem | "Fechar" sempre. "Promover" e "Dispensar" no fim da rolagem. | Não |
| Academia, revelação da peneira | "Fechar". As linhas não abrem o jovem. | Não, mas o fluxo para na lista |

Achados:
1. **Corrigido sem compilador.** Num briefing em que todos os candidatos já estavam fixados, aparecia "Ninguém conhecido cumpre o briefing" ao lado das linhas fixadas. Agora o texto depende da lista completa de candidatos, e "Sugestões do olheiro" só aparece quando há sugestões novas (`Sources/Apps/Transfer/FootballRecruitmentView.swift`, `briefSection`).
2. **Aberto.** Botões desabilitados sem motivo visível: "+" de contratação (`FootballMarketViews.swift:157`) e "Promover" na folha de jovem (`FootballAcademyView.swift:423`). O motivo do elenco cheio fica no rodapé da lista. Sugestão: manter o botão habilitado e explicar ao toque, ou mostrar o motivo abaixo dele.
3. **Aberto.** "Promover" e "Dispensar" da folha de jovem ficam no fim da rolagem (`FootballAcademyView.swift:407-440`), embora o cabeçalho diga "decida quem sobe para o elenco principal" (`:28`). Sugestão: subir os três botões acima do painel de Potencial.
4. **Aberto.** O seletor "Seção" fica depois do bloco de recrutamento (`FootballMarketViews.swift:52-57`). Com um briefing de cinco sugestões, ele fica bem abaixo da dobra. Sugestão: pôr "Seção" acima do bloco.
5. **Aberto, baixa gravidade.** A revelação da peneira termina só em "Fechar", e as linhas não abrem o jovem (`FootballAcademyView.swift:236-263`).
6. **Fora do PIL-01, sem confirmação.** Ações destrutivas sem confirmação: excluir briefing (`FootballRecruitmentView.swift:211`), "Dispensar" no Base (`FootballMarketViews.swift:329`) e `FootballAcademyView.swift:128`. A dispensa de jovem da academia já confirma (`:55-63`, `:429-437`).

## Lote 3: ajustes e detalhe do jogador

Mesmo método. `Elenco/FootballPlayerViews.swift` é o detalhe do jogador com três folhas (renovação, proposta a outro clube e empréstimo). A lista do elenco fica em `Tatica/FootballSquadView.swift`, ainda não auditada.

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Ajustes, padrão | Seletor de dificuldade | Não |
| Ajustes, desafio ativo | Dificuldade desabilitada, com motivo. O primeiro controle habilitado fica abaixo. | Não |
| Ajustes, lista de cenários | "Aceitar desafio" fica bem abaixo da dobra | Não |
| Slots de salvamento, slot ativo | "Recomeçar", o único controle (com confirmação) | Não |
| Detalhe, jogador rival | Só "Fechar". "Fazer proposta" fica abaixo do perfil e dos atributos. | Não |
| Detalhe, próprio, renovável | "Negociar renovação" (perto de 500 a 600 pt) | Não |
| Detalhe, próprio, titular ou emprestado | Nenhuma: as ações ficam no bloco "Ações", no fim | Não |
| Detalhe, jogador livre | Nenhuma: só um texto que aponta para a aba Mercado | Não |
| Renovação, contraproposta | "Aceitar contraproposta" | Não |
| Renovação, sem pedido ou bloqueada | Nenhuma: só o motivo em texto | Não, há "Fechar" |
| Proposta a outro clube | "Enviar proposta" (perto de 550 a 610 pt) | Não |
| Empréstimo, sem destinos | Nenhuma: só o título da seção, sem motivo | Não, há "Fechar" |

Achados:
1. **Corrigido sem compilador.** O formulário de proposta a outro clube preenchia valor, salário e contrato só na última seção. Com a rolagem preguiçosa, o "Valor" aparecia como zero até o usuário descer. Agora o preenchimento acontece quando a primeira seção aparece, com a guarda `didLoad` (`Sources/Apps/Elenco/FootballPlayerViews.swift`, `FootballBidSheet`).
2. **Aberto.** No detalhe do jogador, as ações ficam depois do perfil e dos atributos, no bloco "Ações". Para jogador rival, "Fazer proposta" fica bem abaixo da dobra. Sugestão: uma linha de ação logo abaixo do cabeçalho.
3. **Aberto.** Empréstimo sem destinos mostra só o título da seção, sem motivo nem ação. Sugestão: explicar por que a lista está vazia.
4. **Aberto.** Renovação sem pedido ou bloqueada mostra texto ou um formulário em branco, sem próximo passo. A mesma folha abre pela caixa de mensagens e pela oferta de fim de temporada.
5. **Fora do PIL-01, sem confirmação.** "Desistir da conversa" encerra a renovação sem perguntar (`FootballPlayerViews.swift:390-393`). "Aceitar desafio" começa uma carreira nova com um toque (`Ajustes/FootballModesView.swift:30-37`). A venda já confirma (`:301-316`).

## O que falta

- `.factoryPage()` tem ScrollView (`FactoryShared/FactoryShared.swift:143-149`), e as raízes de mercado e academia o usam (`FootballMarketViews.swift:67`, `FootballAcademyView.swift:47`). Os achados de dobra valem como escritos.
- Auditar a lista do elenco (`Sources/Apps/Tatica/FootballSquadView.swift`) e os demais apps.
- Confirmar no aparelho as posições da tabela, principalmente o limite de 667 pt.
- Os achados 2 e 3 pedem decisão de layout antes de mexer no código.
