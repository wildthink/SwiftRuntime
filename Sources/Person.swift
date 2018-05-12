import Foundation

public struct Person {
	public var name: String
	public var age: Int {
	    return 23
	}
}

extension Person: DynamicType {}

