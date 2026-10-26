import AppFeature
import Testing

@MainActor
struct RootViewTests {
    @Test
    func makesBody() {
        _ = RootView().body
    }
}
