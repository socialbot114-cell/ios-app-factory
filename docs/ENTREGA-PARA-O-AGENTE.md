# Pacote para o outro agente — disparar, acompanhar e relatar

Atualizado em 07/out/2026, 02:47 (Brasília). A rotina horária mantém este arquivo em dia; o estado real dos builds está na tabela de builds do `docs/ROADMAP-FUTOS.md`.

## Como usar quando você acordar

1. Leia a seção "Estado agora" para saber o que já passou.
2. Cole no outro agente, na ordem, os prompts A, B, C e D (cada um é independente; B só faz sentido se A estiver resolvido).
3. Jogue os roteiros da seção "O que você testa" no aparelho, quando o build chegar ao TestFlight.
4. Traga para mim o relatório do agente (modelo na seção "Relatório") e o que você achou jogando.

## Estado agora

| Item | Estado |
|---|---|
| 1.1 (10) | Aprovado e no TestFlight desde 06/out 22:29. Linha de base. |
| 1.1 (11) | Branch `ccr-020b52d1-16pkkp`, commit `2dfaa10`, run `37572402802` iniciado 07/out 01:38. Em validação às 02:47. O número 11 só é consumido quando o upload termina. |
| Entrega A (próximo build) | Branch `feature/entrega-a-ritmo`, a partir do mesmo commit do 11. Já tem: uma lenda no começo da carreira e uma por temporada (sem convidado por partida), tela de abertura (carregamento, Continuar, Novo jogo, Opções). Escrito, não compilado: só o CI valida. |
| Hall das Lendas | Já unido às duas branches acima. Não entra no TestFlight do Football; validado pelo workflow "iOS app validation". |

Regras que valem para todos os prompts:
- O agente **não altera código**. Dispara, acompanha e relata. Quem corrige sou eu, a partir do relatório.
- Nunca pular, desligar ou apagar teste para ficar verde.
- O workflow "Football TestFlight" roda um de cada vez e só guarda um pedido em espera (um pedido novo substitui o que estava esperando): não disparar um novo enquanto outro estiver em andamento.
- O número do build é consumido só no upload. Se um run for barrado no gate, o mesmo número pode ser usado de novo.

---

## Prompt A — Fechar o build 1.1 (11)

```
Projeto socialbot114-cell/ios-app-factory, workflow "Football TestFlight".
1. Veja o resultado do run 37572402802 (branch ccr-020b52d1-16pkkp, commit 2dfaa10, version 1.1, build 11).
2. Se terminou com sucesso e o passo "Upload TestFlight" e "Activate internal TestFlight after Apple processing" concluíram, responda apenas: "1.1 (11) enviado" com o horário de término (horário de Brasília, UTC-3).
3. Se falhou, NÃO altere código. Traga: nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro e, se houver, a hierarquia de acessibilidade anexada ao log (procure "Hierarquia:" no log do passo "Test iPhone and iPad"). Liste também os testes que passaram em número ("N testes, M falhas").
4. Se ainda estiver em andamento, diga em qual passo está e há quanto tempo, e volte a verificar a cada 15 minutos.
Não dispare outro run enquanto este não terminar.
```

## Prompt B — Próximo build: 1.1 (12), com a Entrega A

Só depois de A estar resolvido (11 enviado ou barrado e corrigido).

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "Football TestFlight" (football-testflight.yml) com:
  ref: feature/entrega-a-ritmo
  version: 1.1
  build: 12
Antes de disparar, confirme que não há outro run do mesmo workflow em andamento e que o build 12 ainda não foi usado (nome do artefato football-release-1.1-12 não pode existir em runs anteriores).
Acompanhe o run até o fim. NÃO altere código.
Se passar: responda "1.1 (12) enviado" com o horário de Brasília.
Se falhar: traga o nome exato de cada teste que falhou, a linha do arquivo, a mensagem de erro e a hierarquia anexada (procure "Hierarquia:" no log), e o número de testes que passaram. O build 12 continua livre nesse caso.
O que há de novo neste build: uma lenda no começo da carreira e uma por temporada (sem convidado por partida), tela de abertura com Continuar, Novo jogo e Opções, carregamento com dicas.
```

## Prompt C — Capturas de tela (iPhone e iPad)

Pode rodar junto com B (workflow diferente).

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "iOS simulator screenshots" (screenshots.yml) com:
  ref: feature/entrega-a-ritmo
  app: manager-futebol
  states: onboarding,onboarding-mode,loading,title,title-new,offseason-recap,offseason-contracts,offseason-review,offseason-pack,offseason-holiday,offseason-sponsor,offseason-preseason,offseason-kickoff
  families: iphone,ipad
Acompanhe até o fim. NÃO altere código.
Quando terminar, liste os nomes e IDs dos artefatos gerados. Se conseguir baixar e abrir as imagens, para cada uma diga em uma linha: texto cortado ou sobreposto, botão principal fora da tela, tela vazia ou cores ilegíveis. Se não conseguir baixar, diga só o resultado do run e os nomes dos artefatos.
```

## Prompt D — Hall das Lendas (validação do app novo)

```
Projeto socialbot114-cell/ios-app-factory. Dispare o workflow "iOS app validation" (validate.yml) com:
  ref: feature/entrega-a-ritmo
  app: hall-das-lendas
Acompanhe até o fim. NÃO altere código.
Relate: iPhone e iPad separadamente, quantos testes de domínio e de interface passaram, e para cada falha o nome do teste, a linha do arquivo e a mensagem de erro.
```

---

## O que você testa (quando o build chegar ao TestFlight)

Roteiros completos em `docs/PLANO-DE-TESTES.md`, seção 5. Resumo para a primeira noite:

1. **Abertura (build 12):** abrir o app. Esperado: carregamento com dica, depois a tela com Continuar, Novo jogo e Opções. Tocar em Opções e abrir "Reduzir movimento" e as carreiras salvas.
2. **Primeira abertura limpa:** apagar o app e instalar de novo. Esperado: Novo jogo, onboarding de cinco páginas, escolha de dificuldade, proposta de clube.
3. **Lenda inicial (build 12):** aceitar um clube. Esperado: o pacote de craque eterno abre sozinho na primeira visita ao Gestor; abrir e tocar "Escalar o craque". Fechar o app antes de abrir o pacote e reabrir: o pacote continua esperando.
4. **Jornada diária:** abrir o Gestor, jogar uma rodada ao vivo, ver o resultado. Contar toques. Anotar onde ficou perdido.
5. **Fim de temporada (ritual):** simular até o fim (ou usar um save perto do fim) e tocar "Encerrar temporada". Passar por todas as etapas, inclusive fechar o app no meio e voltar pelo painel "Entre temporadas". Esperado: um novo pacote de lenda chega no ritual.
6. **Qualquer erro, travada ou texto estranho:** anotar o que estava fazendo e tirar captura de tela.

## Relatório que o agente devolve para mim

```
Run:
Workflow e ref:
Versão e build:
Resultado (sucesso/falha/em andamento) e horário (Brasília):
Testes: N passaram, M falharam
Falhas (para cada uma): nome do teste, arquivo:linha, mensagem, hierarquia anexada (sim/não e o texto)
Artefatos (nome e ID):
Observações:
```

Quando você me trouxer isso, eu corrijo na branch certa e preparo o próximo build; o que ficar pendente entra no roadmap com data e hora.
