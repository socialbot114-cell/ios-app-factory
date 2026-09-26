# iOS App Factory

Nove protótipos SwiftUI para avaliação em iPhone e iPad. Os projetos usam XcodeGen, deployment target iOS 17+ e dados locais demonstrativos.

## Apps

1. Ateliê de Colorir
2. Crime Idle
3. Detetive na Testa
4. Manager de Futebol Brasileiro
5. Meu QR Pix Offline
6. Leitor PDF de Bolso
7. Brasília Política — Contexto
8. Diário do Sono
9. Quebra-Cabeças de Bolso

## Executar no Mac

```sh
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild test -project IOSAppFactory.xcodeproj -scheme CrimeIdle \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Escolha qualquer scheme listado em `project.yml`. Build de simulador não é instalável em iPhone/iPad físico.

## GitHub Actions

- **iOS app validation**: pull requests e pushes em `main`; roda testes em iPhone e iPad para cada app, em matriz com no máximo três jobs simultâneos.
- **iOS simulator screenshots**: disparo manual com um app ou `all`; constrói o app e captura estados reais do simulador para artifacts de revisão.

Os artifacts são temporários de revisão, não screenshots finais de App Store. Falhas de build/captura mantêm logs e resultados para diagnóstico. Nenhum workflow assina ou envia um app.

## Limitações deliberadas do protótipo

- Conteúdo editorial, arte e catálogo são demonstrações sinalizadas; precisam de autoria/licença/revisão antes de distribuição.
- O Diário do Sono é manual e não solicita microfone.
- Core Motion precisa de verificação adicional em aparelho físico.
- O QR Pix cria um payload estático demonstrativo; não confirma pagamentos nem substitui leitura/validação em apps bancários reais.
- O Leitor PDF inclui um documento local de exemplo; OCR não faz parte do protótipo.

Consulte [`specs/README.md`](specs/README.md) para o mapa das especificações de origem.
