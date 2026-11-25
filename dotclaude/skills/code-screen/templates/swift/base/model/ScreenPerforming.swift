@MainActor
public protocol ScreenPerforming: AnyObject {}

public extension ScreenPerforming {
    @discardableResult
    func perform(_ work: @escaping @MainActor (Self) async -> Void) -> Task<Void, Never> {
        Task {
            await work(self)
        }
    }
}
