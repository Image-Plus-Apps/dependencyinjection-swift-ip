# Dependency Injection

![Swift](https://github.com/richard-clements/dependencyinjection-swift/workflows/Swift/badge.svg)

A lightweight, thread-safe dependency injection framework for Swift with native support for Swift's strict concurrency.

## Requirements

- Swift 5.9+
- iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+

## Initialising a Graph

Graphs are built using closure syntax.

```swift
let graph = Graph {
    Dependency(for: SomeProtocol.self) { graph, args in 
        SomeConcrete(dependency: graph.resolve(), argument: args[0] as! Int)
    }
}
```

Dependencies can be declared also in closure syntax with the graph and added arguments as inputs to the closure.
```swift
Dependency(for: SomeProtocol.self) { graph, args in 
    SomeConcrete(dependency: graph.resolve(), argument: args[0] as! Int)
}
```

It's also possible to declare a very simple dependency with an autoclosure. These dependencies can not take an input.
```swift
Dependency(for: SomeProtocol.self, resolver: SomeConcrete())
Dependency(SomeConcrete())
```

## Scopes
There are multiple scopes available.

| Scope | Result |
| :-----: | ------ |
| `new` | Returns a new instance of the dependency each time. |
| `name(Name)` | Matches dependency based on `Name`. Will store the dependency and return this intance, if the name matches when resolving. |
| `singleInstance` | Stores the instance and will return whenever the dependency is resolved, unless there are stricter matches on the name. |

To define a scope, use `withScope`. If no scope is given, then `new` is the default value.

```swift
Dependency(SomeConcrete1()).withScope(.new)
Dependency(SomeConcrete2()).withScope(.named("A Name"))
Dependency(SomeConcrete3()).withScope(.singleInstance)
```

## Injecting

To inject a value outside of graph dependencies, use `@Inject`.

```swift
class SomeClass {
    @Inject(name: "A Name", graph: aGraph, arguments: 1, 2, 3) var value: Int
}
```

All parameters of `@Inject` are optional. If the graph parameter is not passed, the default single value instance will be used.

There are four property wrapper variants:

| Wrapper | Behaviour |
| :-----: | ------ |
| `@Inject` | Resolves immediately on init. |
| `@LazyInject` | Resolves on first access. |
| `@MutableInject` | Like `@Inject` but the value can be reassigned. |
| `@MutableLazyInject` | Like `@LazyInject` but the value can be reassigned. |

## Initialising Default Graph

To initialise the default single value instance graph use `Graph.initialise`. The initialise method uses the same closure style as the `Graph.init` method.

```swift
Graph.initialise {
    Dependency(for: SomeProtocol.self) { graph, args in 
        SomeConcrete(dependency: graph.resolve(), argument: args[0] as! Int)
    }
}
```

To get the single instance of `Graph`, use `Graph.default`.
## Swift Concurrency

This framework is fully compatible with Swift's strict concurrency checking. All core types (`Graph`, `Dependency`, `Scope`) conform to `Sendable`, and static mutable state is protected with locks.

### Nonisolated Dependencies

By default, dependency closures are nonisolated and `@Sendable`. This works for any type that doesn't require actor isolation:

```swift
Graph {
    Dependency { NetworkService() }
    Dependency { UserRepository(api: $0.resolve()!) }
}
```

### @MainActor Dependencies

For types that are `@MainActor`-isolated (view models, coordinators, UIKit wrappers), annotate the closure with `@MainActor`:

```swift
Graph {
    Dependency { @MainActor in HomeViewModel() }
    Dependency { @MainActor in ProfileCoordinator() }
    Dependency { NetworkService() }  // nonisolated, no annotation needed
}
```

The `@MainActor` annotation tells the framework to resolve this dependency on the main thread. If resolution is triggered from a background thread (e.g. a `@LazyInject` accessed after an API callback), the framework will automatically dispatch to the main thread, resolve, and return the value.

For closures that take the `Graph` parameter, use an explicitly typed variable:

```swift
let resolver: @MainActor @Sendable (Graph) -> MyViewModel = { graph in
    MyViewModel(service: graph.resolve()!)
}
Graph {
    Dependency(resolver)
}
```

### Mixing Nonisolated and @MainActor in One Closure

When a nonisolated dependency needs to resolve another dependency that is `@MainActor`-isolated, use `resolveMainActor()`:

```swift
Dependency { graph in
    let version: String = graph.resolve(named: .versionNumber)!         // nonisolated
    let refreshURL: URL = graph.resolve(named: .refreshUrl)!            // nonisolated
    let session: AuthSession = graph.resolveMainActor()!                // hops to main thread
    return BearerAuthenticator(
        authSessionProvider: session,
        refreshUrl: refreshURL,
        version: version
    )
}
```

`resolveMainActor()` is safe to call from any thread. If already on the main thread it runs directly; if on a background thread it dispatches synchronously to main.

All the same variants are available:

```swift
graph.resolveMainActor()                          // by type
graph.resolveMainActor(arguments: 1, "x")         // with arguments
graph.resolveMainActor(named: .someScope)          // by name
graph.resolveMainActor(scope: .myScope, arguments: 1)  // by scope + arguments
```
