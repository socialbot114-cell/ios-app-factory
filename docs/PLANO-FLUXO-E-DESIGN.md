# Plano — fluxo do dia/partida (frente 2) e design de mundo aberto (frente 3)

Base: tela de bloqueio na troca de dia, "O que fazer agora", chat e física da partida já entregues (ver `docs/ROADMAP-FUTOS.md`, seção "6 de outubro (2)"). Este plano termina com uma fase única de teste de tudo.

## Frente 2 — Fluxo do dia e da partida

### 2A. Antes do jogo: "Preparação" em passos
- Uma tela única, aberta pelo Gestor, com 4 passos: escalação, rival, estilo, condição. Usa `matchPreparation()` (já existe) e termina em "Pronto, ir ao estádio", que abre a partida.
- Passo concluído vira check; o que falta mostra o motivo (o `why` do guia).
- Arquivos: `Apps/Gestor/FootballMatchPrepFlow.swift` (novo), ajuste em `FootballDashboardView`; Core: reaproveita `matchPreparation()`.
- Pronto quando: da tela inicial até o apito inicial em no máximo 3 toques; nenhum passo exige sair do fluxo.

### 2B. Intervalo: conversa de vestiário
- Ao pausar no 45', abrir uma folha com 3 falas (Elogiar, Cobrar, Mudar o ritmo) e 1 ajuste rápido de tática.
- Efeito real e pequeno: moral e atributos de rendimento no 2º tempo (±), com limite para não quebrar o equilíbrio. Resposta do time no chat/narração.
- Arquivos: `Core/FootballHalftimeTalk.swift` (novo), `LiveMatchState` (campo opcional para saves), `Apps/Partida/FootballHalftimeSheet.swift`; ganchos em `FootballLiveMatchView`.
- Pronto quando: efeito determinístico por semente, coberto por teste de Core; saves antigos abrem.

### 2C. Pós-jogo: resumo e fechamento
- Cartão de fim de jogo antes da coletiva: placar, destaques (melhor em campo, gol, cartão), mudança em torcida/diretoria/moral (reaproveita `FootballPostMatchSummary` e `MatchImpact`).
- Ordem: apito final → resumo → coletiva → tela de bloqueio da noite.
- Arquivos: `Apps/Partida/FootballFullTimeCard.swift` (novo); `FootballHome` (ordem de apresentação).
- Pronto quando: a ordem não se perde em avanço rápido nem ao sair e voltar à partida.

### 2D. Física que falta
- Intervalo da prorrogação, disputa de pênaltis (cobrador, goleiro, comemoração), substituições animadas (placa e troca na lateral).
- Arquivo: `Apps/Partida/FootballPitchEngine.swift` (novas fases em `PitchPhase`).
- Pronto quando: pênaltis seguem o resultado da simulação (quem converte e quem perde).

## Frente 3 — Design e mundo vivo

### 3A. Menos ruído nas Mensagens
- Notícias e avisos do sistema agrupados por tipo, com "silenciar" e "marcar tudo como lido". Conversas de pessoas sempre acima.
- Arquivos: `Core/FootballChat.swift` (agrupamento por tipo), `Apps/Mensagens/FootballInboxView.swift`.

### 3B. Tela de bloqueio mais clara
- Uma pendência em destaque por vez (a do botão), as demais recolhidas em "mais N". Separar visualmente "Durante a noite" do resultado e do próximo jogo.
- Arquivo: `PhoneOS/FootballPhoneLockScreen.swift`.

### 3C. Papel de parede e ambiente
- Fundo muda com o momento: manhã, dia de jogo, noite, jogo em casa/fora; transição suave ao trocar de dia.
- Arquivo: `PhoneOS/FootballPhoneShell.swift` (`PhoneWallpaper`) com parâmetro de momento vindo do Core (`FootballCalendarClock`).

### 3D. Transições entre apps
- Abrir/fechar app com origem no ícone, vibração leve, respeitando "Reduzir movimento".
- Arquivos: `Sources/FootballHome.swift`, `PhoneOS/FootballPhoneHome.swift`.

### 3E. Mundo que reage
- Mensagens espontâneas após eventos: jogo (família, jogador, presidente), crise, proposta, aniversário/contrato. Regras no Core, máximo 2 por dia, com semente.
- Arquivos: `Core/FootballWorldReactions.swift` (novo), integração em `FootballChat`.

### 3F. Campo mais legível
- Câmera que acompanha a bola e zoom nos lances (gol, pênalti, falta), jogadores maiores.
- Arquivos: `Apps/Partida/FootballLivePitchView.swift`.

## Ordem sugerida
2A → 2C → 2B → 3A → 3B → 3C → 3D → 3E → 2D → 3F. Cada item entra com testes de Core (quando houver regra) e um estado de captura novo.

## Fase final — testar tudo
1. **Core (Docker Swift 5.9):** suíte inteira, mais testes novos de intervalo, mundo reativo e agrupamento de mensagens.
2. **Build iOS (CI):** compilar e rodar os UI tests no iPhone **e no iPad**; adicionar testes: preparação em passos, conversa do intervalo, resumo pós-jogo, bloqueio com avanço.
3. **Capturas (CI):** novos estados (`prep-flow`, `halftime-talk`, `fulltime-card`, `inbox-grouped`, `lock-night`, `wallpaper-night`, `penalties`) e artefato de conferência.
4. **Playtest guiado (~10 dias de jogo):** checklist com tempo por dia, quantos toques até jogar, se o guia acerta, se o bloqueio cansa, se há mensagem repetida.
5. **Critérios de aceite:** zero falha de teste; nenhum fluxo sem saída; saves antigos abrem; "Reduzir movimento" sem animação; contraste legível em claro e escuro.

## Riscos
- Efeito da conversa do intervalo pode desequilibrar resultados: limitar e testar em carreiras longas (`FootballLongCareerTests`).
- Ordem de apresentação (resumo, coletiva, bloqueio) é sensível a avanço rápido: cobrir com UI test.
- Câmera e física novas só se julgam em movimento: exigem playtest no aparelho.
