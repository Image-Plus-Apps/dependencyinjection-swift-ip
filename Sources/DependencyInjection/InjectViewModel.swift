#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
@MainActor
public final class InjectViewModel<T: Observable & AnyObject>: @unchecked Sendable {
    private var _wrappedValue: T

    public init(name: Scope.Name? = nil, graph: Graph = .default) {
        if let name = name {
            _wrappedValue = graph.resolve(scope: name)!
        } else {
            _wrappedValue = graph.resolve()!
        }
    }

    public var wrappedValue: T {
        _wrappedValue
    }

    public var projectedValue: Bindable<T> {
        Bindable(_wrappedValue)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
@MainActor
public final class LazyInjectViewModel<T: Observable & AnyObject>: @unchecked Sendable {
    private var _wrappedValue: T?
    private let name: Scope.Name?
    private let graphResolver: @Sendable () -> Graph

    public init(name: Scope.Name? = nil, graph: @escaping @Sendable @autoclosure () -> Graph = .default) {
        self.name = name
        self.graphResolver = graph
    }

    public var wrappedValue: T {
        if _wrappedValue == nil {
            if let name = name {
                _wrappedValue = graphResolver().resolve(scope: name)!
            } else {
                _wrappedValue = graphResolver().resolve()!
            }
        }
        return _wrappedValue!
    }

    public var projectedValue: Bindable<T> {
        Bindable(wrappedValue)
    }
}

#endif
