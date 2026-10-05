# Baseline do FutOS — inventário, decisões e saves de referência

Mantido pela sessão 6a. Estado do código: branch `manager-futebol/phases-2-7`. Evidência de testes: suíte de domínio (Docker `swift:5.9`), build iOS e capturas no GitHub Actions.

## F0-01 · Inventário por app (ações, leituras, bloqueios, cooldowns e históricos)

| App | Leituras principais | Ações | Bloqueios / cooldowns | Histórico |
|---|---|---|---|---|
| **Gestor** | agenda ordenável (prazo, importância, responsável), preparação do próximo jogo, resumo da rodada, diretoria, treino | jogar, simular, avançar até decisão (pausas escolhidas em Ajustes) | confirmação quando algo vence no próximo avanço | resumo pós-jogo por partida |
| **Tática** | elenco, formação, instruções, funções, comparativo do rival, desgaste projetado | planos A/B, escalação, estilo, funções, treino, bolas paradas | planos só fora da partida; formação precisa ser preenchível | planos salvos; rotina de bola parada |
| **Liga** | classificação, cenários (título/acesso/permanência), confronto direto, dificuldade do calendário | abrir clube, partida e rodadas | só mostra o que o calendário permite | resultados e relatórios |
| **Transfer** | briefings, comparação, relatórios datados, disputas por contratação | briefing, negociação em etapas, assinatura, observação | janela aberta, caixa e teto salarial; contraproposta vale 2 dias; 3 recusas encerram | negociações e fatos |
| **Clube** | estádio, estruturas, avaliação da diretoria, reunião de diretoria, obra em etapas | melhorias, reunião, ingressos | uma obra por vez; paralisa sem caixa | evolução das estruturas |
| **Mensagens** | conversas por pessoa ou assunto, anexos, estados | responder, prometer, marcar conversa, dispensar | pedido sem resposta por 3 dias expira; conversa marcada cobra se esquecida | todas as mensagens (80) |
| **Chuteira** | linha do tempo com fonte e confiabilidade, perfis, memória pública | publicar com assunto, alvo e tom (prévia), responder comentários, crises | uma publicação por dia; crise bloqueia posts | posts, respostas, memória pública (20) |
| **Palpite+** | briefing do jogo, desfalques, mercados, liquidação | bilhete, rascunho persistido | fechamento ao avançar o calendário; participação opcional | histórico de liquidações |
| **Rodada** | prazo, filtros, comparação de capitães | escalação fantasy, capitão | prazo da rodada; rascunho persistido | pontuação por rodada |
| **Vida** | plano de 6 dias, bens, bem-estar, projetos pessoais | atividades, plano, bens, comentarista | uma atividade por dia; viagem bloqueia presenciais | decisões pessoais, série de 30 dias |
| **Negócios** | loja, coleções, naming, programas sociais, amistosos, delegação, livro de projetos | coleção, naming negociado, projeto social, amistoso/excursão | coleção em andamento bloqueia outra; teto de investimento da delegação | livro de projetos previsto × realizado |
| **Metas** | metas com origem, progresso, histórico | adotar/trocar até 3 metas | recompensa única; apostas só se adotadas | concluídas, não cumpridas, substituídas |
| **Troféus** | conquistas com progresso e contexto, linha do tempo, destaques | marcar até 3 destaques | conquistas antigas sem contexto | linha do tempo da carreira |
| **Alertas** | acontecimentos e arcos (boato do craque), cadeia de eventos | decidir, pedir informação, delegar | prazo do arco: 4 dias; omissão tem desfecho | arcos encerrados (últimos 3 visíveis) |
| **Marca** | 3 indicadores (imagem, marca, torcida) e o que mudou | campanha com briefing, contrato de imagem | uma campanha por vez; contrato com obrigações em 10 dias | retrato de 40 dias |
| **Banco** | projeção de caixa (garantido × estimado), extrato, empréstimos do treinador | aporte, devolução, simulação de obra/contratação | parcelas só com caixa ≥ 0 | extrato reconciliado diariamente |
| **Contatos** | cartões, assuntos por contato, ficha | conversar (uma por dia de jogo), pedidos | pedidos com prazo de 3 dias; presidente exige clube | histórico de conversas e combinados |
| **Ajustes** | dificuldade e regras, avisos, movimento, pausas do avanço rápido | alterar preferências | dificuldade trava durante desafio ativo | mudanças de dificuldade registradas |

## F0-04 · Capturas dos três estados

- **Carreira nova:** rota `select` (escolha do clube) e `home` logo após aceitar.
- **Carreira em andamento:** `home`, `phone`, `table`, `agenda` e demais rotas (uma temporada completa e oito dias da seguinte).
- **Fim de temporada:** rota `season-end` (todas as rodadas jogadas, Gestor com o painel de encerramento).

## F0-05 · Problemas confirmados, por severidade

| Sev. | Problema | Reprodução / evidência | Estado |
|---|---|---|---|
| Alta | Compromissos e conversas ficavam abertos depois de o atleta sair do clube | `FootballLongCareerTests` (10 temporadas × 3 sementes) | Corrigido: `cancelOrphanedCommitments` |
| Alta | Avanço rápido ignorava as pausas escolhidas | `FootballAdvancePausesTests` | Corrigido (GES-05) |
| Alta | Troca de clube herdava naming, loja, programas e coleção do clube anterior | testes de F4-07 (sessão 01) | Corrigido |
| Média | Folga prometida cumprida era julgada como quebrada (ordem do tick) | `FootballContactRelationsTests` | Corrigido |
| Média | Dificuldade exibida divergia do desafio ativo | captura `settings-phone` | Corrigido |
| Média | Elenco em branco no Actions após o hub de preparação | captura `squad` do lote 8 | Corrigido: hub recolhido |
| Média | UITest do Gestor intermitente (toque no dock durante a animação de saída) | xcresult do `validate.yml` 37300463930 | Corrigido nos testes; confirmação pendente |
| Baixa | Rota de captura `match-prep` abria a partida ao vivo | print do lote 9 | Corrigido: lista exata de rotas |
| Baixa | "Conversa ao vivo" exige pausa manual quando o modo Pausar está ligado | desenho do modo | Aceito |

Ideias (não são bugs): reduzir texto repetido em Metas ("acontecimento decidido ×N", já agrupado), unificar chips redundantes ("Ver ficha" e "Ficha" em Mensagens).

## F0-06 · Decisões de produto registradas

- **Ritmo de tempo:** um dia de jogo por avanço; o avanço rápido para só onde o jogador escolheu (decisões, lesões, propostas; coletiva opcional). Padrão da coletiva: dispensada, como sempre foi.
- **Foco:** primeiro esportivo (partida, tática, elenco), depois narrativo (mensagens, imprensa, arcos), por último economia pessoal. A partida padrão abre em **Narração**; **Ver jogo** é opção.
- **Palpite+:** participação opcional, em fichas fictícias; nenhuma meta obrigatória depende de apostar.
- **Publicações:** uma por dia; consequências aparecem em etapas (1 e 3 dias) e entram na memória pública.
- **Delegação:** sempre com custo, teto e relatório (gerente comercial, empresário, comissão técnica).

## F0-07 · Saves de referência

`FootballReferenceSavesTests` cobre seis saves: nova carreira, meio de temporada, fim de temporada, três temporadas, partida em andamento e demitido. Para cada um: reabrir, comparar fatos, compromissos, partida ao vivo e agenda, e continuar produzindo o mesmo jogo. Também há um save legado sem nenhum campo dos sistemas novos que abre e volta a funcionar.
