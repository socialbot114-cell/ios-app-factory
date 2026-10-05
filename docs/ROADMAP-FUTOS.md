# Roadmap FutOS — carreira viva de futebol

Referência de continuidade: **Manager-futebol bugs e melhorias**.

Status inicial: **planejamento registrado; implementação das etapas abaixo ainda não iniciada**.

Este roadmap evolui o Manager de Futebol para um mundo persistente acessado pelo celular FutOS. Parte das funcionalidades citadas já existe; as caixas representam trabalho incremental a validar, e não uma afirmação de que todos os sistemas precisam ser construídos do zero.

## 1. Objetivo e regras de produto

**Objetivo:** cada app deve permitir observar, planejar, decidir, acompanhar e recordar acontecimentos de uma mesma carreira. O futebol é o eixo; vida pessoal, relações e negócios produzem escolhas que o influenciam.

### Regras de experiência

- Uma decisão importante tem contexto, alternativas, custo de oportunidade e retorno visível.
- Consequências imediatas, atrasadas e históricas precisam ser distinguíveis.
- Personagens lembram compromissos; acontecimentos têm continuidade.
- Informação pública, observação profissional e rumores têm graus de confiabilidade distintos.
- Nenhum app precisa de tarefas obrigatórias todos os dias. Consulta e memória também têm propósito.
- Delegação e avanço rápido preservam uma jornada agradável para quem quer focar no campo.
- Conteúdo e personagens são fictícios; fichas do Palpite+ continuam separadas do dinheiro da carreira.
- Uma consequência econômica ou esportiva é aplicada uma única vez, mesmo quando aparece em vários apps.

### Premissas de trabalho, sujeitas a confirmação

1. O tempo avança por iniciativa do jogador; não há penalidades por ficar dias reais sem abrir o jogo.
2. A carreira permanece offline e determinística por semente.
3. O primeiro incremento usa os dias de jogo existentes. Manhã/tarde/noite e dias entre partidas só entram após validar o ciclo semanal.
4. Novas regras devem permitir carregar saves antigos com defaults e migrações explícitas.
5. Palpite+ fica opcional e com fichas fictícias; sua possível transformação em prognósticos é uma decisão posterior.

## 2. Como acompanhar

### Estados

`Planejado → Em andamento → Em validação → Concluído`

Uma caixa só é marcada depois da implementação e da verificação descrita. Para itens de desenho, a entrega é uma decisão registrada; para funcionalidades, é comportamento executável.

### Registro por entrega

| Campo | Preencher ao iniciar/concluir |
|---|---|
| ID | Fase e categoria, por exemplo `F2-MSG-01` |
| Objetivo | Qual problema do jogador será resolvido |
| Responsável | Pessoa ou sessão responsável |
| Estado | Um dos quatro estados acima |
| Dependências | Entregas necessárias |
| Evidência | Teste, captura, cenário manual ou resultado de simulação |
| Referência | Commit/PR quando houver |
| Próxima ação | Uma microação concreta |

### Painel de marcos

| Marco | Resultado | Estado | Evidência |
|---|---|---|---|
| M0 | Baseline funcional e decisões de produto | Planejado | — |
| M1 | Consequências e navegação compartilhadas | Planejado | — |
| M2 | Uma semana completa e coerente | Planejado | — |
| M3 | Pessoas com memória e negociação | Planejado | — |
| M4 | Clube, economia e vida com projetos contínuos | Planejado | — |
| M5 | Todos os 18 apps com propósito verificável | Planejado | — |
| M6 | Carreira multitemporada validada | Planejado | — |

Sem estimativas de calendário até medir a primeira entrega vertical. Revisar escopo ao concluir cada marco.

## 3. Sequência de implementação

### F0 — Baseline e decisões

**Objetivo:** estabelecer o que funciona hoje e escolher regras antes de ampliar o estado da carreira.

- [ ] F0-01 Inventariar ações, leituras, bloqueios, cooldowns e históricos de cada app.
- [ ] F0-02 Rodar os testes atuais do motor no Linux e registrar versão/resultado.
- [ ] F0-03 Verificar build e UI tests iPhone no macOS/GitHub Actions.
- [ ] F0-04 Capturar uma carreira nova, uma em andamento e uma no fim da temporada.
- [ ] F0-05 Classificar problemas confirmados por severidade e reprodução; separar ideias de bugs.
- [ ] F0-06 Confirmar ritmo de tempo, foco esportivo/narrativo e papel do Palpite+.
- [ ] F0-07 Selecionar saves de referência para testar migração e retomada.

**Meta M0:** baseline reproduzível, decisões registradas e nenhuma falha crítica conhecida sem encaminhamento.

### F1 — Fundação compartilhada

**Objetivo:** um fato do mundo pode gerar vários retornos, sem duplicar sua consequência.

- [ ] F1-01 Modelar fatos importantes com ID estável, origem, data de jogo e entidades envolvidas.
- [ ] F1-02 Definir resultado de decisão: efeitos aplicados, compromissos criados e próximos acontecimentos.
- [ ] F1-03 Definir compromissos e ações agendadas com prazo, estado e conclusão única.
- [ ] F1-04 Processar vencimentos em uma ordem explícita ao avançar o calendário.
- [ ] F1-05 Criar destinos de navegação que incluam app, seção e entidade específica.
- [ ] F1-06 Persistir novidade lida, resolvida e dispensada sem confundir esses estados.
- [ ] F1-07 Definir retenção de históricos para não crescer indefinidamente.
- [ ] F1-08 Introduzir versão de save e migração para os campos realmente implementados.
- [ ] F1-09 Verificar reabertura, repetição de comando, salto de calendário e determinismo.

**Meta M1:** um evento piloto chega a Mensagens, Chuteira e Notificações com o mesmo ID de origem; sua consequência ocorre uma única vez após salvar/carregar.

### F2 — Primeira entrega vertical: semana de jogo

**Objetivo:** dar profundidade ao ciclo principal antes de expandir todos os sistemas.

- [ ] F2-01 Escolher um cenário: reserva pede minutos antes de uma partida importante.
- [ ] F2-02 Mostrar pedido em Mensagens e necessidade de decisão no Gestor.
- [ ] F2-03 Permitir resposta com alternativas e prazo de compromisso.
- [x] F2-04 Acessar diretamente o atleta e a escalação pela conversa. Botões Ver atleta e Escalação na mensagem de pedido de minutos.
- [ ] F2-05 Preparar a partida usando relatório do rival e condição dos atletas.
- [ ] F2-06 Contabilizar presença e resultado usando dados da partida efetivamente jogada.
- [x] F2-07 Avaliar promessa, moral e relação ao vencer o prazo. Veredito cumprida/parcial/quebrada/justificada; moral por profissionalismo, relação com o empresário, lesão não pesa. `FootballPromiseOutcomeTests`.
- [x] F2-08 Produzir resposta do atleta, resumo do Gestor e repercussão pública somente quando justificável. Fala do atleta e consequências na mensagem; notícia pública só para craque (top 5) com profissionalismo baixo.
- [ ] F2-09 Mostrar pendências que expiram antes de confirmar avanço rápido.
- [x] F2-10 Verificar cumprir, quebrar, recusar e ignorar o pedido, inclusive após reabrir o app. Pedido ignorado por 3 dias de jogo cobra moral -4 uma vez; testes de save/reabertura. Suíte 177/177 no Docker swift:5.9.

**Meta M2:** uma jornada conectada entre Gestor, Mensagens, Tática e relatório pós-jogo, com retorno compreensível e persistente.

### F3 — Pessoas, memória e mercado

**Objetivo:** substituir relações genéricas e acordos instantâneos por processos com continuidade.

- [ ] F3-01 Acrescentar memória de conversas e compromissos aos personagens do piloto.
- [ ] F3-02 Introduzir interesses e preferências observáveis, sem personalidade aleatória a cada conversa.
- [ ] F3-03 Criar negociação em etapas: consulta, proposta, contraproposta, acordo/recusa/expiração.
- [ ] F3-04 Integrar interesse do atleta, papel no elenco e condições financeiras.
- [ ] F3-05 Adicionar concorrência por uma contratação e alternativas de recrutamento.
- [ ] F3-06 Conectar imprensa e rede social a fatos públicos, com fonte e confiabilidade.
- [ ] F3-07 Implementar follow-up de uma crise e de uma promessa quebrada.

**Meta M3:** contratar um atleta e resolver uma relação exigem escolhas contextualizadas; os participantes lembram o acordo.

### F4 — Projetos, economia e vida

**Objetivo:** criar decisões de médio prazo e fazer dinheiro, tempo e energia terem usos concorrentes.

- [ ] F4-01 Exibir projeção de caixa incluindo compromissos já assumidos.
- [ ] F4-02 Criar um projeto comercial com briefing, duração e avaliação posterior.
- [ ] F4-03 Criar uma reunião de diretoria com pedido e resposta futura.
- [ ] F4-04 Integrar atividades pessoais numa agenda com conflitos claros.
- [ ] F4-05 Permitir delegar uma rotina com custo, limite e relatório.
- [ ] F4-06 Balancear retornos para evitar combinações de ações sem custo que dominem a carreira.
- [ ] F4-07 Verificar comportamento em troca de clube, demissão e nova temporada.

**Meta M4:** jogador consegue planejar um projeto, acompanhar custos e observar efeitos durante vários dias de jogo.

### F5 — Amplitude dos 18 apps

**Objetivo:** completar as categorias abaixo com identidade própria e integração.

- [ ] F5-01 Revisar apps contra seus critérios de aceite individuais.
- [ ] F5-02 Completar Liga, Rodada e Palpite+ como experiências de análise e acompanhamento.
- [ ] F5-03 Completar Metas e Troféus como planejamento e memória da carreira.
- [ ] F5-04 Refinar FutOS: busca, notificações, retomada e acessibilidade.
- [ ] F5-05 Remover caminhos redundantes que confundam a função de cada app.

**Meta M5:** 18 apps revisados; cada um tem um propósito demonstrável e o jogador não precisa visitar todos para avançar.

### F6 — Estabilização e carreira longa

**Objetivo:** verificar coerência, balanceamento e usabilidade ao longo das temporadas.

- [ ] F6-01 Simular pelo menos 10 temporadas em múltiplas sementes e dificuldades.
- [ ] F6-02 Cobrir troca de clube, demissão, aposentadorias, contratos e projetos vencidos.
- [ ] F6-03 Testar migração, round-trip de save e retomada nos pontos de decisão.
- [ ] F6-04 Verificar limites de histórico, tempo de processamento e tamanho de save.
- [ ] F6-05 Executar jornadas UI no iPhone e revisar capturas reais; validar iPad para layouts alterados.
- [ ] F6-06 Fazer playtest e registrar decisões entendidas, confusas e repetitivas.
- [ ] F6-07 Corrigir falhas críticas e atualizar baseline, backlog e próximos marcos.

**Meta M6:** carreira multitemporada sem consequência duplicada, compromisso órfão ou falha crítica confirmada pendente.

## 4. Categorias e microações por app

As fases indicam quando começar. Concluir uma fase não implica concluir automaticamente todas as expansões de um app.

### 01 — Gestor | F2

**Objetivo:** ajudar o treinador a priorizar a semana.

- [ ] GES-01 Organizar pendências por prazo, importância e responsável.
- [ ] GES-02 Exibir compromissos e preparação do próximo jogo numa agenda.
- [ ] GES-03 Mostrar o que vence antes do próximo avanço de calendário.
- [ ] GES-04 Criar resumo pós-jogo com mudanças e causas, não apenas números finais.
- [ ] GES-05 Permitir avanço rápido até decisões escolhidas pelo jogador.

**Aceite:** jogador identifica o que exige atenção agora e consegue abrir o assunto específico em um toque.

### 02 — Tática | F2, expansão F4

**Objetivo:** preparar, executar e avaliar um plano de jogo.

- [ ] TAC-01 Salvar planos A/B com escalação e instruções.
- [ ] TAC-02 Comparar preparo físico, funções e ameaças observadas do rival.
- [ ] TAC-03 Relacionar treino e rotação ao calendário e às promessas aos atletas.
- [ ] TAC-04 Implementar um conjunto inicial de bolas paradas com efeito no motor.
- [ ] TAC-05 Vincular explicações pós-jogo aos dados reais; evitar atribuir causalidade que o motor não registra.

**Aceite:** duas escolhas táticas plausíveis têm trade-offs verificáveis; nenhum controle novo é apenas decorativo.

### 03 — Liga | F5

**Objetivo:** transformar números do campeonato em informação útil.

- [ ] LIG-01 Abrir ficha do clube ao tocar na tabela ou na busca.
- [ ] LIG-02 Abrir relatório de uma partida e ficha do atleta na artilharia.
- [ ] LIG-03 Navegar por rodadas anteriores e futuras.
- [ ] LIG-04 Exibir confronto direto, forma e dificuldade do calendário.
- [ ] LIG-05 Mostrar cenários matemáticos de acesso, título e rebaixamento quando aplicáveis.

**Aceite:** analisar o próximo rival e localizar uma partida histórica sem sair para uma lista genérica.

### 04 — Transfer | F3

**Objetivo:** recrutar por necessidade e negociar com informação imperfeita.

- [ ] TRF-01 Criar briefing de contratação: posição, perfil, orçamento e papel esperado.
- [ ] TRF-02 Salvar filtros e listas comparativas de candidatos.
- [ ] TRF-03 Mostrar conhecimento, data e confiabilidade dos relatórios.
- [ ] TRF-04 Negociar taxa, duração, salário e papel por etapas.
- [ ] TRF-05 Processar contrapropostas, concorrência e expiração pelo calendário.
- [ ] TRF-06 Validar custo total no Banco e registrar acordo no histórico.

**Aceite:** contratação completa atravessa observação, negociação e registro; orçamento e folha nunca são cobrados duas vezes.

### 05 — Clube | F4

**Objetivo:** governar um projeto esportivo com a diretoria.

- [ ] CLB-01 Separar avaliação esportiva, financeira e institucional.
- [ ] CLB-02 Criar reunião contextual com pedido de verba ou revisão de meta.
- [ ] CLB-03 Registrar resposta, condições e prazo da diretoria.
- [ ] CLB-04 Acompanhar obra por etapas com custos e impacto durante execução.
- [ ] CLB-05 Dar tarefas e relatórios à comissão; incluir delegação inicial.
- [ ] CLB-06 Consolidar legado e convites; mover gestão de saves para Ajustes.

**Aceite:** uma promessa à diretoria é acompanhada e avaliada, inclusive ao trocar de temporada.

### 06 — Mensagens | F2/F3

**Objetivo:** ser a interface de conversas e acordos da carreira.

- [ ] MSG-01 Agrupar mensagens por conversa, pessoa e assunto.
- [ ] MSG-02 Abrir conversa específica por notificação.
- [ ] MSG-03 Marcar leitura por conversa em vez de ler toda a inbox ao abrir o app.
- [ ] MSG-04 Adicionar respostas contextuais e follow-ups agendados.
- [ ] MSG-05 Distinguir lida, respondida, resolvida e expirada.
- [ ] MSG-06 Consultar promessas e anexos: ficha, proposta, relatório ou contrato.

**Aceite:** retomar uma conversa preserva respostas, prazo e compromisso; o histórico explica o desfecho.

### 07 — Chuteira | F3

**Objetivo:** simular uma esfera pública que reage ao mundo.

- [ ] CHU-01 Criar perfis persistentes de personagens e clubes.
- [ ] CHU-02 Associar postagens a fatos, rumores e fontes.
- [ ] CHU-03 Compor publicação escolhendo assunto, alvo e tom com prévia.
- [ ] CHU-04 Implementar respostas em thread e reações persistentes.
- [ ] CHU-05 Atualizar engajamento por etapas, sem sortear novamente ao abrir a tela.
- [ ] CHU-06 Conectar crises e publis a consequências futuras e memória pública.

**Aceite:** uma fala repercute de forma coerente em público, diretoria ou elenco; não há resposta repetível para farmar bônus.

### 08 — Palpite+ | F5

**Objetivo:** oferecer prognósticos opcionais com análise e acompanhamento.

- [ ] PAL-01 Confirmar papel do app antes de ampliar suas regras.
- [ ] PAL-02 Exibir dados públicos de forma, desfalques e confrontos.
- [ ] PAL-03 Persistir rascunho do bilhete e mostrar fechamento do mercado.
- [ ] PAL-04 Abrir detalhe do bilhete com partidas e justificativa da liquidação.
- [ ] PAL-05 Criar perfis de palpiteiros e histórico comparável de acertos.
- [ ] PAL-06 Preservar separação entre fichas, dinheiro pessoal e caixa do clube.

**Aceite:** cada resultado é rastreável ao jogo real da carreira e liquidado uma vez; participação é opcional.

### 09 — Rodada | F5

**Objetivo:** montar uma estratégia fantasy a cada rodada.

- [ ] ROD-01 Mostrar prazo de fechamento, jogos e disponibilidade dos atletas.
- [ ] ROD-02 Filtrar por preço, forma, confronto e risco de ausência.
- [ ] ROD-03 Persistir rascunho e permitir comparar escolhas de capitão.
- [ ] ROD-04 Exibir pontuação por atleta e componente após a rodada.
- [ ] ROD-05 Criar liga privada fictícia com personagens recorrentes.
- [ ] ROD-06 Compartilhar resultado no Chuteira sem duplicar recompensas.

**Aceite:** jogador entende como cada atleta pontuou e por que sua decisão teve resultado diferente dos rivais.

### 10 — Vida | F4

**Objetivo:** dar significado a tempo, energia e trajetória pessoal.

- [ ] VID-01 Planejar atividades com duração, energia e conflitos.
- [ ] VID-02 Criar continuidade para curso, livro e compromissos de mídia.
- [ ] VID-03 Associar descanso e apoio pessoal ao contexto da semana.
- [ ] VID-04 Mostrar custos recorrentes dos bens e uso contextual de suas vantagens.
- [ ] VID-05 Manter Vida disponível em períodos sem clube e revisar restrições atuais.
- [ ] VID-06 Exibir histórico de decisões pessoais e bem-estar.

**Aceite:** escolher um compromisso deixa explícito o que será adiado ou sacrificado; ficar desempregado não paralisa a vida.

### 11 — Negócios | F4

**Objetivo:** gerir projetos comerciais com acompanhamento.

- [ ] NEG-01 Definir coleção com público, preço, investimento e duração.
- [ ] NEG-02 Exibir demanda e relatório de vendas ao longo dos jogos.
- [ ] NEG-03 Negociar naming rights com condições financeiras e reação da torcida.
- [ ] NEG-04 Transformar projeto social em etapas com resultados registrados.
- [ ] NEG-05 Agendar amistoso/turnê antes da execução, incluindo desgaste e receita.
- [ ] NEG-06 Mostrar retorno realizado versus previsto de cada projeto.

**Aceite:** pelo menos um projeto exige planejamento, acompanhamento e avaliação final; receita não é bônus instantâneo sem contexto.

### 12 — Metas | F5

**Objetivo:** apoiar prioridades escolhidas e compromissos do mundo.

- [ ] MET-01 Identificar origem: jogador, diretoria, atleta ou personagem.
- [ ] MET-02 Permitir escolher e acompanhar um conjunto limitado de metas pessoais.
- [ ] MET-03 Abrir a ação contextual que ajuda a cumprir cada meta.
- [ ] MET-04 Exibir eventos que contribuíram para o progresso.
- [ ] MET-05 Registrar conclusão, falha e substituição sem perder histórico.

**Aceite:** progresso corresponde a ações reais; recompensas são únicas e metas não incentivam cliques sem propósito.

### 13 — Troféus | F5

**Objetivo:** preservar memória afetiva e legado.

- [ ] TRO-01 Registrar data, clube, partida e participantes do desbloqueio.
- [ ] TRO-02 Abrir o contexto histórico da conquista.
- [ ] TRO-03 Exibir progresso verificável de conquistas em andamento.
- [ ] TRO-04 Criar linha do tempo de títulos, recordes e temporadas.
- [ ] TRO-05 Permitir escolher destaques do perfil e compartilhar um marco.

**Aceite:** uma conquista pode ser revisitada com seu contexto original mesmo após mudança de clube.

### 14 — Alertas | F3

**Objetivo:** acompanhar acontecimentos com continuidade.

- [ ] ALE-01 Criar um arco piloto com início, atualização, decisão e encerramento.
- [ ] ALE-02 Mostrar participantes, origem, confiabilidade e prazo.
- [ ] ALE-03 Permitir pedir informação ou delegar quando o contexto comportar.
- [ ] ALE-04 Fazer a omissão gerar um desfecho registrado.
- [ ] ALE-05 Consultar cadeia de acontecimentos e efeitos posteriores.

**Aceite:** o arco tem ao menos dois desfechos significativos e comportamento definido se o jogador não responder.

### 15 — Marca | F4

**Objetivo:** gerir reputação, torcida e acordos de comunicação.

- [ ] MAR-01 Separar imagem do treinador, força da marca e humor da torcida.
- [ ] MAR-02 Definir campanha com objetivo, público, orçamento e prazo.
- [ ] MAR-03 Negociar contrato comercial com obrigações verificáveis.
- [ ] MAR-04 Mostrar evolução por período e fatos que contribuíram para ela.
- [ ] MAR-05 Avaliar campanha e refletir resultado em demanda e propostas futuras.

**Aceite:** jogador consegue explicar a mudança de imagem por acontecimentos observáveis, não por um número opaco.

### 16 — Banco | F4

**Objetivo:** planejar obrigações futuras e separar patrimônios.

- [ ] BAN-01 Separar conta do clube e conta pessoal, com extratos completos.
- [ ] BAN-02 Exibir recebíveis, despesas contratadas e vencimentos.
- [ ] BAN-03 Simular contratação/obra antes de assumir compromisso.
- [ ] BAN-04 Mostrar cenários e premissas da projeção, distinguindo garantido de estimado.
- [ ] BAN-05 Formalizar empréstimo do treinador com saldo e condições de devolução.
- [ ] BAN-06 Abrir o fato ou contrato associado a cada lançamento.

**Aceite:** saldo e extrato reconciliam; nenhuma transferência entre contas cria ou elimina dinheiro indevidamente.

### 17 — Contatos | F3

**Objetivo:** construir relações recíprocas com pessoas persistentes.

- [ ] CON-01 Abrir ficha específica pela busca e por mensagens.
- [ ] CON-02 Registrar temas, histórico, interesses e promessas.
- [ ] CON-03 Oferecer conversa contextual em vez de uma única ação genérica por papel.
- [ ] CON-04 Permitir que o contato proponha oportunidade ou peça ajuda.
- [ ] CON-05 Integrar confiança a preço, conselho e resposta institucional de forma explicável.
- [ ] CON-06 Tratar mudança de presidente/empresário e continuidade de família/amigo ao trocar de clube.

**Aceite:** relação evolui por acontecimentos e compromissos; não basta repetir o mesmo almoço para obter todos os benefícios.

### 18 — Ajustes | F1/F5

**Objetivo:** controlar a experiência do FutOS e da simulação.

- [ ] AJU-01 Centralizar saves, nova carreira, importação/exportação se incluídas no escopo.
- [ ] AJU-02 Configurar notificações por prioridade e tipo.
- [ ] AJU-03 Configurar pausas do avanço rápido e níveis de delegação.
- [ ] AJU-04 Adicionar preferências de acessibilidade e reduzir movimento.
- [ ] AJU-05 Separar ferramentas de configuração de tarefas de gestão do clube.
- [ ] AJU-06 Mostrar regras ativas dos desafios e mudanças de dificuldade.

**Aceite:** preferências sobrevivem à reabertura e não alteram silenciosamente as regras de um desafio.

## 5. FutOS — integração transversal

- [ ] OS-01 Permitir abrir o destino específico ao tocar em aviso da tela de bloqueio.
- [ ] OS-02 Ordenar notificações por prioridade e vencimento reais.
- [ ] OS-03 Fazer busca abrir clube, contato, atleta e seção exatos.
- [ ] OS-04 Distinguir selos de novidade de contadores de tarefas ativas.
- [ ] OS-05 Preservar aba, rolagem e rascunho ao alternar apps quando relevante.
- [ ] OS-06 Oferecer feedback contextual de ação e histórico persistente do resultado.
- [ ] OS-07 Explicar bateria/energia e sinal/humor com acessibilidade equivalente.
- [ ] OS-08 Verificar retorno de sheets, partida ao vivo e destinos aninhados.
- [ ] OS-09 Padronizar estados vazios úteis: informar quando e como haverá conteúdo.

**Meta:** navegar no celular parece acompanhar uma carreira; uma notificação não obriga a procurar novamente o assunto dentro do app.

## 6. Critérios globais de conclusão

Para cada incremento funcional:

- [ ] Há uma jornada descrita antes da implementação, incluindo alternativa e omissão quando aplicável.
- [ ] Custo, bloqueio, prazo e retorno são compreensíveis na interface.
- [ ] Estado relevante é persistido e retomado.
- [ ] Decisão e liquidação são idempotentes quando podem ser repetidas.
- [ ] Consequências cruzadas usam o mesmo fato de origem.
- [ ] Testes de domínio cobrem invariantes novas; UI tests cobrem jornadas críticas alteradas.
- [ ] Capturas reais demonstram novos estados no iPhone para mudanças visuais.
- [ ] Não há novo botão de gestão sem efeito no motor ou função de consulta clara.
- [ ] Há caminho de delegação ou omissão para conteúdo opcional.
- [ ] Marco e evidência foram atualizados neste roadmap.

### Indicadores para revisão

| Indicador | Meta inicial |
|---|---|
| Apps revisados contra aceite | 18/18 em M5 |
| Jornada vertical conectada | 1 completa em M2, depois ampliar |
| Consequências duplicadas nos cenários verificados | 0 |
| Compromissos sem conclusão/expiração definida | 0 |
| Saves de referência migrando | 100% dos selecionados em F0 |
| Falhas críticas confirmadas pendentes | 0 para M6 |
| Histórico financeiro reconciliado | 100% dos cenários econômicos verificados |
| Compreensão das decisões | Registrar no playtest; definir alvo após primeira amostra |
| Desempenho e tamanho do save | Medir baseline em F0; fixar limites antes de F6 |

Essas metas representam critérios futuros, não resultados já obtidos.

## 7. Próximo passo concreto

**Começar por F0 e depois pela fatia F2 do reserva que pede minutos.** Implementar somente a fundação F1 necessária para essa jornada, mantendo possibilidade de extensão.

Ordem das primeiras microações:

1. Medir baseline e verificar testes atuais.
2. Escrever os quatro desfechos do pedido: cumprir, quebrar, recusar e ignorar.
3. Identificar quais modelos existentes de mensagens e promessas podem ser reaproveitados.
4. Definir destino específico de conversa/atleta/escalação.
5. Implementar consequência, prazo e retomada.
6. Construir a experiência da conversa e o resumo de repercussões.
7. Verificar save/load e uma semana completa no simulador.
8. Registrar evidências e revisar o escopo da próxima entrega.

## 8. Diário de progresso

| Entrega | Estado | Evidência/referência | Próxima ação |
|---|---|---|---|
| Roadmap inicial | Concluído | Este arquivo | Iniciar F0 |
| F0 — baseline | Planejado | — | Inventariar e rodar verificações |
| F1 — fundação mínima | Planejado | — | Depende do cenário F2 detalhado |
| F2 — pedido de minutos | Planejado | — | Definir desfechos e reaproveitamento |

Atualizar este diário e as caixas a cada entrega verificada. Registrar mudanças de direção e itens adiados com motivo, preservando o histórico da jornada.

### Incremento inicial — implementação local em validação

Implementado, ainda sem aprovação de build Swift/iOS:

- Respostas persistentes aos pedidos de minutos, com progresso do compromisso em Mensagens e Gestor.
- Proteção contra substituir a mesma promessa repetidamente para ganhar moral e renovar prazo.
- Recusa explícita e idempotente, restrita a pedidos abertos do elenco atual.
- Resultado de promessa com ID de origem e detalhes de titularidades e efeitos.
- Encerramento da promessa quando atleta deixa o clube e tratamento de prazo de temporada anterior.
- Leitura individual de mensagem; abrir Mensagens não marca toda a inbox como lida.
- Avisos da tela de bloqueio abrem o app correspondente.
- Busca de contatos destaca a pessoa encontrada no app Contatos.
- Save versão 11, com novos campos opcionais para leitura de saves legados.
- Testes de domínio adicionados em `FootballCommitmentTests.swift`.

Verificações executadas: `python3 tools/validate_factory.py` passou; `git diff --check` passou.

Atualização de validação: Swift não está instalado no host, mas a imagem Docker local `swift:5.9` permitiu compilar e testar o motor. A suíte completa em Release passou: **159 testes, zero falhas**. Todos os arquivos `Sources/*.swift` passaram pelo parser `swiftc -frontend -parse`. Isso não substitui a checagem de tipos com o SDK iOS nem os UI tests. Não foram disparados workflows remotos nesta etapa.

Próximas ações: validar o incremento no macOS; detalhar conversa encadeada, omissão com prazo e destinos específicos por mensagem; verificar encerramento de compromissos ao trocar de clube/temporada. O roadmap completo permanece em andamento.

### Segundo incremento — entregas concorrentes integradas

- Agenda consultiva no motor: promessas, propostas, acontecimentos e contratos ordenados por prazo absoluto.
- Gestor mostra prioridades e confirma avanço rápido quando há itens próximos de vencer.
- Avanço até decisão considera a agenda antes de consumir um prazo importante.
- Liga permite navegar por rodadas, abrir partidas, consultar clubes e atletas da artilharia.
- Busca do FutOS normaliza acentos, caixa e espaços; clubes abrem ficha consultiva específica.
- Contatos abrem ficha específica e mensagens não lidas geram notificações individuais.
- Notificações são ordenadas por proximidade do prazo e prioridade; Metas usa indicação de tarefas ativas.
- Novos testes de agenda: ordenação, consulta pura, limites de vencimento e avanço de calendário.

Estado: motor verificado; interface em validação iOS. Cenários e comandos em `docs/AUDITORIA-FUTOS-INCREMENTO-02.md`. Não marcar M2/M5 completos: conversa encadeada, omissão contextual e demais expansões continuam pendentes.

### Integração FutOS — navegação e captura

Notificação passou a abrir a mensagem com ações no componente real de Mensagens. Agenda passou a abrir atleta/contrato ou mensagem de proposta específica. Busca de atleta aguarda o dismiss antes de apresentar outra ficha. Rotas de captura `agenda`/`commitment` e jornada UI contextual adicionadas. Parser e checks locais aprovados; execução UI e geração das novas capturas permanecem pendentes no macOS.
