# Auditoria FutOS — incremento 02

## Estado da entrega

Código integrado localmente; sem commit, push ou publicação. Referência: Manager-futebol bugs e melhorias.

Três frentes foram distribuídas em concorrência: Liga, navegação FutOS e agenda. As duas primeiras retornaram entregas; a terceira foi interrompida pelo limite do agente após produzir arquivos, que foram revisados e incluídos nos testes do motor.

## Resultado técnico

| Verificação | Resultado |
|---|---|
| Motor Swift 5.9, compilação Debug | Passou |
| Suíte Debug completa | Interrompida por timeout; não contada como aprovação |
| Motor Swift 5.9, suíte Release completa | 159 testes, zero falhas |
| Tempo dos testes Release | 252,588 segundos, além da compilação |
| Parser Swift dos arquivos de interface | Passou |
| Validação estrutural da factory | Passou |
| Whitespace/diff check | Passou |
| Checagem de tipos SwiftUI com SDK iOS | Pendente |
| UI tests e capturas novas no simulador | Pendentes |

Warnings existentes sobre variáveis não usadas e descarte redundante de retorno Void permanecem; não impediram compilação/testes.

### Reprodução do motor no Linux com Docker

Executar da raiz do repositório:

```bash
docker run --rm -v "$PWD/apps/manager-futebol:/source:ro" -w /source swift:5.9 swift test -c release --scratch-path /tmp/football-release
docker run --rm -v "$PWD/apps/manager-futebol:/source:ro" -w /source swift:5.9 bash -lc 'swiftc -frontend -parse Sources/*.swift'
python3 tools/validate_factory.py
git diff --check
```

O parser verifica sintaxe, não existência de APIs nem resolução de tipos SwiftUI.

## Roteiro de auditoria visual e funcional

### A. Liga

1. Abrir Liga em carreira nova; selecionar rodada futura e verificar partidas sem placar.
2. Jogar/simular uma rodada e abrir seu resultado; conferir posse, finalizações e eventos registrados.
3. Navegar entre rodadas, Série A/B e Copa; conferir seleção independente das divisões.
4. Tocar num clube da tabela; conferir elenco, forma e calendário contra a carreira.
5. Abrir um artilheiro; conferir ficha de consulta e vínculo com clube.
6. Voltar entre fichas e relatórios sem perder navegação ou gerar sheet sobreposto.

### B. Gestor e agenda

1. Verificar contratos vencendo e prazos de propostas/eventos.
2. Iniciar uma promessa e conferir progresso e prazo no Gestor e Mensagens.
3. Simular quando há vencimento próximo: conferir confirmação e efeitos após avançar.
4. Usar avanço até decisão com proposta/evento pendente: não consumir essa decisão automaticamente.
5. Conferir contratos: avanço normal não deve tratar fim de temporada como liberação antecipada.

### C. Mensagens e compromissos

1. Ler apenas uma mensagem; contador deve reduzir somente uma unidade.
2. Aceitar pedido de minutos: resposta e compromisso precisam persistir ao reabrir.
3. Tentar prometer novamente: não renovar prazo nem aumentar moral.
4. Cumprir titularidades: resultado único com detalhes e moral correspondente.
5. Vencer prazo sem cumprir: registrar quebra e efeito na diretoria uma vez.
6. Recusar pedido e repetir ação: não aplicar penalidade novamente.

### D. FutOS

1. Buscar clube por nome e cidade; abrir ficha do resultado correto.
2. Buscar nome com e sem acento; conferir os mesmos resultados relevantes.
3. Buscar contato; consultar pessoa correta e disponibilidade da conversa.
4. Tocar em notificação de mensagem na central e no bloqueio; abrir o item correto.
5. Marcar a mensagem consultada como lida e conferir badge/notificação.
6. Conferir ordem de avisos com crise, coletiva e acontecimento próximo do prazo.
7. Validar textos longos, tamanhos de fonte maiores e retorno ao início.

## Limites conhecidos do incremento

- Mensagens continuam com lista de assuntos; conversas encadeadas completas ainda não foram implementadas.
- Notificação agora abre o componente real de Mensagens focado no assunto, com suas ações disponíveis. Apenas a mensagem aberta é marcada como lida.
- Fichas novas da Liga e busca são consultivas; não duplicam ações de gestão.
- Troca de clube/temporada ainda precisa de auditoria específica para compromissos: caminhos existentes limpam promessas.
- O roadmap dos 18 apps está em andamento; estas entregas não representam conclusão de todos os marcos.
- Nenhuma captura antiga constitui evidência visual das novas telas.

## Próxima passagem de validação

Em Mac com Xcode/XcodeGen, gerar `project.yml` e executar `xcodebuild test` para o scheme `ManagerFutebol`, usando simulador disponível. Capturar os estados acima somente após build aprovado. Atualizar este arquivo com run/commit e imagens geradas; só então aprovar a interface.

## Integração adicional — FutOS como ponto de entrada

- Agenda abre ficha do atleta para promessa/contrato; proposta abre sua mensagem acionável quando existe, com fallback para Transfer.
- Notificações usam `FootballInboxView` focado por ID, evitando uma segunda interface apenas consultiva.
- Busca de atleta aguarda o fechamento da busca antes de apresentar a ficha, evitando apresentações concorrentes de sheets.
- Cenários `agenda` e `commitment` incluídos na ferramenta de screenshots; carreira de captura contém promessa demonstrativa com resposta registrada.
- Jornada UI adicionada: `testFutOSNotificationOpensTheActualMessageAndAgenda`, com attachments previstos. Ainda não executada em simulador.
- Parser Swift de Sources e UITests aprovado; preflight e diff check aprovados após integração.
- O motor não foi alterado nesta passagem; os 159 testes aprovados correspondem ao mesmo código Core.

As capturas novas estão preparadas, mas ainda não foram geradas. Não apresentar imagens anteriores como evidência desta integração.
