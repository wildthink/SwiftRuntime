## Create a Swift Runtime with Sourcery

Perhaps the most important feature of Objective-C (ObjC) is its reflection API; a programmer interface, available at runtime, that provides access to an object's structure and class hierarchy by a string-name. This includes the names and types of every property, the names of every method with the type of every parameter, and the name of every Class and its ancestry. It wasn't the first language to provide this nor the last but in its day it demonstrated a significant advantage in the creation of robust tooling like Interface Builder and advanced libraries like the Enterprise Objects Framework (EOF).

At that time, we had to rely on the creators and developers of the compiler to provide new features if we could hope for anything at all. Today, Swift has Mirrors. These are useful but are limited in comparison to the runtime of ObjC (and other languages). For these core components and features, we still have to rely on the language/compiler community because they have access to the data structures that define and specify the structure of the Types and Classes we create.

But I want what I want and I want it now. And I want it in Swift.

ObjC was originally implemented as a pre-processor, parsing a special syntax to create an Abstract Syntax Tree (AST), this type of specification was used to drive the generation of standard C code which, in turn, was fed to the compiler. Doing the same thing today would just be ugly. And we can't just crack open the compiler.

Rats!

But wait.

The designers of the [LLVM](https://en.wikipedia.org/wiki/LLVM), a modular compiler toolchain, had the foresight to design the compiler process in a new way, a pipeline that allows us to tap into the products of different stages of the compiler. This is still complicated but fortunately some knowledgable, industrious and virtuous people have created two important components to help; [SourceKitten](https://github.com/jpsim/SourceKitten) and [Sourcery](https://github.com/krzysztofzablocki/Sourcery). 

Many many thanks to [JP Simard](https://twitter.com/simjp) and [Krzysztof Zabłocki](https://twitter.com/merowing_) and to the supporting community of contributors.

SourceKitten links and communicates with `sourcekitd.framework` to parse our Swift source code into an AST and Sourcery combines a cleaner interface to the AST with several templating engines to generate code (or text) as we desire.

Sourcery is already being applied to many domains and used in over 8,000 projects. It's well worth learning about. You can start with their [github](https://github.com/krzysztofzablocki/Sourcery). Go check it out. I can wait.

Okay then, let's proceed.

Basically what I want (for now) is the ability to have a more data driven system, configurable with external textual data. This could be as simple as putting CSS-like styling information in a file to be injected on-demand at runtime. Or it could involve a dynamic message passing infrastructure - sending commands and parameters between loosely bound components.

We'll take a look at how you can leverage Sourcery to re-create some features of the Objective-C runtime in Swift. It's not complete but is intended as a meaningful example of what you can do with a bit of forethought and a small amount of coding with the right tools. Not a contrived example but hopefully something to get you thinking and provide enough working code to be useful and to build upon.

#### Backstory

I’m all-in with Swift these days but being an old, Objective-C guy there are definitely times when I miss the dynamic runtime of ObjC. Even though type-safety is all the rage (with many a good reason) there are still times when I want to `get` or `set` a property by name or call a method given its name (or #selector). So for quite a while I found myself changing my `structs` to `classes` to leverage the @objc annotations but straddling the fence just isn't comfortable.

Way back when, I was known to pop the hood on the Objc Runtime, bash the `isa` pointer, lookup implementation pointers, fiddle with the va_list to call the function, and create classes at runtime. Mostly for fun but there were a few times when it was just the ticket to solve a particular problem.

Dangerous? Indubitably. Effective? Absolutely (in special cases).

This wasn't for the feint of heart but it was interesting and instructive. To be fair, some folks have done something similar in Swift by manipulating the underlying memory layout. But that's not going to be our approach. When you get right down to it, all that's going on is that the compiler is building a bunch of data structures for us under the hood and exposing an API for us to use them. So why not do this ourselves for our own Swift `structs` and `classes`; it's not really "rocket surgery". But man can it be tedious.

We're not going to re-create the full runtime here but hopefully enough to be at least instructive, if not useful. Note that this will work for `structs` as well as `classes` BUT it requires a bit of care when dealing with `structs` (as we will see). There are clearly different ways to approach this design-wise, I'm presenting only one solution of many. The real point is to demonstrate what can be done with thoughtful design, the right tools, and minimal effort.

#### What Is It We Want?

##### Step 1 - Let's start off by deciding what we would like to express, specifically, in code.

For our example, we are going to create an API to help us with properties. Given the (String) name of a property we will be able to look up its declared type and get and set its values in a type-safe way without throwing or raising any exceptions. The one flaw is that if we ask for an unknown property we just get back `nil` so we can’t be sure if the value really is `nil` or if we misspelled something.

To encapsulate this API we are going to define a **Waldo** (a <u>remote manipulator</u>). To identify the types we want to access with a Waldo, we introduce a new protocol, `DynamicType` - something that each of our types will need to adopt. This protocol acts as a marker for Sourcery as we will see later. Waldo is not unlike Swift's Mirror in intent but it's something we own and get to define.

Waldo is defined as a protocol and each type must provide its own implementation providing access to its members. Formally, we define a `DynamicType` and `Waldo` as follows.

```swift
public protocol DynamicType {
    func waldo() -> Waldo
}

public protocol Waldo {
    func value<T>() -> T?
    func type (for key: String) -> Any.Type?
    func get<T> (for key: String, default value: T?) -> T?
    func set<T> (_ key: String, to value: T?)
}
```

For our example we will need something to work with. A simple `Person` will do. Note that `age` is a computed property - so it's read-only.

```swift
public struct Person {
    public var name: String
    public var birthday: Date
    // In years
    public var age: Int {
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year!
    }
}
```

Next, let's think about how we would like to use this new API.

```swift
var mary = Person(name: "Mary", birthday: Date(timeIntervalSince1970: 0))
let waldo = mary.waldo()
let age: Any = waldo.get("age")
waldo.set("name", to: "Mary Jane")
mary = waldo.value() // To get the updated Person
```

##### Step 2 - Create a working exemplar by hand.

As mentioned, this is going to be a bit tedious, but it's easier to flesh out any implementation issues before creating the template. We won't need to do this for every one of our types - that's where Sourcery comes in. We'll nest each definition of a concrete Waldo in the Type it operates over and provide a `getter` to return an instantiation of it. Note that each Waldo is a custom implementation based on the type that it manipulates.

To comply with the protocol we need three methods:

- `type (for key: String)`, For the `type` information we just hook into a Dictionary, mapping names to Swift types.

- `get<T> (for key: String, default value: T? = nil) -`  The get method uses a switch on the property name to select a return of the value cast to whatever type is asked for.

- `set<T> (_ key: String, to value: T? = nil)` - similar strategy as for the `get`

Note that the age variable gets a getter but not a setter as it's calculated and read-only.

```swift
extension Person {

    public fun waldo() -> Waldo { return _Waldo(this: self) }

    class _Waldo: Waldo {

        var this:Person
        private static var type_map: [String:Any.Type] = [
            "name": String.self,
            "birthday": Date.self,
            "age": Int.self,
        ]

        init (this: Person) {
            self.this = this
        }

        public func type (for key: String) -> Any.Type? {
            return _Waldo.type_map[key]
        }

        public func get<T> (for key: String, default value: T? = nil) -> T? {
            switch key {
                case "name": return this.name as? T
                case "birthday": return this.birthday as? T
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
```



###### Note: Special Instructions for dealing with structs

If the object being manipulated by Waldo is a `struct` then we must remember that it is passed by value, so mutating operations ONLY APPLY TO THE COPY that the Waldo holds. Currently there isn't any way to capture a reference to a `struct`. We must use the Waldo's `value()` method to extract an object having the newly set values. We must also be aware that each call to get the object's Waldo will return a new Waldo holding a new copy of the instance when that instance is a `struct`.

```swift
var mary = Person(name: "Mary")
let name: String? = mary.waldo().get("name", default: nil)

let waldo = mary.waldo()
waldo.set("name", to: "Mary Jane")
Swift.print (mary)
// -> Person(name: "Mary")
Swift.print (waldo.value()!) 
// -> Person(name: "Mary Jane")
```



##### Step 3 - Turn our example into a template

This is where we get our leverage from Sourcery. Backed by SourceKitten, Sourcery gives us access to the AST for every swift type in our project. In our case we are only interested in the ones that implement our DynamicType protocol. For each of our DynamicTypes, we iterate over its public variables and emit a `case` to return the variable's value if-and-only-if it satisfies the requested type, `nil` otherwise, likewise for publicly writable setters.

The template is provided below for completeness but I refer the reader to the [Sourcery documentation](https://cdn.rawgit.com/krzysztofzablocki/Sourcery/master/docs/index.html) for the syntax and detailed instructions on creating templates. Of course to actually generate the code you will need to download and install [Sourcery](https://github.com/krzysztofzablocki/Sourcery).

```swift
// swiftlint:disable variable_name
import Foundation

{% for type in types.based.DynamicType %}
extension {{ type.name }} {

    public func waldo() -> Waldo { return _Waldo(this: self) }

    class _Waldo: Waldo {

        var this:{{ type.name }}
        private static var type_map: [String:Any.Type] = [
            {% for variable in type.variables|instance %}
            "{{variable.name}}": {{variable.typeName}}.self,
            {% endfor %}
        ]

        init (this: {{ type.name }}) {
            self.this = this
        }

        public func type (for key: String) -> Any.Type? {
            return _Waldo.type_map[key]
        }

        public func get<T> (for key: String, default value: T? = nil) -> T? {
            switch key {
                {% for variable in type.variables|instance|publicGet %}
                case "{{variable.name}}": return this.{{variable.name}} as? T
                {% endfor %}
                default:
                    return value
            }
        }

       public func set<T> (_ key: String, to value: T? = nil) {
            switch key {
                {% for variable in type.storedVariables|instance|publicSet %}
                {% if variable.isMutable %}
                case "{{variable.name}}":
                {% if variable.isOptional %}
                    if this.{{variable.name}} is T?,
                {% else %}
                    if this.{{variable.name}} is T,
                {% endif %}
                        let tv = value as? {{variable.typeName}} {
                        this.{{variable.name}} = tv
                    }
                {% endif %}
                {% endfor %}
                default:
                    return
            }
        }
    }
}

{% endfor %}
```

##### Step 4 - Tidy up.

For Sourcery to recognize our type as a candidate it can apply the template to, we extend it to adopt the `DynamicType` protocol.

```Swift
extension Person: DynamicType {}
```

It was a little work to get us here, but with the power of auto-generation we can easily enable any and all of our own types to be dynamic with the added bonus that any enhancements (or fixes) to your Waldo can be applied with a single command.

```
$ sourcery --sources <sources path> --templates <templates path> --output <output path>
```

Enjoy!

#### Resources

You can find the code and templates along with a playground with the starter implementation here.

[github/SwiftRuntime](https://github.com/wildthink/SwiftRuntime) BSD Licensed example code

And Sourcery docs and github here.

 [Sourcery documentation](https://cdn.rawgit.com/krzysztofzablocki/Sourcery/master/docs/index.html) 

 [Sourcery](https://github.com/krzysztofzablocki/Sourcery)


