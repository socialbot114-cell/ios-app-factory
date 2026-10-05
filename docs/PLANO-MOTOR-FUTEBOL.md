# Plano — Motor do Manager Futebol

## Estado atual (diagnóstico)
- `MatchSimulation.step` roda minuto a minuto com RNG por minuto derivado da seed; o resultado é determinístico, e simulado (rápido) e detalhado dão o mesmo placar.
- Limitações encontradas: no máximo 1 finalização por lado por minuto; só 5 tipos de finalização; assistente sorteado sem relação com a jogada; tackles nunca eram contados; todos os jogos tinham o mesmo "caráter"; eventos só de gol, chance, defesa e cartão.

## Fase 1 — Feito nesta entrega (Core/FootballMatchVariety.swift + FootballLiveEngine)
1. **Personalidade da partida (`MatchFlavor`)** derivada da seed: ritmo, volatilidade da posse, rigor do árbitro, jogo aéreo, jogo pelas pontas. Todos com média 1, então o equilíbrio de gols não muda. Dá um título ao jogo.
2. **Jogadas construídas (`BuildUp`)**: cruzamento, passe em profundidade, tabela, puxada de linha, lançamento, escanteio, falta, rebote, jogada individual, bola recuada. Cada uma escolhe quem finaliza e quem passa por posição e função (ponta/lateral cruzam, armador faz passe em profundidade, zagueiro/volante lançam, especialista cobra bola parada), e gera o texto coerente.
3. **Ações sem gol** (`actionPhase`, fluxo de RNG separado, não altera placar): impedimento, desarme (agora conta nas estatísticas e na nota), drible ganho/perdido, cruzamento afastado, bola na trave. Novos `MatchEvent.Kind`: `offside, tackle, dribble, cross, woodwork`.
4. Seeds por minuto passam por SplitMix (`MatchSimulation.mix`) e os fluxos de texto e ação ficam separados do principal.
5. Testes novos: variedade de perfis e de eventos, média de ritmo = 1, assistências entre 55% e 85% dos gols.
6. Refino: título do perfil normalizado por traço (com "Jogo equilibrado" quando nenhum se destaca) e anunciado pelo narrador na saída de bola; no máximo um lance secundário narrado por minuto, nunca por cima de gol, chance, cartão ou lesão; ordem de narração alternada entre os lados; escolha ponderada por atributo (velocidade no impedimento, drible, desarme, cabeceio no corte do cruzamento); cerca de 12 desarmes por time contados na nota, com peso 0,05.
7. Teste de calibração com 300 jogos variados da liga: gols, desarmes, volume de narração e minutos sem lances amontoados.
   Medição atual por jogo: 2,92 gols · 30,9 chutes · 26,0 faltas · 4,4 cartões · 28,2 desarmes · 49 eventos narrados.
   Antes desta entrega, o mesmo confronto fixo de referência dava 3,77 gols e 46 eventos; agora dá 3,67 gols e 56 eventos. O placar não se deslocou; a narração ganhou cerca de 10 lances.
   Próximo ajuste sugerido (Fase 4): chutes um pouco acima do real (cerca de 24 a 26), então reduzir a taxa de finalização e subir o xG médio na mesma proporção.

## Fase 2 — Coordenação coletiva
- Cadeia de passes real: lista de 2 a 4 participantes por posse, com estatística de passes-chave e `passes completados`.
- Pressão coordenada: `pressing` e `lineHeight` mudam a chance de recuperação alta, impedimento e contra-ataque do rival.
- Compactação: distância entre linhas (formação + largura) afetando espaço entre linhas, em vez de só modificadores de ataque/defesa.
- Entrosamento: jogadores com mais jogos juntos aumentam a chance de tabela e passe em profundidade.

## Fase 3 — Estado de jogo e IA
- Momentum com memória (gol sofrido, expulsão, pênalti desperdiçado) alterando ritmo por 5 a 10 minutos.
- IA tática: reagir a placar, cartões, fadiga e formação do rival; substituições por perfil (atacante fresco ao perder, zagueiro ao ganhar).
- Árbitro com perfil próprio (`MatchFlavor.strictness` já é a base) e VAR em pênaltis e gols.
- Lesões com causa (choque, esforço) em vez de sorteio uniforme.

## Fase 4 — Calibração e qualidade
- Harness de calibração (500+ jogos): gols/jogo, chutes, escanteios, cartões, posse, vitória do favorito, comparados com metas reais (ex.: 2,6 gols, 24 chutes, 10 escanteios, 3,8 cartões por jogo).
- Teste de equivalência: mesmo seed, modo rápido e detalhado, mesmo placar.
- Ajustar constantes (`goalCalibration`, `foulsPerMinute`, pesos de `BuildUp`) só depois do harness.

## Fase 5 — Integração visual
- `FootballPitchEngine` já consome `goal/save/chance`; adicionar `woodwork`, `dribble`, `tackle`, `cross` e `offside` como animações curtas (bandeira, drible, carrinho).
- Usar `BuildUp` e o campo `relatedPlayerID` para desenhar a cadeia de passes antes do chute.
- Mostrar o título do jogo (`flavor.title`) no pré-jogo e no resumo.

## Riscos
- Testes rodam no Linux com a imagem Docker `swift:5.9`:
  `docker run --rm -v "$PWD":/pkg:ro -v /tmp/mfbuild:/build -w /pkg swift:5.9 swift test --scratch-path /build`
  (em `apps/manager-futebol`). A suíte completa leva cerca de 10 minutos.
- Mudou a ordem de consumo do RNG, então resultados antigos por seed mudam. Saves em andamento continuam abrindo, porque `MatchSimulation` não ganhou campos armazenados e os novos `Kind` são aditivos.
