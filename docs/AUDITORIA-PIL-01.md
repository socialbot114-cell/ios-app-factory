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

## Lote 4: elenco e tática

Mesmo método. `Tatica/FootballSquadView.swift` (226 linhas) e `FootballTacticalPlansPanel.swift` (45 linhas), lidos por inteiro. Posições estimadas (cerca de ±50 pt).

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Elenco, clube selecionado, topo | Seletor de formação e o campo (toque num titular para trocá-lo), logo abaixo do cabeçalho e do plano de jogo | Não |
| Elenco, lista de jogadores | Nenhuma no topo: a lista por posição é a última seção, depois de cinco painéis | Não |
| Planos A/B, sem plano salvo | "Salvar o atual", cerca de 900 pt, abaixo da dobra | Não |
| Planos A/B, com plano salvo, partida em andamento | "Aplicar" desabilitado, sem motivo visível | Não |
| Sem clube selecionado | Corpo vazio. O início mostra a configuração antes, então não deve ser alcançado. | Não |

Achados:
1. **Aberto, baixa gravidade.** A lista de jogadores fica no fim da tela (`FootballSquadView.swift:59-73`). Para abrir um reserva é preciso rolar até o fim, porque titulares abrem pelo campo. Sugestão: um atalho "Reservas" perto da escalação.
2. **Aberto.** "Aplicar" dos planos A/B fica desabilitado durante a partida sem explicação (`FootballTacticalPlansPanel.swift:29`). É o mesmo padrão dos botões desabilitados do mercado e da academia.
3. **Aberto, fora do PIL-01.** "Escalação ideal" substitui a escalação inteira sem perguntar (`FootballSquadView.swift:35`). Não é destrutivo, mas desfaz a escalação atual sem confirmação.
4. **Sem mudança.** O seletor de formação é a primeira escolha da tela, e o campo funciona como ação. Passa em PIL-01.

## Lote 5: alertas, painel da liga e mensagens

Mesmo método, com leitura direta dos três arquivos. Não cobri `Liga/FootballLeagueViews.swift` (502 linhas) nem o painel de arcos de história (`FootballStoryArcPanel`), que a tela de alertas usa no topo.

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Alertas, com acontecimento pendente | Primeira escolha, logo depois do painel de arcos (altura não verificada) | Não |
| Alertas, "Tudo calmo" | Nenhuma: só texto | Não, a saída é a navegação |
| Liga, painel de análise | Nenhuma: painel só de leitura | Não, se a tela-mãe tiver ação (não auditada) |
| Mensagens, lista de conversas | Busca, lápis "Nova conversa" e grupos (escolhas) | Não |
| Mensagens, conversa com resposta pendente | Ações do cartão laranja, no fim da rolagem (a conversa rola até o fim ao abrir), e os atalhos fixos na base | Não |
| Mensagens, conversa só de leitura | Texto no rodapé; ações só nas mensagens | Não, há "Voltar", salvo quando a conversa abre por notificação |

Achados:
1. **Corrigido sem compilador.** "Convencer a ficar" ignorava o retorno de `promiseStarts`, que é `Bool`. Quando a promessa não podia ser criada, nada acontecia e nada avisava. Agora segue o padrão de "Prometer 3 jogos" e mostra o aviso (`Sources/Apps/Mensagens/FootballInboxView.swift`, cartão de atleta que quer sair).
2. **Aberto, decisão do usuário.** "Listar para venda" põe o atleta à venda sem confirmação (`FootballInboxView.swift:400-403`). "Recusar" recusa a proposta sem confirmação (`:417-420`). "Aceitar" já pede confirmação (`:53-65`). Sugestão: aplicar o mesmo padrão a "Listar para venda" e "Recusar".
3. **Aberto, baixa gravidade.** Numa conversa aberta por notificação, o botão "Voltar" some (`:204`). A saída fica com a navegação externa, que não foi auditada aqui.

## Lote 6: tabela da liga

Mesmo método, com leitura de `Liga/FootballLeagueViews.swift` por inteiro (502 linhas). Posições estimadas (cerca de ±50 pt).

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Liga, Série A ou B | Seletor de seção. Cada linha da tabela abre a ficha do clube. | Não |
| Liga, rodadas | Setas e seletor de rodada, depois da tabela inteira e da análise (muito abaixo da dobra) | Não |
| Liga, Copa com chave | Cartões das fases; cada partida abre o relatório | Não |
| Liga, Copa sem chave | Nenhuma: só o texto sobre as próximas fases | Não, há o seletor de seção |
| Liga, Artilharia | Linhas de artilheiros, que abrem a ficha | Não |
| Relatório ou pré-jogo | "Voltar". Sem ação para frente acima da dobra: os clubes ficam no fim. | Não |
| Ficha do jogador | "Voltar" e o link do clube, logo abaixo do cabeçalho | Não |
| Ficha do clube | "Voltar". O elenco começa cedo, com linhas que abrem a ficha do jogador. | Não |

Achados:
1. **Aberto, baixa gravidade.** A navegação de rodadas (`FootballLeagueViews.swift:118-150`) fica depois da tabela inteira e da análise. Quem quer ver a rodada atual precisa rolar bastante. Sugestão: um atalho "Rodada atual" perto do seletor de seção.
2. **Aberto, baixa gravidade.** A copa sem chave mostra só o texto sobre as próximas fases, sem ação (`:246-250`). Sugestão: dizer quando será o sorteio e oferecer um atalho para a tabela.
3. **Aberto, baixa gravidade.** O relatório e o pré-jogo não têm ação para frente acima da dobra. Os links dos clubes ficam no fim da página (`:382-389`). Sugestão: levar os links para o cabeçalho.

## Lote 7: banco e clube (telas principais)

Mesmo método, com leitura de `Banco/FootballFinanceView.swift` (256 linhas) e `Clube/FootballClubView.swift` (221 linhas). Os painéis que essas telas chamam em outros arquivos (empréstimo, projeção, extratos, diretoria) não foram auditados. Posições estimadas (cerca de ±50 pt).

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Banco, padrão | Nenhuma: a tela abre com seis painéis de leitura (visão geral, receitas, despesas, comparação, saldo e orçamento) | Não |
| Banco, aporte do treinador | "+ R$ 100 mil", "+ R$ 250 mil" e "+ R$ 500 mil", bem abaixo da dobra | Não |
| Clube, celular de 6,1 pol. ou maior | "Gestão do clube" (três links), logo depois do cabeçalho e do estádio | Não |
| Clube, celular pequeno | Os links ficam perto da borda da dobra | Não |

Achados:
1. **Aberto, média.** O Banco não tem ação visível sem rolar. A tela abre com seis painéis de leitura, e o aporte do treinador fica bem abaixo (`FootballFinanceView.swift:56-68`). Sugestão: pôr uma linha de ação logo abaixo da visão geral, com empréstimo ou aporte conforme o risco, e deixar os gráficos depois.
2. **Aberto, baixa gravidade.** O aporte pessoal gasta o dinheiro do treinador sem confirmação (`:60-66`). Hoje só avisa quando o caixa pessoal não cobre (`:62`).
3. **Aberto, baixa gravidade.** Em "Clube", a ilustração do estádio (190 pt, `FootballClubView.swift:47`) empurra "Gestão do clube" (`:139-146`) para perto da dobra em celulares pequenos. Sugestão: subir a gestão para logo abaixo do cabeçalho e reduzir a imagem.

## Lote 8: painéis do banco, da diretoria e dos arcos

Mesmo método, com leitura de `Banco/FootballCoachLoanView.swift` (57 linhas), `Banco/FootballStatementsPanel.swift` (90), `Banco/FootballCashProjectionView.swift` (193), `Clube/FootballBoardFinancePanels.swift` (50) e `Clube/FootballStoryArcPanel.swift` (88). Posições estimadas (cerca de ±50 pt).

| Painel e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Aportes a devolver, com aporte ativo | "Perdoar o saldo", com confirmação | Não |
| Extratos, com lançamentos | Seletor Clube/Treinador; linhas com origem abrem o detalhe | Não |
| Extratos, sem lançamentos | Só o seletor e o saldo, sem texto de vazio | Não |
| Projeção de caixa | "Simular contratação ou obra", fechado por padrão. O resumo é só leitura. | Não |
| Diretoria: avaliação e obra | Nenhuma: painéis de leitura | Não |
| Arcos abertos, em Alertas | Escolhas do arco e "Pedir informação", no topo da tela de acontecimentos | Não, mas um arco ocupa cerca de 500 a 600 pt |

Achados:
1. **Aberto, média.** Em Alertas, um arco aberto ocupa cerca de 500 a 600 pt. As escolhas ficam no limite da dobra em telas pequenas (`FootballStoryArcPanel.swift:32-66`). Esta é a altura que o lote 5 não tinha verificado. Sugestão: mostrar as três escolhas numa linha compacta, com a explicação atrás de um toque.
2. **Aberto, baixa gravidade.** Decisões de arco são imediatas, sem confirmação (`FootballStoryArcPanel.swift:52`). São decisões de jogo, com prazo, mas não há como desfazê-las. Decisão sua: pedir confirmação ou não.
3. **Aberto, baixa gravidade.** Sem lançamentos, o painel de extratos mostra só o seletor e o saldo, sem texto de vazio (`FootballStatementsPanel.swift:49-57`). Linhas sem origem ficam desabilitadas, sem explicação (`:75`).
4. **Reforça o lote 7.** No Banco, a ordem é projeção, aportes e extratos. A primeira ação fica abaixo da dobra: o simulador da projeção (`FootballCashProjectionView.swift:21-26`) e o aporte do treinador (`FootballFinanceView.swift:56-68`).

## Lote 9: metas, troféus, lendas, loja e contatos

Mesmo método, com leitura de `Metas/FootballQuestsView.swift` e `FootballGoalsPanels.swift`, `Trofeus/FootballAchievementsView.swift` e `FootballLegacyPanels.swift`, `Lendas/FootballLegendsView.swift`, `Loja/FootballStoreView.swift`, e `Contatos/FootballContactsView.swift` e `FootballContactRelationsView.swift`. Posições estimadas (cerca de ±50 pt).

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Metas | "Adotar uma meta" (menu), dentro do painel de metas, logo abaixo do topo | Não |
| Troféus, com linha do tempo longa | Nenhuma: a linha do tempo (até 20 entradas) vem antes da galeria | Não |
| Conquista desbloqueada | "Destacar no perfil" e o compartilhamento | Não |
| Conquista bloqueada | Nenhuma: só o progresso | Não, há "Voltar" |
| Lendas, com pacote pendente | "Abrir pacote", no topo | Não |
| Lendas, sem pacote | "Joga esta temporada" e os cartões da coleção | Não |
| Loja | Nenhuma: vitrine sem compra nesta versão | Não, há "Voltar" |
| Contatos | "Ver ficha" e a ação do primeiro contato | Não |

Achados:
1. **Aberto, média.** Em Troféus, a linha do tempo (até 20 entradas) fica antes da galeria. Abrir uma conquista exige rolar bastante quando a carreira já tem história (`FootballAchievementsView.swift:19-20`). Sugestão: galeria antes da linha do tempo, ou mostrar as cinco últimas entradas com "ver todas".
2. **Corrigido sem compilador.** "Destacar no perfil" ficava habilitado com o limite de destaques cheio, e o toque não fazia nada, porque `setHighlight` devolve falso. A dica abaixo já explicava, mas o botão parecia funcionar. Agora fica desabilitado nesse caso (`FootballLegacyPanels.swift`, `FootballTrophyDetailView`).
3. **Corrigido sem compilador.** "Recusar" num pedido que já não estava aberto deixava o aviso em branco, porque a resposta era nula. Agora mostra "Este pedido já não está aberto." (`FootballContactRelationsView.swift:45`).
4. **Aberto, baixa gravidade.** A Loja não tem ação nenhuma. É vitrine sem compra nesta versão, de propósito. Quando a compra for ligada, a ação principal precisa ficar no topo do cartão.
5. **Aberto, baixa gravidade.** "Trocar por outra" troca uma meta sem confirmação (`FootballGoalsPanels.swift:20`). Decisão sua: pedir confirmação ou não.

## Lote 10: rodada mágica e vida do treinador

Mesmo método, com leitura de `Rodada/FootballFantasyView.swift` (326 linhas) e de `Vida/FootballCoachLifeView.swift` (172), `FootballLifeContinuityView.swift` (86) e `FootballPersonalPlanView.swift` (116). Posições estimadas (cerca de ±50 pt).

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Rodada, sem resultado de rodada | Próxima rodada, depois o painel de detalhe (texto) e a escalação com "Sugestão" e "Salvar time" | Não |
| Rodada, com resultado de rodada | Nenhuma: o detalhe com 11 linhas expansíveis fica antes da escalação | Não, mas a ação do dia fica abaixo da dobra |
| Vida, padrão | Agenda do dia: as atividades, logo depois de condição e caixa | Não |
| Vida, planejamento de dias | Linhas de dia, depois de toda a agenda (cerca de 400 pt abaixo) | Não |
| Vida, bens e investimentos | "Comprar", "Aplicar" e "Resgatar", no fim da tela | Não |

Achados:
1. **Aberto, média.** Na Rodada Mágica, o detalhe da última rodada vem antes da escalação (`FootballFantasyView.swift:35-38`). Com resultado, são 11 linhas expansíveis antes de "Seu time dos sonhos" e de "Salvar time" (`:227-262`). A ação do dia fica abaixo da dobra. Sugestão: escalação antes do detalhe, ou o detalhe recolhido por padrão.
2. **Aberto, baixa gravidade.** "Vender" bens e "Resgatar" investimento agem sem confirmação (`FootballCoachLifeView.swift:121`, `:167`), e "Desmarcar" um dia também (`FootballPersonalPlanView.swift:108`). Há consequência em dinheiro ou na agenda. "Comprar" já avisa quando não pode. Decisão sua.
3. **Aberto, baixa gravidade.** O planejamento de dias fica depois da agenda do dia. Em telas pequenas, a primeira linha de dia fica abaixo da dobra. A agenda tem ações visíveis, então a tela passa em PIL-01.
4. **Padrão a seguir.** Vários botões explicam o bloqueio: "Marcar" fica desabilitado com o conflito escrito acima, "Compartilhar no Chuteira" mostra o motivo embaixo, e as atividades bloqueadas avisam ao toque. Vale replicar no mercado e na academia.

## Lote 11: marca e palpite+

Mesmo método, com leitura de `Marca/FootballGrowthView.swift` (157 linhas), `Marca/FootballBrandImageView.swift` (198), `Marca/FootballSponsorView.swift` (43), `Palpite/FootballBettingView.swift` (374) e das ações em `Core/FootballGrowth.swift`, `Core/FootballCareer+Betting.swift` e `Core/FootballCareer+Club.swift`. Posições estimadas (cerca de ±50 pt). Na Marca a altura varia mais, porque o histórico de movimentos muda a tela.

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Marca, com proposta de TV | "Assinar" da proposta, logo depois da pressão (cerca de 350 pt) | Não |
| Marca, sem proposta de TV | Nenhuma: as próximas ações ficam depois dos indicadores, da campanha e do contrato de imagem (cerca de 1.000 a 1.400 pt) | Não, há "Voltar" |
| Marca, "Lançar campanha" | Nenhuma: o botão fica depois dos indicadores e de três seletores (cerca de 900 a 1.250 pt). O motivo do bloqueio aparece acima dele | Não |
| Marca, contrato de imagem oferecido | "Assinar", depois da campanha (cerca de 1.100 a 1.500 pt) | Não |
| Marca, cota de patrocínio oferecida | "Fechar", no fim da tela, depois do patrocinador master (mais de 1.400 pt) | Não |
| Patrocínio, com propostas | "Assinar" da primeira proposta (cerca de 250 pt) | Não |
| Patrocínio, sem propostas | Nenhuma: só o texto de espera | Não, há "Voltar" |
| Palpite, carteira | "Bônus de fichas" (cerca de 200 pt). Na recarga fica desabilitado; o motivo agora aparece abaixo (achado 2) | Não |
| Palpite, jogos da rodada | Odds do primeiro jogo (cerca de 350 pt) | Não |
| Palpite, pausa de apostas ativa | Odds do primeiro jogo (cerca de 450 pt), habilitadas. O aviso da pausa fica no topo | Não |
| Palpite, bilhete com seleções | "Confirmar palpite", depois de todos os jogos da rodada (cada jogo ocupa cerca de 150 pt) | Não, mas a ação fica abaixo da dobra |
| Palpite, palpites de temporada | Odds dos seis clubes, depois de todos os jogos e do bilhete (cerca de 950 pt com quatro jogos) | Não |
| Palpite, jogo responsável | "Pausa de N dias", no fim da tela, depois de bilhetes e palpiteiros | Não |

Achados:
1. **Aberto, média.** A Marca põe as decisões no fim. A ordem é: métricas, pressão, TV, indicadores (com até oito movimentos e as definições), campanha, contrato de imagem, patrocinador master e cotas (`FootballGrowthView.swift:13-21`). Sem proposta de TV, a primeira ação fica entre 1.000 e 1.400 pt. Sugestão: pôr as propostas (TV, cotas e contrato de imagem) logo abaixo da pressão, e os indicadores depois delas. Decisão de layout.
2. **Corrigido sem compilador.** "Bônus de fichas" ficava desabilitado na recarga de quatro dias, sem motivo na tela. O aviso "O bônus volta a cada 4 dias de jogo." estava num caminho que o botão desabilitado nunca alcança, porque `claimDailyBonus` testa a mesma condição (`Core/FootballCareer+Betting.swift:188-196`). Agora o aviso aparece em texto abaixo dos botões enquanto a recarga durar, e o caminho morto saiu (`Sources/Apps/Palpite/FootballBettingView.swift`, `walletPanel`).
3. **Aberto, média.** "Confirmar palpite" fica depois de todos os jogos da rodada. Quem toca numa odd do primeiro jogo precisa rolar até o fim da lista para confirmar (`FootballBettingView.swift:34-35`, `:206-242`). Sugestão: uma barra fixa no rodapé com "Bilhete (N) · Confirmar", como a barra do Gestor (`.safeAreaInset`), ou o bilhete logo abaixo da carteira. Decisão de layout.
4. **Aberto, média.** Durante a pausa de apostas, as odds e o bilhete seguem habilitados. O aviso "Autoexclusão ativa" só sai ao confirmar o bilhete ou ao fazer um palpite de temporada (`FootballBettingView.swift:28-33`, `:159-180`; `FootballCareer+Betting.swift:158`). Sugestão: desabilitar as odds com o motivo acima da lista, ou mostrar o motivo no bilhete. Decisão sua: o que a pausa deve bloquear.
5. **Aberto, média, decisão sua.** "Pausa de 5, 10 ou 20 dias" age na hora, sem confirmação, e fica habilitada mesmo durante uma pausa. `selfExclude` grava o novo fim sem comparar com o atual (`FootballCareer+Betting.swift:207-209`). Assim, uma pausa de 20 dias pode ser encurtada para 5 com um toque. Sugestão: uma nova pausa só estende a atual, e a ação pede confirmação.
6. **Aberto, baixa gravidade.** Um toque em "Palpite de temporada" registra a aposta com o valor do stepper, que fica abaixo da lista. O botão mostra só a cotação (`FootballBettingView.swift:257-275`). Sugestão: mostrar o valor no botão, ou pôr o stepper acima da lista.
7. **Aberto, baixa gravidade.** "Fechar" nas cotas de patrocínio aceita a cota na hora (`FootballGrowthView.swift:148`). A palavra pode ser lida como "dispensar", e as outras propostas de contrato dizem "Assinar". Sugestão: "Assinar", com o mesmo aviso de falha de `FootballSponsorView.swift:32`.
8. **Fora do PIL-01, sem confirmação.** "Assinar" da TV (`FootballGrowthView.swift:66`), da cota (`:148`), do contrato de imagem (`FootballBrandImageView.swift:178`) e do patrocinador (`FootballSponsorView.swift:31`), e "Lançar campanha" (`FootballBrandImageView.swift:120-127`) agem sem pedir confirmação. Cada oferta mostra valores e prazo, mas o toque não confirma. Decisão sua.
9. **Código sem uso.** `campaignPanel` (`FootballGrowthView.swift:76-102`) é privado e não tem referência. A campanha da tela é a de `FootballBrandImageView.swift`. Sugestão: remover numa fatia de limpeza.
10. **Sem mudança (conferido).** Dois pontos que pareciam falhas silenciosas não são alcançados pela tela. `signTV` e `acceptSlotOffer` descartam o retorno, mas a oferta de TV some ao ser assinada, e há no máximo uma oferta por cota (`Core/FootballGrowth.swift:273-279`, `:312-337`). Propostas de patrocínio só aparecem sem contrato vigente (`Core/FootballCareer+Club.swift:372-376`), então "Assinar" não substitui um contrato em curso.
11. **Padrão a seguir.** "Lançar campanha" mostra o motivo do bloqueio acima do botão desabilitado, e as odds bloqueadas por integridade avisam ao toque (`FootballBettingView.swift:163-164`). Vale replicar no caso da pausa (achado 4).

## Lote 12: negócios

Mesmo método, com leitura de `Negocios/FootballBusinessView.swift` (177 linhas), `FootballBusinessDealsView.swift` (148), `FootballCollectionProjectView.swift` (115), `FootballCommercialDelegationView.swift` (86) e `FootballProjectLedgerView.swift` (78), e das ações em `Core/FootballCareer+Business.swift`, `Core/FootballBusinessDeals.swift` e `Core/FootballCommercialDelegation.swift`. A tela é longa, então as posições são estimativas grosseiras (cerca de ±150 pt abaixo de 1.000 pt).

| Tela e estado | Ação principal visível sem rolar | Beco sem saída? |
|---|---|---|
| Negócios, padrão | "Ampliar" da loja (cerca de 250 pt) | Não |
| Coleção, sem projeto | "Lançar coleção", desabilitado com o motivo acima quando há bloqueio (cerca de 610 a 650 pt, abaixo da dobra de 667 pt) | Não |
| Coleção, em andamento | Nenhuma: barras e ritmo, só leitura | Não, a tela tem outras ações |
| Gerente comercial, sem contrato | "Contratar gerente" (cerca de 1.000 pt) | Não |
| Gerente comercial, ativo | "Atualizar ordens" e "Dispensar" (cerca de 1.050 pt) | Não |
| Retorno dos projetos | Nenhuma: leitura. A ação fica nas outras seções | Não |
| Naming, negociação aberta | "Enviar proposta", depois de pedido, duração e interruptor (cerca de 1.400 pt) | Não |
| Naming, ofertas sem negociação | "Negociar com X" (cerca de 1.300 pt) | Não |
| Naming, ofertas na seção do estádio | "Aceitar" (cerca de 2.200 pt) | Não |
| Projeto social, sem projeto | "Começar projeto", desabilitado com o motivo acima quando há bloqueio (cerca de 1.600 pt) | Não |
| Projeto social, em etapas | Nenhuma: barra e relatório | Não |
| Programas sociais | "Iniciar" ou "Encerrar" em cada linha (cerca de 2.300 pt) | Não |
| Amistosos | "Jogar em casa" por adversário (cerca de 2.700 pt) | Não |
| Agenda de amistosos, sem datas | Nenhuma: só o texto | Não, há "Voltar" |
| Propostas de empresários | "Aceitar" por proposta (cerca de 3.050 pt) | Não |

Achados:
1. **Aberto, média.** A tela é uma coluna de nove painéis. Só a loja tem ação perto do topo (`FootballBusinessView.swift:21`). Naming, programas, amistosos e empresários ficam entre 1.000 e 3.000 pt (`:22-29`). Sugestão: uma faixa "Decisões pendentes" no topo, com as propostas abertas, e o resto em seções que se recolhem. Decisão de layout.
2. **Aberto, baixa gravidade.** "Lançar coleção" fica abaixo da dobra em telas de 667 pt, depois do seletor de público, do porte e das métricas (`FootballCollectionProjectView.swift:54-69`). O motivo do bloqueio aparece acima do botão (linha 61), o que está certo; falta a posição. Sugestão: encurtar a explicação da previsão para o botão subir.
3. **Aberto, média.** "Jogar em casa" joga o amistoso na hora: não pede data nem confirmação, não mostra a receita e o desgaste (que a agenda mostra), e conta no limite de amistosos da temporada (`FootballBusinessView.swift:127-131`; `Core/FootballCareer+Business.swift:114-118`). Há também dois caminhos para amistosos na mesma tela: jogar já, acima, e agendar data, na agenda do hub (`FootballBusinessDealsView.swift:100-121`). Sugestão: um caminho só, a agenda, com a estimativa antes do toque. Decisão sua.
4. **Aberto, média.** "Aceitar" a proposta de naming direto custa 2 de humor da torcida (`Core/FootballCareer+Business.swift:74`), e a tela não avisa (`FootballBusinessView.swift:74-76`). A negociação mostra a reação antes de enviar (`FootballBusinessDealsView.swift:33-34`). Sugestão: mostrar "humor −2" no cartão da oferta.
5. **Fora do PIL-01, sem confirmação.** "Aceitar" o naming (contrato de várias temporadas) e a proposta de empresário (comissão), "Dispensar" o gerente comercial (`FootballCommercialDelegationView.swift:75`), "Cancelar" amistoso agendado (`FootballBusinessDealsView.swift:130`), e "Iniciar" e "Encerrar" programa social (`FootballBusinessView.swift:100`) agem na hora. "Ampliar" a loja gasta caixa, mas o custo aparece no botão. Decisão sua: pedir confirmação nas ações longas e nas destrutivas.
6. **Sem mudança (conferido).** Dois pontos que pareciam falhas silenciosas não acontecem pela tela. "Aceitar" o naming só tem ofertas quando não há contrato ativo: `refreshNamingOffers` esvazia a lista quando há contrato (`Core/FootballCareer+Business.swift:55-56`), e aceitar esvazia de novo. "Jogar em casa" só aparece quando `canPlayFriendly()` é nulo, e `playFriendly` só recusaria um adversário igual ao próprio clube, que a lista já filtra.
7. **Padrão a seguir.** "Começar projeto" e "Lançar coleção" mostram o bloqueio acima do botão desabilitado. "Ampliar" e "Turnê" avisam ao toque com o motivo (`FootballBusinessDealsView.swift:79-81`; `FootballBusinessView.swift:46`, `:138`). A negociação de naming manda cada resposta da marca para um aviso (`FootballBusinessDealsView.swift:38-42`). O retorno dos projetos é só leitura, e está certo.

## O que falta

- `.factoryPage()` tem ScrollView (`FactoryShared/FactoryShared.swift:143-149`), e as raízes de mercado e academia o usam (`FootballMarketViews.swift:67`, `FootballAcademyView.swift:47`). Os achados de dobra valem como escritos.
- Auditar os demais apps: Chuteira.
- Confirmar no aparelho as posições da tabela, principalmente o limite de 667 pt.
- Os achados 2 e 3 pedem decisão de layout antes de mexer no código.
