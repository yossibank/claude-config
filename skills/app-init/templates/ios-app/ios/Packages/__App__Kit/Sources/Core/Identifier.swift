import Foundation

public struct Identifier<Owner>: Hashable, Sendable {
    public let uuid: UUID

    public init(_ uuid: UUID = UUID()) {
        self.uuid = uuid
    }
}

public extension Identifier {
    init?(_ text: String) {
        guard let uuid = UUID(uuidString: text) else {
            return nil
        }

        self.init(uuid)
    }
}

extension Identifier: CustomStringConvertible {
    public var description: String {
        uuid.uuidString.lowercased()
    }
}

extension Identifier: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)

        guard let value = Identifier(text) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid identifier: \(text)"
            )
        }

        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
