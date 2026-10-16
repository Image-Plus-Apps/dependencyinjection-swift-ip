//
//  InjectViewModelTests.swift
//
//
//  Created by Claude on 2026-10-16.
//

#if canImport(SwiftUI) && canImport(AppKit) && canImport(Observation)
import XCTest
import SwiftUI
import AppKit
import Observation
@testable import DependencyInjection

/// Hosts real SwiftUI views so the wrappers run under SwiftUI's own
/// view-identity and dynamic-property machinery.
@available(macOS 14.0, *)
@MainActor
final class InjectViewModelTests: XCTestCase {

    @MainActor @Observable
    final class ViewModel {
        var text = ""
    }

    /// Counts how many times the graph builds a `ViewModel`.
    @MainActor
    final class Factory {
        var resolveCount = 0
    }

    /// Records what the child view saw on each init and body evaluation.
    @MainActor
    final class Log {
        var childInits = 0
        var bodyInstances: [ObjectIdentifier] = []
    }

    /// Changing `tick` re-evaluates the parent's body, which re-creates the
    /// child view struct. Changing `identity` gives the child a new identity.
    @MainActor @Observable
    final class ParentState {
        var tick = 0
        var identity = 0
    }

    struct Parent<Child: View>: View {
        let state: ParentState
        let makeChild: () -> Child

        var body: some View {
            let _ = state.tick
            makeChild().id(state.identity)
        }
    }

    struct InjectChild: View {
        @InjectViewModel var viewModel: ViewModel
        let log: Log

        init(log: Log) {
            self.log = log
            log.childInits += 1
        }

        var body: some View {
            probe(viewModel, $viewModel.text, log)
        }
    }

    struct LazyInjectChild: View {
        @LazyInjectViewModel var viewModel: ViewModel
        let log: Log

        init(log: Log) {
            self.log = log
            log.childInits += 1
        }

        var body: some View {
            probe(viewModel, $viewModel.text, log)
        }
    }

    struct NamedInjectChild: View {
        @InjectViewModel(name: "shared") var viewModel: ViewModel
        let log: Log

        init(log: Log) {
            self.log = log
            log.childInits += 1
        }

        var body: some View {
            probe(viewModel, $viewModel.text, log)
        }
    }

    struct NamedLazyInjectChild: View {
        @LazyInjectViewModel(name: "shared") var viewModel: ViewModel
        let log: Log

        init(log: Log) {
            self.log = log
            log.childInits += 1
        }

        var body: some View {
            probe(viewModel, $viewModel.text, log)
        }
    }

    /// Assigns the wrapper in its own init. The declaration still gets an
    /// implicit `InjectViewModel()` default, so it must not resolve either.
    struct ExplicitGraphInjectChild: View {
        @InjectViewModel var viewModel: ViewModel
        let log: Log

        init(graph: Graph, log: Log) {
            _viewModel = InjectViewModel(graph: graph)
            self.log = log
            log.childInits += 1
        }

        var body: some View {
            probe(viewModel, $viewModel.text, log)
        }
    }

    // MARK: - Helpers

    private static func probe(_ viewModel: ViewModel, _ text: Binding<String>, _ log: Log) -> some View {
        log.bodyInstances.append(ObjectIdentifier(viewModel))
        return TextField("", text: text)
    }

    private func makeGraph(scope: Scope, factory: Factory) -> Graph {
        Graph {
            Dependency { @MainActor () -> ViewModel in
                factory.resolveCount += 1
                return ViewModel()
            }
            .withScope(scope)
        }
    }

    private func useDefaultGraph(_ graph: Graph) {
        let previous = Graph.default
        Graph.default = graph
        addTeardownBlock { Graph.default = previous }
    }

    private func host<Child: View>(_ state: ParentState, log: Log, _ makeChild: @escaping () -> Child) {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: Parent(state: state, makeChild: makeChild))
        addTeardownBlock { window.close() }
        waitUntil { !log.bodyInstances.isEmpty }
    }

    /// Re-evaluates the parent's body, re-creating the child view struct.
    private func rerenderParent(_ state: ParentState, log: Log, times: Int) {
        for _ in 0..<times {
            let inits = log.childInits
            state.tick += 1
            waitUntil { log.childInits > inits }
        }
    }

    /// Gives the child view a new identity.
    private func changeIdentity(_ state: ParentState, log: Log) {
        let bodies = log.bodyInstances.count
        state.identity += 1
        waitUntil { log.bodyInstances.count > bodies }
    }

    /// Spins the run loop until SwiftUI has applied the pending update.
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date(timeIntervalSinceNow: 2)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertTrue(condition(), "SwiftUI did not apply the update in time", file: file, line: line)
    }

    // MARK: - Unscoped registrations

    func testInjectViewModel_resolvesOncePerViewIdentity() {
        let factory = Factory()
        useDefaultGraph(makeGraph(scope: .new, factory: factory))
        let log = Log()
        let state = ParentState()
        host(state, log: log) { InjectChild(log: log) }

        rerenderParent(state, log: log, times: 3)

        XCTAssertGreaterThanOrEqual(log.childInits, 4, "Child view struct should have been re-created")
        XCTAssertEqual(factory.resolveCount, 1)
        XCTAssertEqual(Set(log.bodyInstances).count, 1)
    }

    func testLazyInjectViewModel_resolvesOncePerViewIdentity() {
        let factory = Factory()
        useDefaultGraph(makeGraph(scope: .new, factory: factory))
        let log = Log()
        let state = ParentState()
        host(state, log: log) { LazyInjectChild(log: log) }

        rerenderParent(state, log: log, times: 3)

        XCTAssertGreaterThanOrEqual(log.childInits, 4, "Child view struct should have been re-created")
        XCTAssertEqual(factory.resolveCount, 1)
        XCTAssertEqual(Set(log.bodyInstances).count, 1)
    }

    func testInjectViewModel_assignedInInit_resolvesOncePerViewIdentity() {
        let factory = Factory()
        let graph = makeGraph(scope: .new, factory: factory)
        useDefaultGraph(makeGraph(scope: .new, factory: factory))
        let log = Log()
        let state = ParentState()
        host(state, log: log) { ExplicitGraphInjectChild(graph: graph, log: log) }

        rerenderParent(state, log: log, times: 3)

        XCTAssertGreaterThanOrEqual(log.childInits, 4, "Child view struct should have been re-created")
        XCTAssertEqual(factory.resolveCount, 1)
        XCTAssertEqual(Set(log.bodyInstances).count, 1)
    }

    // MARK: - New view identity

    func testInjectViewModel_newViewIdentityGetsFreshInstance() {
        let factory = Factory()
        useDefaultGraph(makeGraph(scope: .new, factory: factory))
        let log = Log()
        let state = ParentState()
        host(state, log: log) { InjectChild(log: log) }
        let first = log.bodyInstances.last

        changeIdentity(state, log: log)

        XCTAssertEqual(factory.resolveCount, 2)
        XCTAssertNotNil(log.bodyInstances.last)
        XCTAssertNotEqual(log.bodyInstances.last, first)
    }

    func testLazyInjectViewModel_newViewIdentityGetsFreshInstance() {
        let factory = Factory()
        useDefaultGraph(makeGraph(scope: .new, factory: factory))
        let log = Log()
        let state = ParentState()
        host(state, log: log) { LazyInjectChild(log: log) }
        let first = log.bodyInstances.last

        changeIdentity(state, log: log)

        XCTAssertEqual(factory.resolveCount, 2)
        XCTAssertNotNil(log.bodyInstances.last)
        XCTAssertNotEqual(log.bodyInstances.last, first)
    }

    // MARK: - Scoped registrations

    func testInjectViewModel_singleInstanceIsSharedAcrossViewIdentities() {
        let factory = Factory()
        let graph = makeGraph(scope: .singleInstance, factory: factory)
        useDefaultGraph(graph)
        let log = Log()
        let state = ParentState()
        host(state, log: log) { InjectChild(log: log) }

        changeIdentity(state, log: log)
        rerenderParent(state, log: log, times: 2)

        XCTAssertEqual(factory.resolveCount, 1)
        XCTAssertEqual(Set(log.bodyInstances).count, 1)
        let shared: ViewModel? = graph.resolve()
        XCTAssertEqual(log.bodyInstances.last, shared.map(ObjectIdentifier.init))
    }

    func testLazyInjectViewModel_singleInstanceIsSharedAcrossViewIdentities() {
        let factory = Factory()
        let graph = makeGraph(scope: .singleInstance, factory: factory)
        useDefaultGraph(graph)
        let log = Log()
        let state = ParentState()
        host(state, log: log) { LazyInjectChild(log: log) }

        changeIdentity(state, log: log)
        rerenderParent(state, log: log, times: 2)

        XCTAssertEqual(factory.resolveCount, 1)
        XCTAssertEqual(Set(log.bodyInstances).count, 1)
        let shared: ViewModel? = graph.resolve()
        XCTAssertEqual(log.bodyInstances.last, shared.map(ObjectIdentifier.init))
    }

    func testInjectViewModel_namedScopeIsSharedAcrossViewIdentities() {
        let factory = Factory()
        useDefaultGraph(makeGraph(scope: .named("shared"), factory: factory))
        let log = Log()
        let state = ParentState()
        host(state, log: log) { NamedInjectChild(log: log) }

        changeIdentity(state, log: log)

        XCTAssertEqual(factory.resolveCount, 1)
        XCTAssertEqual(Set(log.bodyInstances).count, 1)
    }

    func testLazyInjectViewModel_namedScopeIsSharedAcrossViewIdentities() {
        let factory = Factory()
        useDefaultGraph(makeGraph(scope: .named("shared"), factory: factory))
        let log = Log()
        let state = ParentState()
        host(state, log: log) { NamedLazyInjectChild(log: log) }

        changeIdentity(state, log: log)

        XCTAssertEqual(factory.resolveCount, 1)
        XCTAssertEqual(Set(log.bodyInstances).count, 1)
    }
}
#endif
