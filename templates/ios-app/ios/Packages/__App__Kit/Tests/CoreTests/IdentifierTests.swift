import Core
import Foundation
import Testing

struct IdentifierTests {
    @Test
    func roundTripsText() throws {
        let id = Identifier<IdentifierTests>()
        let parsed = try #require(Identifier<IdentifierTests>(id.description))

        #expect(parsed == id)
    }

    @Test
    func rejectsInvalidText() {
        #expect(Identifier<IdentifierTests>("invalid") == nil)
    }
}
