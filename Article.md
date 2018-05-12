## Create a Swift Runtime with Sourcery

#### Abstract

We'll take a look at how you can leverage Sourcery, the best open-source Swift code-generator to re-create features of the Objective-C runtime in Swift. This is not a Sourcery tutorial. Rather, its intended as a meaningful example of what you can do with a bit of forethought and a small amount of coding with the right tools. Not a contrived example but hopefully something to get you thinking with enough [working code](https://github.com/wildthink/SwiftRuntime) to be useful and to build upon.

##### Kudos

Many thanks to [Krzysztof Zabłocki](http://merowing.info) for creating and maintaining [Sourcery](https://github.com/krzysztofzablocki/Sourcery)

#### Intro

I’m all-in with Swift these days but being an old Objective-C guy there are definitely times when I miss the dynamic runtime of ObjC. Even though type-safety is all the rage (with many a good reason) there are still times when I want to `get` or `set` a property by name or call a method given its name (or #selector). So for quite a while I found myself changing my `structs` to `classes` to leverage the @objc annotations but straddling the fence just isn't comfortable, if you take my meaning.

Way back when I was known to pop the hood on the Objc Runtime, bash the `isa` pointer, lookup implementation pointers, fiddle with the va_list to call the function, and create classes are runtime. Mostly for fun but there were a few times when it was the ticket to solve a particular problem.

Dangerous? Indubitably. Effective? Absolutely (for special cases).

This isn't for the feint of heart but it is instructive. And to be fair, some folks have done something similar in Swift by manipulating the underlying memory layout. But that's not going to be our approach. When you get right down to it, all that's going on is that the compiler is building a bunch of structures for us under the hood and exposing an API for us to use. So why not do this myself for my Swift structs and classes; its not really "rocket surgery". But boy can it be tedious.

Then along came [Sourcery](https://github.com/krzysztofzablocki/Sourcery). If you're not familiar with this tool created by [Krzysztof Zabłocki](http://merowing.info/) you need to be. Its amazing.

Essentially...

> **Sourcery** is a code generator for Swift language, built on top of Apple's own SourceKit. It extends the language abstractions to allow you to generate boilerplate code automatically.
>

There are some great resources on [github](https://github.com/krzysztofzablocki/Sourcery) to learn from so go check it out. I can wait.

Okay then, let's proceed.

We're not going to re-create the full runtime but enough to be instructive if not useful. Note that this will work for `structs` as well as `classes` BUT we require a bit of care when dealing `structs` as we will see. There are clearly different ways to approach this design-wise so I'm not advocating this in particular. The real point is to demonstrate what can be done with not a lot of effort.

#### What Do We Want

##### Step 1

Let's start off by deciding what we would like to express in code.

This time around we are going to create an API to help us with properties. Given the (String) name of a property we will be able to lookup its declared Type and get and set its values in a type-safe way without throwing or raising any exceptions. The one trade-off we will make is that if we ask for an unknown property we just get back nil so we can't be sure that we didn't mistype something or the value is really nil. Not awful but as we will see, we can even provide a solution for that as well.

To avoid cluttering the original type with additional methods via `extension` we are going to create another `struct` that will wrap an instance giving us the desired API to the object. However, unlike Swift's Mirror, I am going to add one virtual property, the `lens`, to the original Type because I find it more convenient.

For our example, lets create a very simple type to play with. Since using a `struct` introduces a few wrinkles we use it to illustrate; using `classes` is more straight forward.

```swift
struct Person {
    var name: String
}
```

Next, lets think about how we would like to use this new API.

```swift
let mary = Person(name: "Mary")
mary.lens.set("name", to: "Mary Jane")
```

Formally, we define a `DynamicType` and `Lens` as follows.

```Swift
public protocol DynamicType {
    var lens: Lens { get }
}

public protocol Lens {
    func value<T>() -> T?
    func type (for key: String) -> Any.Type?
    func get<T> (for key: String, default value: T?) -> T?
    func set<T> (_ key: String, to value: T?)
}
```

##### Step 2

Create a working exemplar by hand.

As I mentioned this is a bit tedious but its easier to flesh out any implementation issues before creating the template. The pattern here is to create a nested definition of a concrete Lens and provide a getter to return an instantiation of it. For the `type` information we just hook into a Dictionary. The `get` method uses a `switch` on the property name to select a return of the value cast to whatever type is asked for.

```swift
extension Person {

    public var lens: Lens { return _Lens(this: self) }

    class _Lens: Lens {

        var this: Person
        func value<T>() -> T? { return this as? T }

        private static var type_map: [String:Any.Type] = [
            "name": String.self,
            ]

        init (this: Person) {
            self.this = this
        }

        public func type (for key: String) -> Any.Type? {
            return _Lens.type_map[key]
        }

        public func get<T> (_ key: String, default value: T? = nil) -> T? {
            switch key {
            case "name": return this.name as? T
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
```



###### Note: Special Instructions for dealing with structs

If the object being manipulated by the lens is a `struct` then we must remember that it is passed by value so mutating operations ONLY APPLY TO THE COPY. We must use the Len's `value()` method to extract an object having the newly set values. We must also be aware that each call to get the object's lens will return a new lens holding a new copy.

Its not pretty, I know, but currently there isn't any way to capture a reference to a `struct`.

```swift
var mary = Person(name: "Mary")
let name: String? = mary.lens.get("name", default: nil)

let lens = mary.lens
lens.set("name", to: "Mary Jane")
Swift.print (mary)
// -> Person(name: "Mary")
Swift.print (lens.value()!) 
// -> Person(name: "Mary Jane")
```



##### Step 3

Turn our example into a template.

The template is provided below for completeness but I refer the reader to the [Sourcery documentation](https://cdn.rawgit.com/krzysztofzablocki/Sourcery/master/docs/index.html) for the syntax and detailed instructions on creating templates. Of course to actually generate the code you will need to download and install [Sourcery](https://github.com/krzysztofzablocki/Sourcery).

```
// swiftlint:disable variable_name
import Foundation

{% for type in types.based.DynamicType %}
extension {{ type.name }} {

    public var lens: Lens { return _Lens(this: self) }

    class _Lens: Lens {

        var this:{{ type.name }}
        private static var type_map: [String:Any.Type] = [
            {% for variable in type.storedVariables|instance %}
            "{{variable.name}}": {{variable.typeName}}.self,
            {% endfor %}
        ]

        init (this: {{ type.name }}) {
            self.this = this
        }

        public func type (for key: String) -> Any.Type? {
            return _Lens.type_map[key]
        }

        public func get<T> (for key: String, default value: T? = nil) -> T? {
            switch key {
                {% for variable in type.storedVariables|instance|publicGet %}
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

##### Step 4

Tidy up.

To have your new type (struct or class) be Dynamic simply extend it thusly. 

```Swift
extension Person: DynamicType {}
```

It was a bit of work to get us here but with the power of auto-generation you can easily enable any and all of your own types with the added bonus that any enhancements (or fixes) to your Lens can be applied with a single command.

```
$ sourcery --sources <sources path> --templates <templates path> --output <output path>
```

#### Resources

github/[SwiftRuntime](https://github.com/wildthink/SwiftRuntime) BSD Licensed example code

 [Sourcery documentation](https://cdn.rawgit.com/krzysztofzablocki/Sourcery/master/docs/index.html) 

 [Sourcery](https://github.com/krzysztofzablocki/Sourcery)



