import SwiftUI

extension View {
    /// Alerta de uma folha (sheet). O alerta da tela de trás não aparece enquanto a folha está aberta,
    /// então cada folha que pode recusar uma ação mostra a recusa por conta própria.
    func sheetAlert(_ message: Binding<String?>) -> some View {
        alert("Manager de Futebol", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
