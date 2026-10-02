// swift-tools-version:5.9
// Pacote do motor do jogo (sem SwiftUI). Compila e testa no Linux; o app iOS inclui a mesma pasta Core.
import PackageDescription

let package = Package(
    name: "ManagerFutebolCore",
    targets: [
        .target(name: "ManagerFutebol", path: "Core"),
        .testTarget(name: "ManagerFutebolTests", dependencies: ["ManagerFutebol"], path: "Tests")
    ]
)
