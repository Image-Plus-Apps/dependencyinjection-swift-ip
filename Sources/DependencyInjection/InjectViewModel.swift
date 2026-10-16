#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

/// Resolves a view model from the graph on first read. Creating one resolves
/// nothing, so a holder per view re-creation is cheap. `@State` keeps the
/// holder from the view's first installation, so the graph is asked once per
/// view identity. Before installation, reads go to the view's own holder, so
/// an instance configured then is the one SwiftUI keeps.
@MainActor
private final class ResolvedViewModel<T: AnyObject> {
    private let name: Scope.Name?
    private let graph: Graph

    private(set) lazy var value: T = resolve()

    init(name: Scope.Name?, graph: Graph) {
        self.name = name
        self.graph = graph
    }

    private func resolve() -> T {
        if let name = name {
            return graph.resolve(scope: name)!
        } else {
            return graph.resolve()!
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@propertyWrapper
@MainActor
public struct InjectViewModel<T: Observable & AnyObject>: DynamicProperty {
    @State private var storage: ResolvedViewModel<T>

    public init(name: Scope.Name? = nil, graph: Graph = .default) {
        _storage = State(initialValue: ResolvedViewModel(name: name, graph: graph))
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
    @State private var storage: ResolvedViewModel<T>

    public init(name: Scope.Name? = nil, graph: @Sendable @autoclosure () -> Graph = .default) {
        let graph = graph()
        _storage = State(initialValue: ResolvedViewModel(name: name, graph: graph))
    }

    public var wrappedValue: T {
        storage.value
    }

    public var projectedValue: Bindable<T> {
        Bindable(storage.value)
    }
}

#endif
