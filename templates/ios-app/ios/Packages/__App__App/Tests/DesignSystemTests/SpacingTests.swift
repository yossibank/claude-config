import DesignSystem
import Testing

struct SpacingTests {
    @Test
    func growsInOrder() {
        #expect(Spacing.small < Spacing.medium)
        #expect(Spacing.medium < Spacing.large)
    }
}
