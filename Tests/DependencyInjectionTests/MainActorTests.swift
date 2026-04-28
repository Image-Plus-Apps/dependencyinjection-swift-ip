//
//  MainActorTests.swift
//
//
//  Created by Claude on 2026-04-28.
//

import XCTest
@testable import DependencyInjection

@MainActor
final class MainActorTests: XCTestCase {

    @MainActor
    final class MockViewModel: Sendable {
        let value: Int
        init(value: Int = 42) {
            self.value = value
        }
    }

    // MARK: - Basic Resolution

    func testResolveMainActorClass() {
        let graph = Graph {
            Dependency { @MainActor in MockViewModel() }
        }
        let vm: MockViewModel? = graph.resolve()
        XCTAssertNotNil(vm)
        XCTAssertEqual(vm?.value, 42)
    }

    func testResolveMainActorClassWithGraphClosure() {
        let resolver: @MainActor @Sendable (Graph) -> MockViewModel = { _ in MockViewModel(value: 7) }
        let graph = Graph {
            Dependency(resolver)
        }
        let vm: MockViewModel? = graph.resolve()
        XCTAssertNotNil(vm)
        XCTAssertEqual(vm?.value, 7)
    }

    func testResolveMainActorClassWithArguments() {
        let resolver: @MainActor @Sendable (Graph, [CVarArg]) -> MockViewModel = { _, args in
            MockViewModel(value: args[0] as! Int)
        }
        let graph = Graph {
            Dependency(resolver)
        }
        let vm: MockViewModel? = graph.resolve(arguments: 99)
        XCTAssertNotNil(vm)
        XCTAssertEqual(vm?.value, 99)
    }

    func testResolveMainActorClassForType() {
        let graph = Graph {
            Dependency(for: MockViewModel.self, resolver: { @MainActor in MockViewModel(value: 10) })
        }
        let vm: MockViewModel? = graph.resolve()
        XCTAssertNotNil(vm)
        XCTAssertEqual(vm?.value, 10)
    }

    // MARK: - Scoping

    func testResolveMainActorSingleInstance() {
        let graph = Graph {
            Dependency { @MainActor in MockViewModel() }
                .withScope(.singleInstance)
        }
        let vm1: MockViewModel? = graph.resolve()
        let vm2: MockViewModel? = graph.resolve()
        XCTAssertTrue(vm1 === vm2)
    }

    func testResolveMainActorNew() {
        let graph = Graph {
            Dependency { @MainActor in MockViewModel() }
                .withScope(.new)
        }
        let vm1: MockViewModel? = graph.resolve()
        let vm2: MockViewModel? = graph.resolve()
        XCTAssertNotNil(vm1)
        XCTAssertNotNil(vm2)
        XCTAssertFalse(vm1 === vm2)
    }

    func testResolveMainActorNamed() {
        let graph = Graph {
            Dependency { @MainActor in MockViewModel(value: 1) }
                .withScope(.named("vm1"))
            Dependency { @MainActor in MockViewModel(value: 2) }
                .withScope(.named("vm2"))
        }
        let vm1: MockViewModel? = graph.resolve(named: "vm1")
        let vm2: MockViewModel? = graph.resolve(named: "vm2")
        XCTAssertEqual(vm1?.value, 1)
        XCTAssertEqual(vm2?.value, 2)
    }

    // MARK: - Property Wrappers

    func testInjectMainActor() {
        struct Container {
            @Inject var vm: MockViewModel
        }
        let graph = Graph {
            Dependency { @MainActor in MockViewModel(value: 55) }
        }
        Graph.default = graph
        let container = Container()
        XCTAssertEqual(container.vm.value, 55)
    }

    func testLazyInjectMainActor() {
        struct Container {
            @LazyInject var vm: MockViewModel
        }
        nonisolated(unsafe) var resolved = false
        let graph = Graph {
            Dependency { @MainActor () -> MockViewModel in
                resolved = true
                return MockViewModel(value: 77)
            }
        }
        Graph.default = graph
        let container = Container()
        XCTAssertFalse(resolved)
        XCTAssertEqual(container.vm.value, 77)
        XCTAssertTrue(resolved)
    }

    func testMutableInjectMainActor() {
        struct Container {
            @MutableInject var vm: MockViewModel
        }
        let graph = Graph {
            Dependency { @MainActor in MockViewModel(value: 33) }
        }
        Graph.default = graph
        let container = Container()
        XCTAssertEqual(container.vm.value, 33)
    }

    func testMutableLazyInjectMainActor() {
        struct Container {
            @MutableLazyInject var vm: MockViewModel
        }
        nonisolated(unsafe) var resolved = false
        let graph = Graph {
            Dependency { @MainActor () -> MockViewModel in
                resolved = true
                return MockViewModel(value: 88)
            }
        }
        Graph.default = graph
        let container = Container()
        XCTAssertFalse(resolved)
        XCTAssertEqual(container.vm.value, 88)
        XCTAssertTrue(resolved)
    }
}
