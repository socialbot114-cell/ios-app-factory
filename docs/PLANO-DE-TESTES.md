# Plano de testes — como validar cada entrega

Vale para o Manager de Futebol (FutOS) e para o Hall das Lendas. Complementa o roadmap (`docs/ROADMAP-FUTOS.md`) e a ordem de entrega da seção 5f.

## 1. Princípios

1. Nenhuma entrega vai ao TestFlight sem o gate de testes verde. Hoje não existe compilador no ambiente de desenvolvimento assistido: o CI é a única prova de que o código compila e passa.
2. Cada entrega passa por quatro camadas, nesta ordem: CI, capturas de tela, jogo no simulador ou aparelho e TestFlight interno. Uma camada só começa quando a anterior passou.
3. Quem acha o problema registra o suficiente para outra pessoa reproduzir (modelo na seção 8). "Quebrou" sem número de run, versão ou passo a passo não é relatório.
4. Teste que falha nunca é pulado, desligado ou apagado só para ficar verde. Se o teste for novo e nunca passou, ele é marcado como pendente com motivo escrito e entra na lista da seção 7, com prazo.
5. Cada mudança de modelo de dados vem com teste de save antigo (o jogo precisa abrir saves anteriores sem perder a carreira).

## 2. Camadas e responsáveis

| Camada | O que prova | Quem roda | Quando |
|---|---|---|---|
| 1. CI (gate) | Compila, testes de domínio e testes de interface passam em iPhone e iPad | Workflow "Football TestFlight" (e "iOS app validation" para os outros apps), disparado por você ou pelo outro agente | A cada commit relevante e em cada entrega |
| 2. Capturas de tela | A tela existe, aparece sem estourar e não tem texto cortado ou ilegível | Workflow "iOS simulator screenshots", revisão de imagem por mim e por você | Depois do gate verde |
| 3. Jogo no simulador ou aparelho | O fluxo funciona de ponta a ponta, o ritmo é bom e a animação agrada | Você (roteiros da seção 5) | Depois das capturas |
| 4. TestFlight interno | Funciona no aparelho real, com tempo de uso real e sem falhas | Você e os testadores internos | Cada entrega, por pelo menos 2 dias de uso |

Regra de ouro: se a camada 1 falhar, quem acompanha o run lê o log, diz qual teste falhou e por que, antes de qualquer mudança de código.

## 3. Camada 1 — o que o CI cobre hoje e o que falta

Cobre: compilação, testes de domínio (salvos, regras, ritual de virada, craques eternos, mercado, banco) e os testes de interface do Manager de Futebol em iPhone e iPad. Para o Hall das Lendas: testes de domínio da coleção e da loja simulada e uma jornada de interface.

Ainda não cobre (e como tratar):
- Onboarding, ritual de virada e pacote de craque eterno não têm teste de interface, de propósito: um teste frágil trava o TestFlight. Cobertura é feita por teste de domínio, captura de tela (`onboarding*`, `offseason-*`) e roteiro manual (seção 5). Depois de uma entrega estável, escrever um teste de interface curto para cada um, com identificadores já existentes (`onboarding-continue`, `offseason-continue`, `offseason-holiday-*`, `icon-pack-open`).
- Compras reais: o CI usa a loja simulada. Compra de verdade só se testa com a configuração StoreKit local e depois no ambiente de testes da Apple (seção 6).
- Desempenho, memória e acessibilidade: não há medição automática. Entram nos roteiros manuais.

## 4. Camada 2 — capturas de tela

Estados já disponíveis no workflow de capturas: `onboarding`, `onboarding-mode`, `offseason-recap`, `offseason-contracts`, `offseason-review`, `offseason-pack`, `offseason-holiday`, `offseason-sponsor`, `offseason-preseason`, `offseason-kickoff`, mais os existentes do jogo. Para o Hall das Lendas: `showcase`, `collection`, `shop`, `detail`, `pack`.

Checklist de revisão de cada imagem:
- Texto não cortado, sobreposto nem ilegível em iPhone e iPad.
- Cores com contraste em tema claro e escuro (quando houver as duas versões).
- Botão principal visível sem rolar.
- Estados vazios e valores extremos (nome muito longo, caixa negativa, elenco no limite).

Rodar iPhone e iPad (`families: iphone,ipad`) em toda entrega que mexa em tela.

## 5. Camada 3 — roteiros de jogo

Cada roteiro tem passos e resultado esperado. Marque OK, falha ou observação, e anote o tempo quando houver.

### 5.1 Onboarding (primeira abertura)
1. Instalar limpo (ou apagar o app) e abrir. Esperado: cinco páginas, a primeira com fundo animado, ícone que "pula" e linhas que entram em cascata.
2. Deslizar e usar "Continuar". Esperado: ponto da página acompanha, vibração leve a cada página.
3. Tocar "Pular" na página 1. Esperado: vai direto à escolha de dificuldade.
4. Escolher Fácil, Normal e Difícil. Esperado: cartão selecionado com contorno dourado; no Fácil aparece o aviso do craque convidado.
5. Tocar "Escolher meu clube". Esperado: tela de propostas; ao fechar e abrir o app depois, o onboarding não volta.
6. Ligar "Reduzir movimento" no iOS e repetir. Esperado: conteúdo aparece sem animação.
Tempo: do início até aceitar uma proposta em até 2 minutos.

### 5.2 Ritual de virada de temporada
Pré-condição: temporada terminada (use um save perto do fim ou a simulação rápida).
1. No Gestor, tocar "Encerrar temporada". Esperado: abre o ritual em tela cheia com a barra de seis etapas.
2. Apito final: linhas aparecem em cascata e o botão só libera depois de ~1,8 s. Conferir posição, meta e artilheiro com a tabela.
3. Se houver contratos que vencem: lista com "Renovar". Renovar um jogador e confirmar que ele sai da lista. Seguir sem renovar outro.
4. "Virar a temporada": tela "Fechando a temporada…". Esperado: não trava; em seguida o balanço mostra prêmios, artilheiro, aposentadorias e base. Abrir "Relatório completo" e voltar.
5. Pacote de craque eterno (se houver): abrir, ver o giro e o brilho, tocar "Escalar o craque". Esperado: o craque aparece no elenco e na escalação.
6. Férias: o botão continuar fica bloqueado até escolher. Escolher e ler o efeito (moral, físico, lesões).
7. Patrocinador (só se o contrato acabou): escolher uma oferta. Esperado: oferta fechada aparece e libera continuar.
8. Pré-temporada: testar uma opção sem caixa suficiente (ela aparece travada); escolher uma com custo. Conferir o saldo no Banco.
9. Bola rolando: meta, caixa, patrocinador e primeiro adversário corretos. "Começar a temporada" fecha o ritual.
10. Voltar ao Gestor e conferir que dá para jogar.
Interrupções a testar: fechar o app no meio de cada etapa e reabrir. Esperado: painel "Entre temporadas" com "Continuar" retoma da mesma etapa; jogar fica bloqueado.
Casos extremos: ser demitido na virada (o ritual termina e as propostas de emprego aparecem); elenco com 0 contratos vencendo (etapa é pulada).

### 5.3 Craques eternos no jogo
1. Começar uma carreira nova e aceitar a proposta de um clube. Esperado: ao abrir o Gestor pela primeira vez aparece sozinho o pacote de craque eterno (uma vez só); abrir, ver o giro e o brilho e tocar "Escalar o craque".
2. Conferir: salário zero, não pode ser vendido nem dispensado, joga como titular e aparece no painel "Craque eterno da temporada".
3. Fechar o app antes de abrir o pacote e reabrir. Esperado: o pacote continua esperando no painel do Gestor.
4. Jogar uma partida com o craque e ver o nome nos lances e no relatório.
5. Mudar de clube (demissão e nova proposta). Esperado: o craque da temporada acompanha o treinador.
6. No fim da temporada o craque some do elenco antes do envelhecimento e um novo pacote chega no ritual de virada; o nome do antigo continua nos relatórios antigos.
7. Regra: só uma lenda por temporada, mais a do começo da carreira. Não existe escolha de convidado por partida.

### 5.4 Jornada diária (ritmo)
Cronometrar e contar toques: abrir o app, resolver duas ou três pendências, jogar uma rodada (ao vivo e na simulação rápida), ver o resultado. Referência: avançar uma rodada em até 3 toques; jogar ao vivo e fechar sem modal preso. Anotar qualquer lugar onde o jogador não sabe o que fazer.

### 5.5 Hall das Lendas
1. Vitrine: rolar o carrossel e ver paralaxe; tocar numa carta bloqueada e numa liberada.
2. Cartão do dia: abrir pelo banner, ver a animação, a carta emprestada por 24 h e o contador. Abrir de novo no mesmo dia: o banner some.
3. Coleção: filtros por raridade e progresso em anel.
4. Detalhe: inclinar a carta com o dedo e ver o brilho; conferir os números e a história.
5. Loja (simulada no CI, StoreKit real na seção 6): comprar uma carta e ver a comemoração; "Restaurar compras".

## 6. Camada 4 — TestFlight interno e compras

Antes de distribuir: confirmar no App Store Connect que o build processou e está em "Pronto para testar", e adicionar o grupo de testadores internos.

Roteiro do testador (2 dias de uso real): jogar uma carreira nova até o fim da primeira temporada, passar pelo ritual inteiro, abrir o pacote de craque e testar o modo Fácil. Enviar feedback pelo próprio TestFlight (captura de tela incluída).

Dados a coletar de cada testador: aparelho e versão do iOS, build, o que estava fazendo e uma captura de tela ou gravação.

Compras do Hall das Lendas (após criar os produtos no App Store Connect):
1. Primeiro no Xcode com `Products.storekit` (preços locais, sem cobrança).
2. Depois com conta Sandbox: comprar uma carta, comprar o pacote da coleção, cancelar no meio, simular falha, restaurar em outro aparelho com o mesmo Apple ID.
3. Conferir que a compra repetida não duplica a carta e que o número do exemplar não muda.

## 7. Matriz de aparelhos e condições

Rodar o roteiro 5.1 a 5.4 em, no mínimo:
- iPhone pequeno (ex.: SE) e iPhone grande (Pro Max), e iPad.
- Tema claro e escuro (quando existir o ajuste PER-03) e "Reduzir movimento" ligado.
- Texto grande (Dynamic Type) e VoiceOver nas telas novas: nenhuma ação importante sem rótulo.
- Sem rede e com rede lenta (o jogo é offline: nada pode travar).
- Aparelho de geração anterior, para olhar desempenho das animações.

Testes de interface pendentes (dívida a quitar): "Banco: simulador muda a projeção e restaurar volta ao valor", "Ajustes: criar e restaurar slot de carreira" e "Liga: abrir ficha do clube e navegar rodadas" estão pulados com motivo escrito. Reescrever cada um quando houver captura e hierarquia do ponto de falha; meta: voltar a rodar antes da Entrega C.

## 8. Como relatar um problema

Copiar e preencher:

```
Versão/build:
Aparelho e iOS:
Onde (app/tela/etapa):
Passos para repetir:
Esperado:
Aconteceu:
Frequência (sempre, às vezes, uma vez):
Captura ou vídeo:
Run do CI (se for do gate):
```

Gravidade:
- **Bloqueia**: perde carreira, trava, não dá para jogar ou crasha. Corrige antes de qualquer outra coisa e gera novo build.
- **Alta**: quebra uma jornada principal mas existe contorno. Entra no próximo build.
- **Média**: erro visual ou de texto que atrapalha. Entra na próxima entrega.
- **Baixa**: polimento. Vai para o roadmap.

Quando o gate falhar: quem acompanha traz o número do run, o nome do teste, a linha do erro e, quando existir, a hierarquia anexada. Só depois se mexe no código.

## 9. Critérios de saída de cada entrega

Uma entrega só vira "pronta" quando:
1. Gate do CI verde em iPhone e iPad, com o build enviado ao TestFlight.
2. Capturas revisadas sem texto cortado e sem tela vazia.
3. Roteiros 5.1 a 5.4 (e 5.5, se for o caso) executados em pelo menos dois aparelhos, sem problema de gravidade "Bloqueia" ou "Alta" aberto.
4. Teste de save antigo passando para cada mudança de modelo.
5. Dois dias de uso interno no TestFlight sem crash relatado.
6. Orçamento de toques da jornada diária (PIL-07) respeitado.

## 10. Estado atual

- Build 1.1 (10): aprovado no gate e no TestFlight. É a linha de base.
- Build 1.1 (11): em validação no CI, com craques eternos, onboarding, ritual de virada e plano atualizado. Se passar, seguir para as camadas 2 a 4 desta lista; se falhar, aplicar a regra da seção 8.
- Hall das Lendas: ainda sem workflow de distribuição; validação por "iOS app validation" e por capturas. Produtos de compra e direitos de imagem pendentes (LAN-01 e LAN-02).
