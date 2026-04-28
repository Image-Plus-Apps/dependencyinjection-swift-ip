import Foundation

public protocol Item: Sendable {
    
    var scope: Scope { get }
    func resolve<T>(with graph: Graph, arguments: [CVarArg]) -> T?
    func resolves<T>(type: T.Type, with scope: Scope) -> Bool
    
}

public struct Dependency: Item, Sendable {

    let module: AnyModule
    
    private init(module: AnyModule) {
        self.module = module
    }

    public init<T>(for type: T.Type, resolver: @escaping @Sendable (Graph, [CVarArg]) -> T) {
        module = GraphModule(resolver: { (graph: Graph, arguments: [CVarArg]) in
            resolver(graph, arguments)
        }).eraseToAnyDependencyModule()
    }

    public init<T>(for type: T.Type, resolver: @escaping @Sendable (Graph) -> T) {
        module = GraphModule(resolver: { (graph: Graph, arguments: [CVarArg]) in
            resolver(graph)
        }).eraseToAnyDependencyModule()
    }

    public init<T>(for type: T.Type, resolver: @escaping @Sendable () -> T) {
        module = IndependentGraphModule(resolver: resolver).eraseToAnyDependencyModule()
    }

    public init<T>(for type: T.Type, resolver: @autoclosure @escaping @Sendable () -> T) {
        module = IndependentGraphModule(resolver: resolver).eraseToAnyDependencyModule()
    }

    public init<T>(_ resolver: @escaping @Sendable (Graph, [CVarArg]) -> T) {
        module = GraphModule(resolver: { (graph: Graph, arguments: [CVarArg]) in
            resolver(graph, arguments)
        }).eraseToAnyDependencyModule()
    }

    public init<T>(_ resolver: @escaping @Sendable (Graph) -> T) {
        module = GraphModule(resolver: { (graph: Graph, arguments: [CVarArg]) in
            resolver(graph)
        }).eraseToAnyDependencyModule()
    }

    public init<T>(_ resolver: @escaping @Sendable () -> T) {
        module = IndependentGraphModule(resolver: resolver).eraseToAnyDependencyModule()
    }

    public init<T>(_ resolver: @autoclosure @escaping @Sendable () -> T) {
        module = IndependentGraphModule(resolver: resolver).eraseToAnyDependencyModule()
    }
    
    public var scope: Scope {
        return module.scope
    }
    
    public func resolves<T>(type: T.Type, with scope: Scope) -> Bool {
        return module.resolves(type: type, with: scope)
    }

    public func resolve<T>(with graph: Graph, arguments: [CVarArg]) -> T? {
        return module.perform(with: graph, arguments: arguments)
    }
    
    public func withScope(_ scope: Scope) -> Dependency {
        Dependency(module: module.withScope(scope))
    }

}

extension Dependency: PartialGraph {
    
    public var dependencies: [Item] {
        [self]
    }
    
}
