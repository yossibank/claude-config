public struct Shown<Value: Hashable & Sendable>: ScreenEditable {
    public private(set) var current: Value?

    public init(_ current: Value? = nil) {
        self.current = current
    }
}

public extension Shown {
    var item: Value? {
        get {
            current
        }
        set {
            if let newValue {
                show(newValue)
            } else {
                closeAll()
            }
        }
    }

    subscript(_ value: Value) -> Bool {
        get {
            isShowing(value)
        }
        set {
            if newValue {
                show(value)
            } else {
                close(value)
            }
        }
    }

    func isShowing(_ value: Value) -> Bool {
        current == value
    }

    mutating func show(_ value: Value) {
        current = value
    }

    mutating func close(_ value: Value) {
        if current == value {
            current = nil
        }
    }

    mutating func closeAll() {
        current = nil
    }
}
