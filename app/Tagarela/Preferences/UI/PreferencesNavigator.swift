import Foundation

/// Seção selecionada nas Preferências, compartilhada com quem precisa abrir a
/// janela **numa seção específica** — o aviso "permissões pendentes" do menu
/// abre direto em Permissões.
///
/// A janela de Preferências é reaproveitada entre aberturas, então um
/// `@State` dentro dela não serviria: ele guardaria a última seção vista e
/// ignoraria o pedido de ir para outra.
@MainActor
final class PreferencesNavigator: ObservableObject {
    @Published var selection: PrefsSection = .geral
}
