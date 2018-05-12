# SwiftRuntime
How to use Sourcery to recreate the ObjectiveC runtime for your own Swift structs and classes.

### Abstract

We'll take a look at how you can leverage Sourcery, the best open-source Swift code-generator to re-create features of the Objective-C runtime in Swift. This is not a Sourcery tutorial. Rather, its intended as a meaningful example of what you can do with a bit of forethought and a small amount of coding with the right tools. Not a contrived example but hopefully something to get you thinking with enough [working code](https://github.com/wildthink/SwiftRuntime) to be useful and to build upon.

### How-to

Install Sourcery - see [Sourcery](https://github.com/krzysztofzablocki/Sourcery) for more options.

[*Homebrew*](https://brew.sh/)

```bash
brew install sourcery
```
If your just tinkering within this download you can just run sourcery from the command line.
```bash
$ sourcery --config sourcery.yml
```

To integrate with your Xcode project, copy the `RunSourcery` script to somewhere in your $PATH. Add an Xcode Behavior to run the script and you're all set.

Create a `Templates` and `Generated` directory in your project and copy the `Runtime.stencil` into the `Templates` directory.

For our example, lets create a very simple type to play with. Since using a `struct` introduces a few wrinkles we use it to illustrate; using `classes` is more straight forward.

```swift
public struct Person {
	public var name: String
}

extension Person: DynamicType {}
```

```bash
$ cd my/project/path; RunSourcery
```
Add the Generated/*.swift to your project. Make sure you don't copy/move them. Otherwise, Xcode won't see any updates when you regenerate.

Try it out.

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

