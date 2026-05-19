#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
@MainActor
public struct InjectViewModel<T: Observable & AnyObject>: DynamicProperty {
    @State private var value: T

    public init(name: Scope.Name? = nil, graph: Graph = .default) {
        let resolved: T
        if let name = name {
            resolved = graph.resolve(scope: name)!
        } else {
            resolved = graph.resolve()!
        }
        _value = State(initialValue: resolved)
    }

    public var wrappedValue: T {
        value
    }

    public var projectedValue: Bindable<T> {
        Bindable(value)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
@MainActor
public struct LazyInjectViewModel<T: Observable & AnyObject>: DynamicProperty {
    @State private var value: T

    public init(name: Scope.Name? = nil, graph: @Sendable @autoclosure () -> Graph = .default) {
        let resolved: T
        if let name = name {
            resolved = graph().resolve(scope: name)!
        } else {
            resolved = graph().resolve()!
        }
        _value = State(initialValue: resolved)
    }

    public var wrappedValue: T {
        value
    }

    public var projectedValue: Bindable<T> {
        Bindable(value)
    }
}

#endif
