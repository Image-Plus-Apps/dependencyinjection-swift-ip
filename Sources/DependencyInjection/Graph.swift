//
//  File.swift
//  
//
//  Created by Richard Clements on 06/08/2020.
//

import Foundation

/// A simple lock-protected container for use as thread-safe static storage.
private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    
    init(_ value: Value) {
        self.value = value
    }
    
    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

public struct Graph: Sendable {
    
    public let dependencies: [any Item]
    private let identifier = UUID()
    
    init(dependencies: [any Item]) {
        self.dependencies = dependencies
    }
    
    private func resolve<T>(scope: Scope, with arguments: [CVarArg] = []) -> T? {
        guard let dependency = dependencies.first(where: { $0.resolves(type: T.self, with: scope) }) else {
            return nil
        }
        if let value: T = Self.resolve(scope: dependency.scope, for: identifier, arguments: arguments) {
            return value
        }
        guard let value: T = dependency.resolve(with: self, arguments: arguments) else {
            return nil
        }
        Self.store(object: value, with: dependency.scope, forIdentifier: identifier, arguments: arguments)
        return value
    }
    
    func argumentsResolver<T>(with arguments: [CVarArg]) -> T? {
        resolve(scope: .new, with: arguments)
    }
    
    func argumentsResolver<T>(scope: Scope.Name, with arguments: [CVarArg] = []) -> T? {
        Self.resolve(scope: .named(scope), for: identifier, arguments: arguments) ?? resolve(scope: .named(scope), with: arguments)
    }
    
    public func resolve<T>() -> T? {
        resolve(scope: .new, with: [])
    }
    
    public func resolve<T>(arguments: CVarArg...) -> T? {
        resolve(scope: .new, with: arguments)
    }
    
    public func resolve<T>(scope: Scope.Name, arguments: CVarArg...) -> T? {
        Self.resolve(scope: .named(scope), for: identifier, arguments: arguments) ?? resolve(scope: .named(scope), with: arguments)
    }
    
    public func resolve<T>(named name: Scope.Name) -> T? {
        Self.resolve(scope: .named(name), for: identifier, arguments: []) ?? resolve(scope: .named(name), with: [])
    }
    
    // MARK: - @MainActor Resolution
    
    /// Executes the given closure on the main thread with `@MainActor` isolation.
    /// If already on the main thread, runs synchronously.
    /// If on a background thread, dispatches synchronously to main.
    private static func onMainThread<T: Sendable>(_ body: @MainActor @Sendable () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { body() }
        } else {
            return DispatchQueue.main.sync {
                MainActor.assumeIsolated { body() }
            }
        }
    }
    
    /// Resolves a dependency on the main thread, allowing the resolved value
    /// to be a `@MainActor`-isolated type. Safe to call from any thread.
    public func resolveMainActor<T: Sendable>() -> T? {
        Self.onMainThread {
            resolve(scope: .new, with: []) as T?
        }
    }
    
    public func resolveMainActor<T: Sendable>(arguments: CVarArg...) -> T? {
        nonisolated(unsafe) let args = arguments
        return Self.onMainThread {
            resolve(scope: .new, with: args) as T?
        }
    }
    
    public func resolveMainActor<T: Sendable>(scope: Scope.Name, arguments: CVarArg...) -> T? {
        nonisolated(unsafe) let args = arguments
        return Self.onMainThread {
            (Self.resolve(scope: .named(scope), for: identifier, arguments: args) ?? resolve(scope: .named(scope), with: args)) as T?
        }
    }
    
    public func resolveMainActor<T: Sendable>(named name: Scope.Name) -> T? {
        Self.onMainThread {
            (Self.resolve(scope: .named(name), for: identifier, arguments: []) ?? resolve(scope: .named(name), with: [])) as T?
        }
    }
    
}

extension Graph {
    
    private static let _storedDependencies = Locked<[UUID: [String: Any]]>([:])
    
    static func scopeName(for scope: Scope) -> String {
        switch scope {
        case .new:
            return ""
        case .named(let scopeName):
            return "{NamedScope_\(scopeName)}"
        case .singleInstance:
            return "{SingleInstance}"
        }
    }
    
    static func argumentsName(for arguments: [CVarArg]) -> String {
        String(describing: arguments)
    }
    
    static func objectIdentifierName<T>(for type: T.Type, with scope: Scope, arguments: [CVarArg]) -> String {
        return String(describing: T.self) + "_" + scopeName(for: scope) + "_" + argumentsName(for: arguments)
    }
    
    static func resolve<T>(scope: Scope, for identifier: UUID, arguments: [CVarArg]) -> T? {
        guard scope != .new else {
            return nil
        }
        return _storedDependencies.withLock { storedDependencies in
            guard let storedObjects = storedDependencies[identifier] else {
                return nil
            }
            let objectStoreName = objectIdentifierName(for: T.self, with: scope, arguments: arguments)
            return storedObjects[objectStoreName] as? T
        }
    }
    
    static func store<T>(object: T, with scope: Scope, forIdentifier identifier: UUID, arguments: [CVarArg]) {
        guard scope != .new else {
            return
        }
        _storedDependencies.withLock { storedDependencies in
            var storedObjects = storedDependencies[identifier] ?? [:]
            storedObjects[objectIdentifierName(for: T.self, with: scope, arguments: arguments)] = object
            storedDependencies[identifier] = storedObjects
        }
    }
}

public protocol PartialGraph: Sendable {
    var dependencies: [any Item] { get }
}

extension Graph: PartialGraph { }

extension Graph {
    
    public init(@GraphBuilder builder: () -> PartialGraph) {
        self.init(dependencies: builder().dependencies)
    }
    
}

extension Graph {
    
    private static let _default = Locked<Graph>(Graph(dependencies: []))
    
    public static var `default`: Graph {
        get { _default.withLock { $0 } }
        set { _default.withLock { $0 = newValue } }
    }
    
    public static func initialise(@GraphBuilder builder: () -> PartialGraph) {
        self.default = .init(builder: builder)
    }
    
}
