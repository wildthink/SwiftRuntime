import Foundation

public struct Person {
    public var name: String
    public var birthday: Date
    // In years
    public var age: Int {
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year!
    }
}

extension Person: DynamicType {}

