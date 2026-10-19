# Roadmap Manager de Futebol — builds 24 em diante

Escrito em 16/out/2026 (horário de Brasília) e atualizado em 17/out, depois dos builds 24 e 25.
Este documento continua o `docs/ROADMAP-FUTOS.md`, que é cronológico e muito longo. Aqui ficam só os próximos passos, com critérios de aceite.

## 1. Onde estamos

- **1.1 (26)** (placares ao vivo, celular, patrocinadores, cidade): `release/1.1-26` @ `d7283d1`, run `39011573945`, todos os passos verdes, ativado no grupo interno e Concluído no App Store Connect em 17/out. Ver a seção 6d.
- **No TestFlight interno antes dele:** 1.1 (25), branch `release/1.1-25` @ `9cc68fd`, run `38993534322`, todos os passos verdes (gate de iPhone e iPad, archive, upload e ativação).
- **1.1 (24)** (lógica e mercado): `release/1.1-24` @ `27bf294`, run `38965319745`, verde.
- **1.1 (23)** (polimento de textos e toques): `release/1.1-23` @ `c59ce2f`, run `38939859482`, verde.
- **Linha de entrega:** `release/1.1-21` → `22` → `23` → `24` → `25`. Nenhuma foi mesclada em `feature/entrega-a-ritmo` ainda.
- **Antes e depois:** build 23 em https://claude.ai/artifact/LFpTygSbRq9VdvxGpFxs8X; builds 24 e 25 em https://claude.ai/artifact/DpRFBWwcH4w1XHa5nu6kzi
- **Sem revisão no aparelho** até agora. Tudo vem de simulador, testes e simulações.

## 2. Diagnóstico que origina este roadmap

Dois blocos: o que foi **medido** (simulações no Linux, motor `Core`) e o que foi **lido** no código ou visto nas 81 capturas do build 23. Nada disto foi visto num aparelho.

### 2.1 Medido

Sonda 1: 3 clubes (União da Serra, Sertanejos, Serra Azul), até 10 temporadas, **sem nenhuma decisão do jogador**.
Sonda 2: 30 campeonatos da Série A (2.700 jogos) e uma amostra de preços de mercado no dia 0, clube União da Serra.

| Medida | Resultado | Referência do futebol real |
|---|---|---|
| Mandante / empate / visitante | 41% / 22% / 35% | cerca de 45% / 27% / 28% |
| Gols por jogo | 3,08 | cerca de 2,7 |
| Jogos com 8 gols ou mais | 2% (máximo 11 num jogo) | abaixo de 1% |
| Campeão por força inicial | o mais forte 11 de 30; os dois mais fortes 18 de 30 | (equilíbrio bom) |
| Zebras (favorito com diferença de força de 5+ perdeu) | 18% | (equilíbrio bom) |
| Pontos líder menos lanterna | média 26 (mín. 14, máx. 35) | (equilíbrio bom) |
| Transferências entre clubes da IA por temporada | cerca de 12 | — |

Mercado no dia 0 (caixa 7,5M, folha 3,25M, teto 4,06M):

| Atleta | Idade | Geral | Pedida | Salário pedido |
|---|---|---|---|---|
| Meia (Maré Alta) | 28 | 85 | 4,69M | 375 mil |
| Atacante (Maré Alta) | 27 | 85/92 | 3,28M | 375 mil |
| Atacante (Aurora FC) | 34 | 82 | 0,96M | 145 mil |

- Um veterano de 34 anos com geral 82 custa 0,96M e pede 145 mil. Um atacante de 27 anos com geral 85 pede 3,28M.
- No lance direto, parcelar em 4x foi aceito pela mesma taxa. A negociação por etapas cobra 3% a mais por parcela extra.
- Um lance de 70% da taxa mais um bônus de gols de 40% derrubou a pedida de 4,69M para 3,52M. O bônus (10 gols) conta como 50% do valor, mesmo para meia e zagueiro.
- Economia do time parado: o caixa foi de 10M para 35M em 5 temporadas, enquanto o teto da folha ficou entre 4,5M e 4,7M. A receita é cerca de 2 vezes a folha.
- Time parado perde o elenco aos poucos (contratos vencem, o jogo completa com os mais baratos) e chegou a 5 pontos em 18 jogos. A demissão veio entre a 1ª e a 5ª temporada.

### 2.2 Lido no código

- O jogo é de **23 dias de jogo por temporada** (18 rodadas aos domingos e 5 fases de copa às quartas). O tempo só anda de jogo em jogo.
- **Janelas:** pré-temporada nos dias 0 e 1; meio do ano nos dias 9 a 11.
- Contratos vencidos da IA são **renovados sozinhos** (`expireContracts`). Por isso o aviso "contrato curto" dos observados não leva a nada, e nenhuma estrela da IA chega livre.
- Os clubes da IA têm **16 atletas** e nenhum caixa próprio. As ofertas por seus atletas usam o orçamento inicial fixo do clube comprador.
- As parcelas pendentes são cobradas de uma vez na virada da temporada, mas na prática a lista está sempre vazia nesse momento: o parcelamento vai até 6 dias de jogo e as janelas fecham no dia 11, então tudo vence antes do dia 23. **Não é um problema real** (conferido em 16/out, ao começar o build 24).
- A vantagem de casa é pequena: +1,5 de ataque, +1 de defesa e +1 de controle (`FootballMatchEngine`).
- A Loja é só vitrine: os cinco módulos Pro não estão à venda e não bloqueiam nada.

### 2.3 Visto nas capturas

- Só 7 dos 23 apps usam o cabeçalho de destaque. Os outros 16 começam de formas diferentes.
- Gestor, Mensagens, Metas e Palpite+ abrem com uma faixa que repete o selo vermelho do ícone. No Gestor aparecem "34 mensagens não lidas".
- Mercado, Marca e Crescimento e a partida ao vivo estão densos. O painel "Imagem, marca e torcida" aparece em dois apps.
- Os botões secundários são verde-claro com texto verde (Contatos, Mercado).
- Na home do celular, o ícone da Loja aparece cortado atrás do dock.
- O Banco mostra barras por origem, mas não o saldo no tempo.
- Não há som. Há vibração em 16 pontos e 97 animações. O tema escuro só é forçado na abertura, no onboarding e na virada.

## 3. Regras de trabalho (valem para todos os builds)

- Não alterar `FactoryShared/FactoryShared.swift`: é compartilhado com outros apps da fábrica.
- Saves: campos novos usam `decodeIfPresent`; saves antigos abrem.
- Sheets precisam de alerta local (`.sheetAlert`); o `.alert` da raiz não aparece com a folha aberta.
- Linhas com `.buttonStyle(.plain)` e `Spacer()` sem fundo precisam de `.contentShape(Rectangle())`.
- Singular e plural sempre por `FootballFormat.plural(count, singular, plural?)`.
- Ordem do tick: `completeMatchDay` incrementa `matchDayIndex` antes de `tickGrowth`.
- O número de build só é consumido no upload. Falha no gate não consome.
- Cada build sai de um worktree próprio (`release/1.1-N`), com a suíte do Core rodada no Docker (`swift:6.1-noble`) antes do GitHub Actions.
- O que mexe na partida ou na economia muda os resultados para a mesma semente. Testes que fixam placar precisam ser revistos junto.

## 4. Build 24 — lógica e mercado

**Estado: enviado e ativado em 16/out.** Entregues: CMP-01, CMP-02, CMP-03, PRT-01, QLD-01, ELE-01, TUT-01. **Não entrou:** SEM-01 (resumo da semana), que passa para a seção 6b. CMP-04 foi retirado: a lista de parcelas nunca chega vazia à virada.

Objetivo: tornar as compras coerentes e medir o equilíbrio da partida. **Sem mexer na economia.** Tamanho: médio. Validação: Core no Docker, `validate.yml`, depois TestFlight.

| ID | Item | Critério de aceite | Onde | Tam. |
|---|---|---|---|---|
| CMP-01 | **Unificar as compras.** O lance direto passa a seguir as mesmas regras da negociação por etapas (ou é absorvido por ela). | Parcelar em N vezes custa o mesmo nos dois caminhos (+3% por parcela extra). Um teste cobre os dois caminhos com a mesma entrada. | `FootballCareer+Market.swift` (`evaluateBid`, `submitBid`), `FootballTransferTalks.swift`, `FootballMarketViews.swift` | M |
| CMP-02 | **Bônus de gols só para quem marca.** O valor do bônus no preço depende da chance real de o atleta atingir a meta pela posição e pelo histórico. | Um bônus de 10 gols para zagueiro ou meia não reduz a pedida. Para atacante, continua valendo metade. | `evaluateBid`, `FootballTransferTalks.swift` | P |
| CMP-03 | **Preço de veterano.** Remover o desconto duplicado de idade (valor de mercado já desconta idade e `askingPrice` desconta de novo para 33+). | Alvo inicial (a calibrar com a sonda): veterano de 33+ não custa menos de 50% de um atleta de 27 a 29 anos com o mesmo geral. Registrar a medição antes e depois. | `askingPrice`, `FootballAttributes.swift` (`marketValue`) | P |
| PRT-01 | **Ajuste da partida.** Mais vantagem de casa, mais empates, menos gols. | Alvos: mandante 44–48%, empate 25–28%, visitante 27–31%, gols 2,6–2,9, jogos com 8+ gols abaixo de 1%. **Resultado medido no build 24 (28 campeonatos): 46% / 24% / 30%, 2,65 gols, 8+ gols em 1,1%.** Mando, visitante e gols entraram na faixa; empates e 8+ gols ficaram quase lá, e o empate quase não reage à taxa de gols (fica entre 22% e 25%): mexer nele pede outro ajuste (por exemplo, o ritmo do fim de jogo). Equilíbrio entre os clubes preservado (o mais forte campeão em 8 a 14 de 30; zebras de 14 a 22%). | `FootballMatchEngine.swift` (bônus de mando e `expectedGoals`), `FootballLiveEngine.swift` | M |
| QLD-01 | **Testes de equilíbrio permanentes.** A sonda vira teste, com faixas aceitas. | Roda no Core em tempo razoável (poucas sementes no CI, mais na rodada manual). Falha se mando, empate, gols ou equilíbrio saírem da faixa. | `Tests/FootballLeagueBalanceTests.swift` (novo) | P |
| ELE-01 | **Rodízio com dica.** A escolha de titulares avisa quem está cansado e sugere o reserva. | O atleta com condição baixa aparece marcado; um toque coloca o melhor reserva da posição. Sem a sugestão, tudo continua como hoje. | `FootballStarterPickerSheet.swift`, `FootballStartingXI.swift` | P |
| TUT-01 | **Rever o tutorial.** Botão em Ajustes para reabrir as boas-vindas e o roteiro da primeira carreira. | O botão reabre o fluxo sem apagar a carreira. | `FootballSettingsView`, `FootballOnboarding.swift`, `FootballCareerFirstRunGuide.swift` | P |
| SEM-01 | **Resumo da semana** na abertura do celular: resultado, lesões, prazos e a próxima decisão numa tela só. (Opcional neste build.) | Uma tela, sem repetir o que o Gestor já mostra. | `FootballPhoneState.swift`, `FootballDashboardView.swift` | M |

**Fora do build 24, de propósito:** teto da folha, contratos da IA e caixa da IA. Mudam o equilíbrio do jogo e pedem conversa antes (seção 6).

## 5. Build 25 — telas

**Estado: enviado e ativado em 17/out.** Entregues: TEL-01 (10 apps, mais Ajustes), TEL-02, TEL-04, TEL-05, TEL-06, TEL-07, TEL-08 (o gráfico já existia; subiu na tela), TEL-10. TEL-03 e TEL-09 ficaram **parciais**: o verde de destaque ficou adaptativo, mas os botões secundários continuam apagados no tema escuro (agora TEL-11). **Não entrou:** SOM-01, por falta de arquivos de áudio. Clube, Gestor e Mensagens mantêm a abertura própria.

Objetivo: consistência entre os apps e uma sensação mais premium. Tamanho: grande, por tocar muitos arquivos. Cada item entra com captura antes e depois. A separação do build 24 é recomendada: se algo quebrar, fica claro qual das duas mudanças causou.

Peças padrão, aplicadas nos 16 apps que ainda não as usam:
1. **Cabeçalho único:** linha de contexto (por exemplo "Temporada 2 · rodada 7"), título e frase de apoio.
2. **Faixa de resumo única:** de dois a três números, no lugar das faixas de alerta repetidas. O alerta fica só onde exige ação.
3. **Botão secundário com contraste:** verde-escuro sobre claro, ou contorno.

| ID | Item | Critério de aceite | Tam. |
|---|---|---|---|
| TEL-01 | Cabeçalho único nos 16 apps | Todos os apps abrem com a mesma estrutura. As capturas antes e depois mostram a diferença. | G |
| TEL-02 | Faixa de resumo única; remover as faixas de alerta repetidas (Gestor, Mensagens, Metas, Palpite+) | O "34 mensagens não lidas" deixa de aparecer como item de atenção. O alerta continua em quem exige ação (coletiva, decisão). | M |
| TEL-03 | Botão secundário com contraste | Razão de contraste medida e anotada; mínimo 4,5:1 para texto. | P |
| TEL-04 | Mercado: negociação em linhas (entrada, parcelas, salário e total em destaque) | Nenhuma linha única com mais de três valores. | M |
| TEL-05 | Marca e Crescimento: tirar o painel duplicado, recolher o registro de eventos | O painel "Imagem, marca e torcida" aparece em um só lugar. O registro abre sob demanda. | M |
| TEL-06 | Partida: reagrupar os controles em duas fileiras, com o essencial à vista | Continuar, velocidade e Trocar sempre visíveis, sem truncar, no iPhone pequeno e no iPad. Os testes de interface da partida passam. | M |
| TEL-07 | Home do celular: conferir a grade (ícone da Loja cortado) | Todos os 21 apps alcançáveis; se a grade rola, há indicação disso. | P |
| TEL-08 | Banco: gráfico do saldo no tempo, usando a projeção de caixa que já existe | O gráfico mostra o realizado e o projetado, com o ponto mais baixo marcado. | M |
| TEL-09 | Passada de tema escuro | Capturas dos apps no escuro; lista do que quebra e correção do que for crítico. | M |
| SOM-01 | Sons e vibração em gol, apito, assinatura de contrato e virada | Opção de desligar em Ajustes. **Depende de arquivos de áudio que ainda não existem no projeto.** | M |
| TEL-10 | Artefato antes e depois do build 25 (como o do 23) | Publicado ao fim do build. | P |

## 6. Equilíbrio e mundo vivo (sem build definido)

Cada item mexe na economia ou no comportamento da IA. **Precisa de decisão do usuário antes** e vem com medição pela sonda (QLD-01).

| ID | Item | Ideia | Risco |
|---|---|---|---|
| ECO-01 | **Teto da folha ligado à receita.** Hoje o caixa sobra (10M para 35M) e o teto quase não cresce. | O teto passa a acompanhar uma fração da receita, e o pedido à diretoria pesa mais. Meta de desenho: folha entre 55% e 65% da receita (hoje, cerca de 50%). | Alto: muda o ritmo de todo o jogo. |
| MND-01 | **Contratos da IA vencendo de verdade.** Uma parte vira agente livre, com **pré-contrato** na metade do ano. | Dá sentido ao aviso de contrato curto e abre a oportunidade de contratar de graça. | Médio |
| MND-02 | **Elenco da IA com cerca de 20.** Hoje têm 16, contra 30 do jogador. | O rodízio passa a ter peso dos dois lados. | Médio |
| MND-03 | **Caixa e transferências da IA.** Cada clube com orçamento próprio; mais movimentação por janela. | As ofertas pelos seus atletas dependem do caixa real do comprador. | Médio |
| CLA-01 | **Cláusulas de contrato.** Multa de rescisão e percentual numa venda futura. | Dá peso às negociações e à venda. | Médio |
| CMP-05 | **Propostas de compra com contraproposta.** Confirmar se hoje só dá para aceitar ou recusar as ofertas por seus atletas. | Abrir a negociação também no lado da venda. | Baixo |
| MET-01 | **Metas secundárias da diretoria.** Revelar jovens, ir longe na copa, fechar no azul. | Apoia a regulação de salário e gasto que já existe. | Baixo |
| TMP-01 | **Semana com conteúdo.** Janelas medidas em datas, com contagem regressiva, e eventos entre os jogos. | O tempo entre rodadas deixa de ser vazio. | Médio |
| LOJ-01 | **Loja.** Ligar a compra de verdade (StoreKit) com o Market Pro entregando algo, ou tirar a Loja da tela inicial até lá. | Hoje os módulos Pro não bloqueiam nada. | Médio (depende de contas e de produtos no App Store Connect) |

## 6b. Ideias adicionadas em 17/out

Três pacotes, em ordem. Cada item é uma proposta, ainda não medida nem testada. Os que mexem no equilíbrio do jogo estão na seção 6 e continuam esperando decisão.

### Build 26 — momentos de pico e clareza (telas e textos, sem mexer na economia)

Achados que originam o pacote, vistos nas capturas do build 25: a virada de temporada (escura e dourada) é a tela mais premium, e fim de jogo, título e coletiva usam o cartão branco comum; o resumo pós-jogo repete a mesma causa em quatro linhas; a central de notificações lista "Zebra na copa" três vezes seguidas; a coletiva não mostra o que cada tom custa.

| ID | Item | Critério de aceite | Tam. |
|---|---|---|---|
| MOM-01 | **Fim de jogo na linguagem da virada.** Fundo escuro, placar grande, uma frase de manchete e vibração; vale também para título, acesso e rebaixamento. | Vitória, empate e derrota têm tratamentos distintos. Respeita "Reduzir movimento". | M |
| CLR-01 | **Resumo do jogo em um cartão.** Três números, uma causa e a próxima ação; o detalhe fica recolhido. | A causa de um resultado aparece uma vez, não uma por linha. | M |
| CLR-02 | **Notificações agrupadas** por tipo e dia ("3 zebras na copa"). | Nenhum título repetido em sequência na central. | P |
| CLR-04 | **Coletiva com prévia do efeito** (torcida, vestiário, diretoria) antes de escolher o tom. | Cada opção mostra o que costuma mudar, sem esconder o risco. | M |
| TEL-11 | **Botões do tema escuro.** Secundários legíveis e principais com texto branco, tratados separadamente. | Razão de contraste do texto de 4,5:1 ou mais nos dois tipos, medida nas capturas escuras. | M |
| CLR-03 | **Tela "Hoje" única** (antes PIL-04 e SEM-01). **Depende de decisão sua.** | Uma tela com resultado, lesões, prazos e a próxima decisão. | M |

### Build 27 — experiência de app iOS e som

Exige configuração no projeto Xcode e na conta Apple; por isso fica separado.

| ID | Item | Critério de aceite | Tam. |
|---|---|---|---|
| IOS-01 | **Live Activity** com o placar ao vivo na tela bloqueada. | Atualiza a cada gol e some no apito final. | G |
| IOS-02 | **Widget** da tela inicial com o próximo jogo. | Mostra adversário, data e horário do calendário do jogo. | M |
| IOS-03 | **Notificação local** "jogo hoje". | Pode ser desligada em Ajustes. | P |
| SOM-01 | **Sons de apito, torcida e gol.** Há uma ferramenta de áudio conectada que gera efeitos, mas gasta créditos: **estimar o custo e pedir aprovação antes de gerar qualquer arquivo.** | Opção de desligar em Ajustes; sons só depois de um toque do jogador. | M |
| MOM-02 | **Apresentação do reforço.** Cartão do atleta ao assinar, no lugar do alerta. | Aparece uma vez por contratação. | P |
| MOM-03 | **Capa do dia seguinte:** manchete gerada do resultado e das reações. | Texto coerente com o placar e as repercussões do jogo. | M |
| MOM-04 | **Cartão de temporada compartilhável** como imagem. | Gera a imagem sem sair do app. | M |

### Build 28 — profundidade e análise

| ID | Item | Critério de aceite | Tam. |
|---|---|---|---|
| PRF-01 | **Tática visual:** zonas de pressão e linha defensiva desenhadas no campo. | Os controles de instrução têm um reflexo visual. | G |
| PRF-02 | **Ficha do atleta com radar de atributos** e comparação lado a lado. | Compara dois atletas na mesma escala. | M |
| PRF-03 | ~~Mapa de finalizações~~ **Já existe** (mapa de finalizações e mapa de calor na partida, `FootballShotMap` e `FootballHeatMap`). Fica só a ideia de levar o mesmo mapa ao resumo pós-jogo. | O resumo pós-jogo mostra o mapa do jogo. | P |
| RPL-01 | **Replay do gol** no campo 2D, a partir dos eventos da partida. | Repete os últimos lances antes do gol. | G |
| AUX-01 | **Auxiliar técnico** com recomendações e personalidade (escalação, rodízio, lesões). | Cada recomendação explica o motivo em uma frase. | M |
| EVO-01 | **Gráfico de evolução de atributos** por temporada. | Mostra ganho e queda por atributo. | P |

### Qualidade (corre em paralelo aos três builds)

| ID | Item | Critério de aceite | Tam. |
|---|---|---|---|
| QLD-02 | **Teste visual automático:** compara as capturas entre builds e aponta o que mudou sem querer. | Gera uma lista de telas com diferença maior que um limite. | M |
| QLD-03 | **Botão "Relatar problema"** no app, com captura de tela, para o TestFlight. | Envia a captura e o estado resumido da carreira. | M |
| QLD-04 | **Passada de acessibilidade:** texto grande e leitor de tela. | Nenhum texto cortado no maior tamanho de fonte. | M |
| PER-01 | **Métricas de desempenho no CI:** tempo de abertura, tamanho do save e quadros na partida ao vivo. | Falha se passar de um limite combinado. | M |

### Banco de ideias (segunda rodada)

Ainda sem critérios; entram em build quando houver decisão. A coluna de viabilidade diz o que já existe no código.

| Tema | Ideia | O que já existe |
|---|---|---|
| Mundo | **Rivalidades com história:** placar histórico e rivais de cada clube. | O motor já registra o confronto direto. |
| Mundo | **Ídolos e capitão** com vínculo com o clube e a torcida. | Capitão existe na Rodada Mágica. |
| Mundo | **Estádio que evolui** na imagem conforme as obras. | Obras e imagem do estádio existem. |
| Carreira | **Convite para a seleção** como evolução da carreira do treinador. | Ofertas de clube e convocações de atletas existem. |
| Carreira | **Filosofia do treinador:** identidade tática que evolui e atrai atletas e ofertas. | Estilos e instruções existem. |
| Carreira | **Plano de 3 temporadas** com metas e pontos de checagem. | Reuniões e metas da diretoria existem. |
| Elenco | **Entrosamento** entre duplas e linhas. | — |
| Elenco | **Vestiário:** grupos, conflitos e liderança. | Moral e promessas existem. |
| Mercado | **Janela em datas** com contagem regressiva e último dia dramático (ofertas relâmpago). | Último dia da janela já gera propostas. |
| Mercado | **Olheiros por região** em mapa. | Missões de olheiro por região existem. |
| Competições | **Torneio continental** para os melhores da Série A. | — |
| Competições | **Modos de carreira:** Resgate (clube em crise) e Fundação (Série B, orçamento mínimo). | Cenários de desafio existem. |
| Personalização | **Criar o próprio clube:** nome, cores e escudo. | Escudos e cores por clube existem. |
| Plataforma | **Save no iCloud** com sincronia entre iPhone e iPad. | Três espaços de save locais existem. |
| Plataforma | **Idiomas** (inglês e espanhol) e modo para daltonismo. | — |

## 6c. Mundo visual, jogo ao vivo, patrocínio e sistema do celular (17/out, terceira rodada)

Esta seção nasceu de uma investigação do código e dos assets, feita antes de propor. Primeiro o que já existe, depois os pacotes.

### O que já existe e o que falta

| Tema | Já existe | O que falta |
|---|---|---|
| **Estádio** | Quatro ilustrações por capacidade (pequeno, médio, grande, grande à noite) no app Clube. Sete outras ilustrações estão nos assets sem nenhum uso no código. Cenas de partida de dia, à noite e de TV. | Todos os clubes com a mesma ilustração: Manaus e Porto Alegre têm o mesmo estádio. Não muda com as obras de forma visível. |
| **Cidade** | Só o nome da cidade, em texto. Na biblioteca de arte 3D há cidade pequena, média e grande, de dia e de noite, e o estádio dentro da cidade. | Nenhuma cidade na tela. A cidade não influencia nada no jogo (torcida, patrocínio, clima, viagem). |
| **Campo** | Campo desenhado em tempo real, com torcida (densidade pelo humor), painéis de LED, refletores, bancos de reservas e iluminação. Mapa de finalizações e de calor. Na arte 3D há três variações de gramado. | Gramado igual em todo jogo: sem desgaste ao longo da temporada, sem chuva ou lama, sem relação com o nível do centro de treinamento. Os painéis de LED são faixas coloridas sem nome. |
| **Personagens** | Lendas com ilustração própria. O resto são ícones e iniciais (contatos com símbolo; sala de perfis com a letra do nome). Na arte 3D há jogadores, goleiro, árbitro, treinador e elenco em onze poses, com pele, cabelo e uniforme variados. | Nenhum atleta, treinador ou contato tem rosto. |
| **Camisas** | Cinco padrões (liso, listras verticais, faixas, metades, faixa transversal) escolhidos por `id` do clube; camisa reserva automática quando as cores se confundem; goleiro com cor própria. | Os padrões se repetem entre clubes. Sem terceiro uniforme. Escudo é um símbolo do sistema com três letras. Sem patrocinador nem número visível na camisa. |
| **Jogos de outras partidas** | O painel "Outros jogos da rodada" mostra o placar de cada jogo **pelo minuto atual** da partida. | Fica no meio da tela. Nenhum aviso quando sai gol em outro jogo, nenhum destaque dos jogos que mexem no seu título ou rebaixamento, nenhuma tabela ao vivo, e os gols não têm autor. |
| **Patrocínio** | Contrato principal, quatro espaços (manga, placas do estádio, uniforme de treino, parceiro digital), naming rights e propostas que renovam. | Nada disso aparece no campo, na camisa ou no estádio. O patrocinador não reage ao desempenho nem à exposição. |
| **Economia e marketing** | Loja do clube com coleções, cota de TV, campanhas de marketing com previsão, programas sociais, gerente comercial delegável, preço de ingresso e 31 acontecimentos de mundo. | O mundo econômico não muda sozinho: sem ciclos de crise e de alta, sem concorrência de rivais por patrocinadores, sem venda de camisa por astro, sem preço de ingresso que acompanhe a importância do jogo. |
| **Celular** | Tela de bloqueio com widgets e "toque para abrir", central de notificações, busca, widgets pequenos na home, papel de parede que muda com o clube e com o momento do dia, preferências de aviso e de ritmo, reduzir movimento, vibração em 16 pontos. | O celular só trava sozinho na virada do dia, sem botão de bloquear. Papel de parede sem escolha. Ícones sem edição, sem mover e sem pastas. Vibração sem ajuste, sem som, sem tema escolhido pelo jogador. |

**Arte 3D:** os scripts (Blender 4.2.1) e um catálogo estão em `Resources/Blender/COMPONENTE_TESTE_INOVACAO`, na branch de entrega. As imagens renderizadas (54 MB) ficam só no checkout principal e são ignoradas pelo git. **Esta máquina não tem Blender**: para gerar mais arte é preciso rodar o Blender no seu computador ou instalá-lo num runner. Isso pesa no tamanho dos pacotes abaixo.

### Build 29 — estádio, cidade, campo, personagens e camisas

| ID | Item | Critério de aceite | Tam. |
|---|---|---|---|
| EST-01 | **Estádio de cada clube.** Uma ilustração por clube, nas cores dele, usando as variações já nos assets, e que muda com o nível das obras. | Dois clubes de mesmo porte não têm a mesma imagem. A imagem muda ao concluir uma obra. | G |
| CID-01 | **Cidade do clube.** Horizonte por porte (pequena, média, grande; dia e noite) no app Clube e um cartão da cidade. | A cidade aparece no Clube. Cada cidade tem um porte definido por dados. | M |
| CID-02 | **A cidade pesa no jogo** (decisão sua): porte da cidade alimenta torcida, bilheteria e patrocínio; clima por região e viagem do visitante afetam a condição. | Medição antes e depois, como no build 24. | G |
| CAM-01 | **Gramado que vive:** variação pelo nível do centro de treinamento, desgaste ao longo da temporada, chuva e lama em alguns jogos. | O campo da partida muda entre início e fim de temporada. Chuva muda a imagem e tem efeito pequeno no jogo, medido. | M |
| CAM-02 | **Atmosfera de clássico:** mosaico da torcida e mais barulho visual em jogos de rivalidade. | Só aparece em clássico, e respeita "Reduzir movimento". | M |
| PRS-01 | **Retratos de atletas** gerados a partir dos personagens 3D: pele, cabelo, idade e camisa do clube. | Cada atleta tem o mesmo retrato sempre. Aparece na ficha, no elenco e na escolha de titulares. Depende de gerar os retratos no Blender. | G |
| PRS-02 | **Treinador e contatos com rosto** (empresário, jornalista, família). | Substitui as iniciais e os símbolos. | M |
| PRS-03 | **Elenco em pose:** comemoração, apresentação de reforço e capa de jornal. | Reaproveita MOM-02 e MOM-03. | M |
| UNI-01 | **Uniforme próprio de cada clube,** em vez de repetir cinco padrões por `id`. | Os 20 clubes têm desenhos distintos nas camisas da partida e nos retratos. | M |
| UNI-02 | **Terceiro uniforme e lançamento de coleção** ligado às vendas da loja. | Lançar uma camisa gera pico de vendas e aparece nos jogos. | M |
| UNI-03 | **Escudo próprio por clube,** no lugar do símbolo e das três letras. | Os 20 escudos distintos, nos mesmos tamanhos de hoje. | M |
| UNI-04 | **Número e nome na camisa** e patrocinador no peito e na manga (ligado a PAT-01). | Visível na partida e nos retratos. | M |

### Build 30 — jogo ao vivo, patrocínio e economia viva

| ID | Item | Critério de aceite | Tam. |
|---|---|---|---|
| AOV-01 | **Faixa de placares ao vivo** no topo da partida: um gol em outro jogo aparece como aviso curto ("GOL · Maré Alta 1–0 Estrela"). | O aviso aparece no minuto do gol e some sozinho. Respeita "Reduzir movimento". | M |
| AOV-02 | **Relevância:** destaque só para os jogos que mexem no seu título, acesso ou rebaixamento, e uma **tabela ao vivo** mostrando sua posição provisória. | A posição muda em tempo real e é explicada em uma linha. | M |
| AOV-03 | **Autor dos gols** nos outros jogos (o resultado final já tem os autores; falta emparelhar com os minutos). | O aviso mostra o nome. | P |
| AOV-04 | **Rodada completa no intervalo e no apito final.** | Lista todos os placares, com os jogos que mexem na tabela em cima. | P |
| PAT-01 | **Patrocinadores visíveis:** nome nas placas de LED (espaço "placas do estádio"), na camisa e na manga, na tela do estádio e no placar. Marcas fictícias. | Cada contrato ativo aparece onde foi vendido; sem contrato, o espaço fica neutro. | M |
| PAT-02 | **Exposição e satisfação do patrocinador:** jogos de TV, público e resultado alimentam o pagamento variável e a renovação. | O patrocinador reage a uma sequência ruim ou boa e isso aparece em mensagem. | G |
| PAT-03 | **Ativações pedidas pelo patrocinador** (ação com a torcida, visita ao CT), com recompensa e custo. | Entra como acontecimento, com prazo. | M |
| ECV-01 | **Mercado de patrocínio vivo:** valores e propostas variam com reputação, desempenho e a concorrência de rivais. | Os valores de uma proposta mudam entre duas temporadas sem o jogador fazer nada. | G |
| ECV-02 | **Venda de camisas por astro:** o ídolo do elenco puxa as vendas da loja. | A venda sobe e cai com a forma e a saída do astro. | M |
| ECV-03 | **Preço de ingresso dinâmico** pela importância do jogo e pela demanda. | Clássico e jogo decisivo aceitam preço maior sem derrubar o público. | M |
| ECV-04 | **Marketing com resposta visível:** efeito das campanhas em gráficos de torcida e sócios, e concorrência de campanhas de rivais. | Cada campanha mostra o antes e o depois. | M |
| ECV-05 | **Ciclos da economia:** fases de alta e de crise que mudam patrocínio, TV e bilheteria. | Aparecem como acontecimento de mundo e podem ser lidas na tela de Finanças. **Mexe no equilíbrio: decisão sua.** | G |

### Build 31 — sistema do celular

Todos os ajustes ficam em `PhonePreferences` com `decodeIfPresent`, para os saves antigos abrirem.

| ID | Item | Critério de aceite | Tam. |
|---|---|---|---|
| OS-01 | **Bloquear e desbloquear à mão:** botão lateral simulado, bloqueio automático por tempo e, opcional, senha. | Travar e destravar funciona a qualquer hora, sem mudar o dia. | M |
| OS-02 | **Papel de parede à escolha:** cores do clube, estádio, cidade, momento do dia automático, gradiente e imagens do jogo; tela inicial e de bloqueio separadas. | A escolha é lembrada no save. | M |
| OS-03 | **Editar a tela inicial:** modo de edição, mover ícones, criar pastas e grupos, várias páginas, dock editável e escolha de widgets. | A organização é guardada no save e sobrevive à virada de temporada. | G |
| OS-04 | **Ajustes do sistema:** vibração (liga, desliga e intensidade), sons, tema (claro, escuro, automático), tamanho do texto, restaurar padrões. | Cada ajuste vale na hora. A vibração fixa em 16 pontos passa a respeitá-lo. | M |
| OS-05 | **Central de controle** (puxar do canto): Foco, vibração, som, tema e bloquear. | Abre de qualquer tela, sem cobrir uma decisão pendente. | M |
| OS-06 | **Modos de Foco** (Jogo, Descanso, Reunião) ligados à prioridade de avisos e às pausas do avanço. | Cada modo muda o que chega, e urgentes nunca são silenciados. | M |
| OS-07 | **Apps de sistema novos:** Notas (anotações do treinador), Mapas (cidades dos clubes e viagens), Tempo (clima da rodada), Relógio (contagem para janela e jogo) e Fotos (momentos do jogo). | Cada um aproveita dados que o jogo já tem. Mapas e Tempo dependem de CID-02. | G |
| OS-08 | **Seletor de apps** (apps recentes). | Alterna entre dois apps abertos sem passar pela tela inicial. | M |

### Ordem e riscos desta seção

- **Primeiro, uma decisão de arte:** quem gera as imagens do Blender (no seu computador ou num runner) e qual o limite de tamanho do app. Sem isso, EST-01, CID-01, PRS-01 e UNI-03 não andam.
- O build 29 é o mais pesado em arte; o 30, em lógica e economia; o 31, em interface do celular. ECV-05 e CID-02 mexem no equilíbrio do jogo e seguem a regra da seção 6: medição antes e depois.
- AOV-01 a AOV-04 são pequenos e não dependem de arte. Podem entrar já no build 26 ou 27 se você preferir ver o resultado ao vivo antes.
- Tudo que escolhe, guarda ou edita do celular vai em campos opcionais do save.

## 6d. Build 26 — o que entrou, o que ficou de fora e por quê (17/out)

**Estado: enviado e ativado em 17/out.** Nenhuma revisão no aparelho ainda.

**Decisão de escopo:** juntar num só build tudo o que é seguro, sem mexer na economia e sem depender de arte nova, áudio ou extensões do Xcode. Cada item de lógica tem teste no Core (Linux); as telas são conferidas pelo GitHub Actions e por capturas.

### Entrou

| Pedido | Itens | Como ficou |
|---|---|---|
| Resultados de outros jogos ao vivo | AOV-01, AOV-02, AOV-03, AOV-04 | Aviso curto de gol em outro jogo durante a partida (só dos jogos de clubes até duas posições do seu na tabela; em saltos de relógio mostra o último). Painel "Outros jogos da rodada" com estrela nos relevantes e **posição provisória** na tabela ("subiu 2 desde o início da rodada"). Autor do gol no aviso. No apito final o painel vira "Rodada completa". Lógica em `Core/FootballLiveRound.swift`. |
| Fim de jogo | MOM-01 (parcial), MOM-03 (manchete) | Manchete de uma linha no cartão do resultado, com gradiente que escurece como na virada de temporada. **Não entrou** a tela cheia dedicada nem a capa de jornal separada. |
| Resumo e fluxo | CLR-01, CLR-02, CLR-04 | Resumo da rodada em cartão: manchete, fichas curtas com a variação, causa dita uma vez, próxima atenção e "Ver detalhes". Notificações com o mesmo título viram uma ("3 mensagens não lidas"). Coletiva mostra o efeito base de cada tom (torcida, diretoria, moral, rival); um teste confere os números contra o motor. |
| Patrocinadores | PAT-01 (parcial) | As placas de LED do campo usam a cor de cada marca contratada, e uma faixa sob o campo lista camisa, espaços vendidos e nome do estádio. **Não entrou** nome escrito nas placas nem logo na camisa. |
| Cidade | CID-01 (parcial) | Painel "Cidade" no Clube, com o horizonte por porte (pequena, média, grande; grande à noite). É só apresentação: não muda nenhuma regra. |
| Sistema do celular | OS-01, OS-02, OS-03 (parcial), OS-04 | Botão de bloquear a tela. Cinco papéis de parede à escolha. Tema claro, escuro ou automático. Vibração com liga e desliga (as 17 vibrações do app respeitam). Trocar os apps de lugar (segurar um ícone, tocar em um e depois em outro), com restaurar. Restaurar padrões do celular. **Não entraram** pastas, várias páginas, widgets escolhíveis nem dock editável. |
| Qualidade | QLD-03, TEL-11 | "Relatar um problema" em Ajustes compartilha um resumo curto (versão, ponto da carreira, últimas ações). Botões secundários com contraste nos dois temas (texto mais claro no escuro). |

### Ficou de fora, e a razão

| Item | Razão |
|---|---|
| EST-01, PRS-01 a PRS-03, UNI-01, UNI-03 | Dependem de gerar arte nova no Blender, que não está instalado nesta máquina. Aguardam a decisão da seção 10. |
| SOM-01 | Não há arquivos de áudio, e gerar efeitos gasta créditos: precisa da sua aprovação do custo. |
| IOS-01 a IOS-03 | Live Activity e widget exigem alvos novos no projeto e capacidades na conta Apple. |
| ECO-01, ECV-01 a ECV-05, PAT-02, PAT-03, CID-02 | Mexem no equilíbrio da economia e do jogo. Seguem a regra de medir antes e depois, e ficam para builds próprios. |
| CAM-01, CAM-02 | Clima e atmosfera no campo pedem mais desenho em Canvas do que dá para conferir sem aparelho. |
| CLR-03, SEM-01 | A decisão da tela "Hoje" continua pendente. |
| OS-05 a OS-08 | Central de controle, Foco, apps de sistema novos e seletor de apps: pacote próprio do celular, depois deste. |

## 6e. Build 27 — o que entrou, o que ficou de fora e por quê (19/out)

**Entrou (em `release/1.1-27`):**
- **Celular:** pastas na tela inicial (criar, mover, renomear, desfazer), central de controle com Foco (Dia de jogo, Descanso, Negócios), vibração, sons e tema; apps novos **Notas** (anotações do treinador, até 50 de 280 caracteres) e **Relógio** (calendário do jogo e contagens).
- **Partida:** clima determinístico por região e jogo (chuva escurece o campo; chip de clima), nomes das marcas nas placas, sons ligados aos lances (infra pronta, sem arquivos de áudio).
- **Visual:** retratos de atletas e do treinador (Blender, camisa tingida com as cores do clube), escudos com 4 formas e 5 desenhos (20 combinações), 20 estádios por clube e cidade por porte.
- **Testes:** 11 testes novos no Core (foco, pastas, notas, clima, relógio, retratos, escudos).

**Limites honestos:** a diferença entre estádios do mesmo porte é sutil (cores de arquibancada e cobertura); nada foi revisado em aparelho físico; os sons só tocam quando houver arquivos `sfx-*` no app, e gerar áudio custa créditos (≈R$ 0,26 por efeito) e depende de aprovação.

**Fica para os próximos builds:** economia viva com medição (ECO/ECV, PAT-02/03, CID-02), Live Activity e widget (exigem alvos Xcode e conta Apple), uniformes próprios, mais arte (treinador e contatos).

## 6f. Build 28 — campo vivo e correções de mercado (19/out)

**Causa dos erros de contratação e de promoção da base:** o teto salarial da diretoria caía 3% a cada temporada sem a meta cumprida, enquanto a folha só crescia (renovações, jovens da base). Em uma de cada três carreiras testadas o teto terminava abaixo da folha, e aí **toda** contratação e **toda** promoção falhavam, com botão apagado e sem explicação. Medido em 72 carreiras simuladas antes da correção.

**Corrigido:**
- Teto com folga mínima de 12% sobre a folha a cada virada de temporada; saves já travados voltam a ter folga ao carregar.
- Promoção da base diz o motivo (elenco cheio, ou quanto falta de folga); o botão não fica mais mudo.
- Negociação por etapas avisa antes de começar se o salário mínimo do atleta não cabe no teto (antes a pessoa negociava taxa e salário e só na assinatura descobria). Negociações paradas por 6 dias de jogo esfriam e liberam a vaga (eram 3 vagas presas para sempre).
- Janelas de transferência mais largas: pré-temporada nos dias 0 a 2 e meio de temporada nos dias 8 a 12; a mensagem de janela fechada diz quando abre.

**Campo ao vivo:**
- Bola fora de verdade: lateral (cobrador com os braços para cima, bola sobre a cabeça), tiro de meta (goleiro) e escanteio, com a regra de quem tocou por último.
- Todo escanteio da estatística agora vira um lance na súmula (tipo novo `corner`) e no campo: cobrador na bandeirinha, atacantes e defensores na área, cruzamento disputado. Chute defendido que a súmula chama de escanteio termina na linha de fundo, sem contar duas vezes.
- Falta e cartão: barreira a 9,15 m quando perto da área.
- Física: arranque e freada limitados (4,6 e 7,5 m/s²), velocidade máxima por atleta, passe com desaceleração no gramado, erro de passe maior com a distância e com marcação, passe cortado, desarme só com rival colado, condução da bola nos pés, marcação por zona.
- Relógio pelo campo: cada minuto vale 2,5 s de jogo; 2× e 4× aceleram o campo e os minutos na mesma proporção (antes o relógio andava 6× e o campo 2,2×). Lances da súmula seguram o relógio.
- O motor do campo foi para o Core (testável no Linux), com 12 testes novos.

**Limites honestos:** sem revisão em aparelho; lateral e tiro de meta comuns acontecem de 6 a 18 vezes por tempo de campo (calibrado por simulação, não por jogos reais); impedimento e pênalti em jogo corrido seguem só na narração.

## 7. Ordem sugerida e dependências

1. **Rodada no aparelho** com o 1.1 (25): iniciar carreira, comprar um jogador, simular uma rodada, virar a temporada. Não gasta build e reordena este plano.
2. **Builds 24 e 25:** entregues.
3. **Build 26:** em andamento, com o pacote da seção 6d (inclui os avisos ao vivo, o celular, os patrocinadores e a cidade, que antes estavam nos builds 29 a 31).
4. **Build 27:** IOS-01 a IOS-03, SOM-01 (só depois da estimativa de custo aprovada), MOM-02 a MOM-04.
5. **Build 28:** PRF-01, PRF-02, PRF-03 (só levar o mapa ao resumo), RPL-01, AUX-01, EVO-01.
6. **Builds 29 a 31 (seção 6c):** mundo visual, ao vivo e patrocínio, sistema do celular. AOV-01 a AOV-04 podem antecipar.
7. **Qualidade:** QLD-02 antes do build 26, para medir o efeito das mudanças de tela. QLD-03 antes de a revisão no aparelho ficar frequente.
8. **Equilíbrio e mundo vivo (seção 6):** um item de cada vez, com decisão e medição antes e depois.
9. **Mesclagem:** decidir quando `release/1.1-22` a `release/1.1-25` entram em `feature/entrega-a-ritmo`.

## 8. Como cada build é entregue

1. Worktree novo a partir do build anterior (`release/1.1-N`).
2. Mudanças pequenas e testadas; a suíte do Core roda no Docker (cerca de 9 a 18 minutos).
3. `validate.yml` (`-f app=manager-futebol`) para compilar o SwiftUI e rodar os testes de interface.
4. Capturas (`screenshots.yml`) quando há mudança de tela, para comparar antes e depois.
5. `football-testflight.yml` (`-f version=1.1 -f build=N`): o gate roda a navegação da partida e os testes de iPhone e iPad antes de archive, upload e ativação.
6. Artefato antes e depois; memória do projeto atualizada com o run e o commit.

## 9. Limites do que se sabe

- A rodada no aparelho **nunca foi feita**. Tudo vem de simulador, testes e simulações.
- A sonda 1 jogou sem decisões: mede a economia e o declínio, mas não o jogo bem jogado. Com poucos clubes e sementes, os números são indicativos.
- O tema escuro dos apps não foi capturado.
- Não foi confirmado qual era o problema do onboarding e da virada de temporada. O que foi feito: o cartão de primeira carreira, que ficava preso, e a renovação das ações da base.

## 10. Perguntas em aberto

1. Quando mesclar `release/1.1-22` a `release/1.1-25` em `feature/entrega-a-ritmo`?
2. O que exatamente quebrava no onboarding e na virada de temporada? (Ainda não confirmado.)
3. Sons (SOM-01): posso pedir a estimativa de custo da ferramenta de áudio conectada? Nenhum arquivo é gerado sem a sua aprovação.
4. Live Activity e widget (IOS-01 e IOS-02): a conta Apple e o projeto Xcode permitem adicionar as extensões?
5. Tela "Hoje" (CLR-03): vale a decisão pendente desde o 1.1 (21)?
6. Loja (LOJ-01): ligar a compra de verdade ou retirar da tela inicial?
7. Teto da folha (ECO-01): qual proporção da receita a diretoria deve aceitar?
8. Qual pacote vem primeiro depois do 26: iOS e som (27), profundidade (28), mundo visual (29), ao vivo e patrocínio (30) ou celular (31)?
9. Arte 3D: quem roda o Blender (seu computador ou um runner de CI), e qual o tamanho máximo de arte no app?
10. Os jogos ao vivo de outros campeonatos (AOV-01 a AOV-04) podem antecipar para o 26 ou 27?
