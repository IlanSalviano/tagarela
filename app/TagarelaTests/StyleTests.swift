import XCTest
@testable import Tagarela

final class StyleTests: XCTestCase {
    func test_4builtIns_haveDistinctIDs() {
        let ids = Set(BuiltInStyles.all.map(\.id))
        XCTAssertEqual(ids.count, 4)
    }

    func test_systemPrompt_includesCodeSwitchingClause_whenNotCru() {
        for s in BuiltInStyles.all where s.id != BuiltInStyles.cruSemReescrita.id {
            XCTAssertTrue(s.systemPrompt.contains("desenvolvimento de software brasileiro"),
                          "style \(s.name) sem cláusula code-switching")
        }
    }

    func test_cru_hasEmptySystemPrompt() {
        XCTAssertTrue(BuiltInStyles.cruSemReescrita.systemPrompt.isEmpty)
    }

    func test_defaultStyleID_pointsToConversaInformal() {
        XCTAssertEqual(BuiltInStyles.defaultStyleID, BuiltInStyles.conversaInformal.id)
    }
}
