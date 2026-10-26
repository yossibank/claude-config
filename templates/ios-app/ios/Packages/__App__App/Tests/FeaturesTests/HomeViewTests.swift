import Features
import Testing

@MainActor
struct HomeViewTests {
    @Test
    func makesBody() {
        _ = HomeView().body
    }
}
