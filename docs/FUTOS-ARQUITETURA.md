# FutOS — onde mora cada coisa

O FutOS é o "celular" do Manager de Futebol. Cada app do celular é uma micro-realidade que lê e escreve na mesma carreira (`FootballCareer`). Regra de ouro: **um assunto tem um dono só**; os outros apps apontam para ele com atalhos.

## Pastas (`apps/manager-futebol/Sources`)

| Pasta | O que tem |
|---|---|
| `PhoneOS/` | O sistema: lista de apps (`FootballPhoneApps`), notificações, tela de bloqueio, tela inicial, busca, barra de status/boot |
| `Apps/<App>/` | Um diretório por app do celular (Gestor, Tática, Liga, Transfer, Clube, Mensagens, Chuteira, Palpite, Rodada, Vida, Negócios, Metas, Troféus, Alertas, Marca, Banco, Contatos, Ajustes) |
| `Apps/Partida/` | Partida ao vivo e motor visual do campo (tela cheia aberta pelo Gestor) |
| `Apps/Elenco/` | Ficha de atleta, renovação, propostas e empréstimo; usados por Tática, Transfer e Busca |
| `Compartilhado/` | Componentes visuais comuns (escudos, notas, barras) |
| `Capturas/` | Telas de captura usadas só nos screenshots automáticos |

Lógica de jogo sem SwiftUI fica em `Core/` (compila e testa no Linux).

## Dono de cada assunto

| App | Dono de… | Não deve ter… |
|---|---|---|
| Gestor | agenda, próxima partida, preparação, resultado, coletiva | gestão de dinheiro, estrutura do clube |
| Tática | escalação, instruções, funções, treino | mercado |
| Liga | tabelas, copa, calendário, perfis de clubes | — |
| Transfer | contratações, propostas, observação, base | — |
| Clube | diretoria, estádio, estrutura/ingressos, comissão técnica, história/recordes/convites | finanças, marketing, patrocínio, carreiras salvas (viraram atalhos) |
| Banco | caixa do clube, folha, extratos, projeções, aporte do treinador | — |
| Marca | marketing, TV, torcida/pressão, patrocinador master e cotas | — |
| Negócios | loja, nome do estádio, projetos sociais, amistosos, empresários | — |
| Vida | energia, estresse, dinheiro pessoal, licenças, investimentos | — |
| Ajustes | carreiras salvas, dificuldade, desafios, avisos, tutorial, histórico de ações | — |

## Tempo do jogo

`Core/FootballCalendarClock.swift` dá data e hora a cada dia de jogo (rodadas aos domingos, copa às quartas; temporada 1 começa em 2027). A carreira expõe `gameDay`, `gameMoment` e `shortDate(matchDay:)`.

Ao avançar o calendário (jogar, simular, avançar dia), `FootballHome` observa `DayKey(season, matchDay)` e:

1. fecha apps e folhas abertos e **bloqueia o celular**;
2. a tela de bloqueio mostra a data/hora passando (fichas de cada dia, noite → amanhecer, tique de vibração);
3. entrega as novidades em widgets: último jogo, próximo jogo com horário, contadores (mensagens, propostas, alertas, metas) e as notificações mais urgentes;
4. a coletiva de imprensa pendente só abre depois que o treinador desbloqueia.

"Reduzir movimento" (sistema ou Ajustes) pula a animação. Os UI tests abrem o celular sem bloqueio; `--lock-on-advance` liga o comportamento.

## Partida: campo e narração

`PitchEngine` segue a súmula, não o contrário:

- gol, defesa, chance e **bola na trave** viram jogadas completas; o chute sai do ponto narrado (`event.x/y`);
- falta, cartão, lesão e impedimento **param o jogo** (bola morta, cobrador vai até a bola, árbitro se aproxima);
- bola que sai gera lateral/escanteio/tiro de meta;
- **intervalo**: todos vão aos bancos e param, a bola fica no centro e nada se mexe; no segundo tempo voltam e o visitante dá a saída;
- **apito final**: o campo congela;
- no modo "Ver jogo" o relógio espera a jogada narrada terminar antes do próximo minuto.

## Noite, guia e comunicação

- **Tela de bloqueio**: só aparece quando o dia do calendário muda (nunca ao abrir o jogo). Traz "Durante a noite": tudo que ficou pendente (respostas, decisões, escalação, propostas), com o botão **O QUE FAZER AGORA** no topo.
- **O que fazer agora** (`Core/FootballNextAction.swift`): `suggestions()` olha a carreira (coletiva, crise, decisões, titulares fora/cansados, mensagens sem resposta, propostas, elenco curto, energia, família, rotina de jogo) e ordena por urgência. O botão da tela inicial abre uma notificação com "Ir agora", que leva ao app (ou à mensagem/decisão exata). Depois da noite, a notificação aparece sozinha. Dicas rotativas (`dailyTip`) surgem de vez em quando.
- **Mensagens** (`Core/FootballChat.swift`): chat estilo WhatsApp com abas Jogadores, Comissão, Família e Clube. Mensagens do sistema viram balões com botões de resposta; mensagens rápidas (elogiar, cobrar, relatório, "O que fazer agora?", carinho) geram resposta e efeitos reais (moral, relação, estresse).
- **Chuteira**: histórias do dia, fotos nos posts (desenhadas pelo app a partir do tipo), anexar foto ao publicar (+15% de curtidas), curtir posts e atalho para as mensagens.

### Como o guia pontua (`FootballNextAction.swift`)

Cada sugestão tem `score` (0–100+), `category` e `why` (o que acontece se ignorar). Prioridade: ≥80 urgente, ≥50 importante, ≥25 bom fazer, abaixo disso rotina. Prazos curtos somam bônus (hoje +30, amanhã +22, até 3 dias +12). Cobre: coletiva, crise, decisões, escalação/preparação do jogo, promessas e contratos, mensagens (agrupa quando são muitas, as antigas pesam mais), propostas, moral baixa, elenco curto, caixa no vermelho/projeção negativa/folha no teto, TV e patrocínio, energia/estresse, família, metas. "Depois" adia até o dia seguinte (urgentes ≥80 não são adiadas). `dayPlan()` monta o roteiro do dia (máx. 2 por assunto + a rotina do calendário), mostrado no Gestor como "Plano do dia".
