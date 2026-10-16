#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

/// Owns a resolved view model on behalf of `@StateObject`, whose autoclosure
/// SwiftUI evaluates once per view identity, so the graph is only asked for an
/// instance once. It never publishes: views observe the `@Observable` view
/// model's own properties.
private final class ResolvedViewModel<T: AnyObject>: ObservableObject {
    let value: T

    init(name: Scope.Name?, graph: Graph) {
        if let name = name {
            value = graph.resolve(scope: name)!
        } else {
            value = graph.resolve()!
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
@MainActor
public struct InjectViewModel<T: Observable & AnyObject>: DynamicProperty {
    @StateObject private var storage: ResolvedViewModel<T>

    public init(name: Scope.Name? = nil, graph: Graph = .default) {
        _storage = StateObject(wrappedValue: ResolvedViewModel(name: name, graph: graph))
    }

    public var wrappedValue: T {
        storage.value
    }

    public var projectedValue: Bindable<T> {
        Bindable(storage.value)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
@MainActor
public struct LazyInjectViewModel<T: Observable & AnyObject>: DynamicProperty {
    @StateObject private var storage: ResolvedViewModel<T>

    public init(name: Scope.Name? = nil, graph: @Sendable @autoclosure () -> Graph = .default) {
        let graph = graph()
        _storage = StateObject(wrappedValue: ResolvedViewModel(name: name, graph: graph))
    }

    public var wrappedValue: T {
        storage.value
    }

    public var projectedValue: Bindable<T> {
        Bindable(storage.value)
    }
}

#endif
