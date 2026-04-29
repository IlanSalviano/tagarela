import XCTest
@testable import Tagarela

@MainActor
final class StyleProviderTests: XCTestCase {
    private final class FakeCustomStore: CustomStyleStore, ObservableObject {
        var styles: [CustomStyle]
        init(styles: [CustomStyle] = []) { self.styles = styles }
        func reload() async {}
        func create(name: String, systemPrompt: String, appendCodeSwitching: Bool) async throws -> CustomStyle {
            fatalError()
        }
        func update(_ style: CustomStyle) async throws { fatalError() }
        func delete(_ style: CustomStyle) async throws { fatalError() }
    }

    func test_all_mergesBuiltInAndCustom() {
        let custom = CustomStyle(name: "aaa primeiro alfabeticamente",
                                  systemPrompt: "p", appendCodeSwitching: false)
        let store = FakeCustomStore(styles: [custom])
        let provider = StyleProvider(customStore: store)
        let names = provider.all.map(\.name)
        XCTAssertEqual(names.first, "aaa primeiro alfabeticamente")
        XCTAssertEqual(provider.all.count, 5)  // 4 built-in + 1 custom
    }

    func test_styleForId_findsBuiltIn() {
        let store = FakeCustomStore()
        let provider = StyleProvider(customStore: store)
        XCTAssertNotNil(provider.style(for: BuiltInStyles.conversaInformal.id))
    }

    func test_styleForId_findsCustom() {
        let custom = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: false)
        let store = FakeCustomStore(styles: [custom])
        let provider = StyleProvider(customStore: store)
        XCTAssertEqual(provider.style(for: custom.id)?.id, custom.id)
    }

    func test_styleForId_unknown_returnsNil() {
        let provider = StyleProvider(customStore: FakeCustomStore())
        XCTAssertNil(provider.style(for: UUID()))
    }

    func test_styleOrDefault_unknown_returnsConversaInformal() {
        let provider = StyleProvider(customStore: FakeCustomStore())
        let style = provider.styleOrDefault(for: UUID())
        XCTAssertEqual(style.id, BuiltInStyles.defaultStyleID)
    }
}
