# Roadmap Manager de Futebol — builds 24 a 26

Escrito em 16/out/2026 (horário de Brasília), depois da rodada de polimento do build 23.
Este documento continua o `docs/ROADMAP-FUTOS.md`, que é cronológico e muito longo. Aqui ficam só os próximos passos, com critérios de aceite.

## 1. Onde estamos

- **No TestFlight interno:** 1.1 (23), branch `release/1.1-23` @ `c59ce2f`, run `38939859482`, todos os passos verdes (gate de testes de iPhone e iPad, archive, upload e ativação).
- **Linha de entrega:** `release/1.1-21` → `release/1.1-22` → `release/1.1-23`. Nenhuma delas foi mesclada em `feature/entrega-a-ritmo` ainda.
- **O 1.1 (22)** trouxe: ações da base em 15, renovadas 50% na metade da temporada e 100% no fim; plantel de 30; escolha de titulares; pedidos à diretoria sobre salário e gastos; alertas dentro das fichas.
- **O 1.1 (23)** trouxe: singular e plural em mais de 60 textos; toque na linha inteira em seis listas; alerta dentro da folha de mensagem; Tática com o campo primeiro; botão Trocar sem quebra de linha; onboarding centralizado; texto de renovação na Academia.
- **Antes e depois do 23:** artefato publicado em https://claude.ai/artifact/LFpTygSbRq9VdvxGpFxs8X

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

## 6. Build 26 em diante — equilíbrio e mundo vivo

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

## 7. Ordem sugerida e dependências

1. **Rodada no aparelho** com o 1.1 (23): iniciar carreira, comprar um jogador, simular uma rodada, virar a temporada. Não gasta build e reordena este plano.
2. **Build 24:** CMP-01 a CMP-03, PRT-01, QLD-01, ELE-01, TUT-01 (e SEM-01 se sobrar tempo). QLD-01 deve entrar **antes** de PRT-01 para que o ajuste da partida seja medido.
3. **Build 25:** TEL-01 a TEL-10 e SOM-01. TEL-01 e TEL-02 primeiro; os demais dependem das peças padrão.
4. **Build 26+:** itens da seção 6, um de cada vez, com a decisão do usuário e a medição antes e depois.
5. **Mesclagem:** decidir quando `release/1.1-22` e `release/1.1-23` entram em `feature/entrega-a-ritmo`.

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

1. Build 24 só de lógica e build 25 só de telas, ou juntos? (Recomendação: separados.)
2. Quando mesclar `release/1.1-22` e `release/1.1-23` em `feature/entrega-a-ritmo`?
3. O que exatamente quebrava no onboarding e na virada de temporada?
4. Para os sons (SOM-01): há arquivos de áudio, ou será preciso criar ou licenciar?
5. Para a Loja (LOJ-01): ligar a compra de verdade ou retirar da tela inicial por enquanto?
6. Para o teto da folha (ECO-01): qual proporção da receita a diretoria deve aceitar?
