//: Playground - noun: a place where people can play

import Cocoa

public protocol Waldo {
    func value<T>() -> T?
    func type (for key: String) -> Any.Type?
    func get<T> (_ key: String, default value: T?) -> T?
    func set<T> (_ key: String, to value: T?)
}

public protocol DynamicType {
    var waldo: Waldo { get }
}

extension Waldo {
    public subscript<T> (key: String, default value: T?) -> T? {
        get { return get(key, default: value) }
        set { set (key, to: newValue) }
    }

    public subscript<T> (key: String) -> T? {
        get { return get(key, default: nil) }
        set { set (key, to: newValue ) }
    }

    func hasProperty(named name: String) -> Bool {
        return nil == type(for: name)
    }
}

public struct Person {
    public var name: String
    public var birthday: Date
    // In years
    public var age: Int {
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year!
    }
}

extension Person {

    public var waldo: Waldo { return _Waldo(this: self) }

    class _Waldo: Waldo {

        var this: Person
        func value<T>() -> T? { return this as? T }

        private static var type_map: [String:Any.Type] = [
            "name": String.self,
            "birthday": Date.self,
            ]

        init (this: Person) {
            self.this = this
        }

        public func type (for key: String) -> Any.Type? {
            return _Waldo.type_map[key]
        }

        public func get<T> (_ key: String, default value: T? = nil) -> T? {
            switch key {
            case "name": return this.name as? T
            case "birthday": return this.birthday as? T
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
            case "birthday":
                if this.birthday is T,
                    let tv = value as? Date {
                    this.birthday = tv
                }
            default:
                return
            }
        }
    }
}

var mary = Person(name: "Mary", birthday: Date(timeIntervalSince1970: 0))
let birthday: Date? = mary.waldo.get("birthday", default: nil)

let waldo = mary.waldo
waldo.set("name", to: "Mary Jane")
Swift.print (mary)
Swift.print (waldo.value()!)


