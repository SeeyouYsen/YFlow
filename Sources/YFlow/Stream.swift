//
//  Stream.swift
//  YFlow
//
//  Created by Ysen on 2025/10/17.
//

import Foundation

/// A wrapper class to hold listener closures for stream events
/// Used internally to manage listener references
private class ListenerWrapper<T> {
    /// The listener closure that handles stream values
    let listener: (T) -> Void

    /// Initialize a new listener wrapper
    /// - Parameter listener: The closure to wrap
    init(_ listener: @escaping (T) -> Void) {
        self.listener = listener
    }
}

/// A cancellable object returned when listening to stream events
/// Allows listeners to unsubscribe from the stream
public class StreamCancellable {
    /// The action to perform when cancelling the subscription
    private var cancelAction: (() -> Void)?

    /// Initialize a new cancellable with the given cancel action
    /// - Parameter cancelAction: The closure to execute when cancelling
    init(cancelAction: @escaping () -> Void) {
        self.cancelAction = cancelAction
    }

    /// Cancels the subscription and removes the listener from the stream
    public func cancel() {
        cancelAction?()
        cancelAction = nil
    }

    /// Automatically cancels the subscription when the object is deallocated
    deinit {
        cancel()
    }
}

/// A reactive stream that allows multiple listeners to observe emitted values
/// Thread-safe implementation using concurrent dispatch queues
public class Stream<T> {
    /// Initialize a new empty stream
    public init() {}

    /// Type alias for listener closures that handle stream values
    public typealias Listener = (T) -> Void

    /// Array of registered listeners wrapped in ListenerWrapper objects
    private var listeners: [ListenerWrapper<T>] = []

    /// Concurrent dispatch queue for thread-safe listener management
    private let queue = DispatchQueue(label: "Stream.queue", attributes: .concurrent)

    /// Flag indicating whether the stream has been cancelled
    private var isCancelled: Bool = false

    /// Cleanup when the stream is deallocated
    deinit {
        listeners.removeAll()
    }

    /// Cancels the stream and removes all listeners
    /// Prevents further emissions and listener registrations
    public func cancel() {
        isCancelled = true
        queue.async(flags: .barrier) {
            self.listeners.removeAll()
        }

    }

    /// Emits a value to all registered listeners
    /// - Parameter value: The value to emit to all listeners
    /// - Note: Does nothing if the stream has been cancelled
    public func send(_ value: T) {
        guard !isCancelled else { return }
        let currentListeners = queue.sync {
            return self.listeners
        }

        for wrapper in currentListeners {
            wrapper.listener(value)
        }
    }

    /// Registers a listener to receive stream values
    /// - Parameter listener: The closure to call when values are emitted
    /// - Returns: A StreamCancellable that can be used to unsubscribe the listener
    @discardableResult
    public func listen(_ listener: @escaping Listener) -> StreamCancellable {
        let wrapper = ListenerWrapper(listener)

        queue.sync(flags: .barrier) {
            self.listeners.append(wrapper)
        }

        return StreamCancellable { [weak self] in
            self?.removeListener(wrapper)
        }
    }

    /// Removes a specific listener wrapper from the listeners array
    /// - Parameter wrapper: The listener wrapper to remove
    private func removeListener(_ wrapper: ListenerWrapper<T>) {
        queue.async(flags: .barrier) {
            self.listeners.removeAll { $0 === wrapper }
        }
    }

    /// Waits for the next value emitted by the stream
    /// - Returns: The next value that will be emitted
    /// - Note: This method will suspend until a value is emitted
    public func next() async -> T {
        return await withCheckedContinuation { continuation in
            var cancellable: StreamCancellable?
            cancellable = listen { value in
                continuation.resume(returning: value)
                cancellable?.cancel()
            }
        }
    }

    /// Waits for the next value emitted by the stream with a timeout
    /// - Parameter timeout: Maximum duration to wait for a value
    /// - Returns: The next value that will be emitted
    /// - Throws: Timeout error if no value is emitted within the timeout period
    public func next(timeout: Duration) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            var isResolved = false
            var cancellable: StreamCancellable?
            var timeoutTask: Task<Void, Never>?

            cancellable = listen { value in
                guard !isResolved else { return }
                isResolved = true
                timeoutTask?.cancel()
                continuation.resume(returning: value)
                cancellable?.cancel()
            }

            timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                guard !isResolved else { return }
                isResolved = true
                cancellable?.cancel()
                continuation.resume(
                    throwing: NSError(
                        domain: "Stream", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Timeout"]
                    ))
            }
        }
    }

    /// Waits for the next value that satisfies the given predicate
    /// - Parameter predicate: A closure that takes a value and returns a boolean indicating if it matches
    /// - Returns: The next value that satisfies the predicate
    /// - Note: This method will suspend until a matching value is emitted
    public func next(`where` predicate: @escaping (T) -> Bool) async -> T {
        return await withCheckedContinuation { continuation in
            var cancellable: StreamCancellable?
            cancellable = listen { value in
                if predicate(value) {
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
            }
        }
    }

    /// Waits for the next value that satisfies the given predicate with a timeout
    /// - Parameters:
    ///   - predicate: A closure that takes a value and returns a boolean indicating if it matches
    ///   - timeout: Maximum duration to wait for a matching value
    /// - Returns: The next value that satisfies the predicate
    /// - Throws: Timeout error if no matching value is emitted within the timeout period
    public func next(`where` predicate: @escaping (T) -> Bool, timeout: Duration, ) async throws
        -> T
    {
        return try await withCheckedThrowingContinuation { continuation in
            var isResolved = false
            var cancellable: StreamCancellable?
            var timeoutTask: Task<Void, Never>?

            cancellable = listen { value in
                guard !isResolved else { return }
                if predicate(value) {
                    isResolved = true
                    timeoutTask?.cancel()
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
            }

            timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                guard !isResolved else { return }
                isResolved = true
                cancellable?.cancel()
                continuation.resume(
                    throwing: NSError(
                        domain: "Stream", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Timeout"]
                    ))
            }
        }
    }
}
