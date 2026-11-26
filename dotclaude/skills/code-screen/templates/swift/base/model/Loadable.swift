public enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed
}

public extension Loadable {
    var value: Value? {
        switch self {
        case let .loaded(value): value
        case .loading, .failed: nil
        }
    }

    var isLoaded: Bool {
        value != nil
    }

    var isFailed: Bool {
        switch self {
        case .failed: true
        case .loading, .loaded: false
        }
    }

    var isSettled: Bool {
        switch self {
        case .loaded, .failed: true
        case .loading: false
        }
    }

    var retrying: Self {
        isFailed ? .loading : self
    }
}

extension Loadable: Equatable where Value: Equatable {}
extension Loadable: Sendable where Value: Sendable {}
