// Generated using Sourcery 0.10.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable variable_name
import Foundation
import CodeBase

extension Person {

    public var lens: Lens { return _Lens(this: self) }

    class _Lens: Lens {

        var this:Person
        private static var type_map: [String:Any.Type] = [
            "name": String.self,
        ]

        init (this: Person) {
            self.this = this
        }

        public func type (for key: String) -> Any.Type? {
            return _Lens.type_map[key]
        }

        public func get<T> (for key: String, default value: T? = nil) -> T? {
            switch key {
                case "name": return this.name as? T
                case "age": return this.age as? T
                default:
                    return value
            }
        }

       public func set<T> (_ key: String, to value: T? = nil) {
            switch key {
                case "name":
                    if this.name is T,
                        let tv = value as? String {
                        this.name = tv
                    }
                default:
                    return
            }
        }
    }
}

