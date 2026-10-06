# Revisão FutOS — 6 de outubro de 2026

Objetivo: melhorar os produtos do FutOS e apresentar capturas reais antes de outro lançamento.

## Incremento

- Rodada: pontuação por componente/atleta, snapshot da última rodada, perfis e comparação na liga dos amigos, publicação contextual no Chuteira.
- Banco: cenários de entrada, salários e parcelas; comparação garantido/esperado, presets de elenco e obra, zerar simulação sem alterar caixa real.
- Ajustes: criar/carregar/apagar slots através da raiz do FutOS, com confirmação de substituição e identificação do espaço ativo.
- Liga: destinos com IDs e retorno explícito, nova jornada completa substituindo o teste pulado.
- Captura: seleção de estados e famílias; rotas novas para revisar resultados, compartilhamento, planejamento e saves.

## Invariantes

- Consulta financeira não registra transações; parcelas têm ordenação determinística.
- Fantasy não liquida rodada pendente nem paga duas vezes. Compartilhar respeita a publicação diária e não reaplica fichas/prêmios.
- Snapshot técnico separado das frases que o jogador lê. Saves sem snapshot mostram ausência de detalhe em vez de reconstrução incorreta.
- Rivais do fantasy são fictícios com pontos simulados, sem afirmar escalações inexistentes.
- Saves e todas as apps compartilham a carreira selecionada.

## Verificações

| Verificação | Resultado |
|---|---|
| Motor completo Release, Swift 5.9 Docker | 388 testes, zero falhas, 121,242 s após compilação |
| Parser Sources/UITests | Aprovado |
| Preflight e diff check | Aprovados |
| Seleção de estados de captura | Aprovada |
| Build e testes iPhone/iPad deste incremento | Aguardando workflow |
| Capturas novas deste incremento | Aguardando workflow |
| Nova publicação TestFlight | Não solicitada nesta entrega |

## Revisão visual solicitada

1. Celular: bloqueio, início e notificações.
2. Semana: pedido/conversa → preparação → jogo → pós-jogo.
3. Banco: saldos mínimos antes/depois de um preset, parâmetros e reset.
4. Rodada: soma dos componentes, capitão 1,5×, comparação e prévia de compartilhamento.
5. Ajustes: espaço em uso, criar segunda carreira e restaurar a primeira.
6. Liga: ficha do clube → atleta → voltar; rodada futura/passada → partida → voltar.

Não usar prints de commits anteriores como aprovação desta entrega. Acrescentar runs e pasta de capturas após conclusão.
