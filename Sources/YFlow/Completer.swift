//
//  Completer.swift
//  YFlow
//
//  Created by Ysen on 2025/10/13.
//

import Foundation

/// A generic actor that provides future-like completion functionality
/// Allows multiple listeners to wait for a single asynchronous result
public actor Completer<T> {
    /// Initialize a new Completer instance
    public init() {}

    /// Type alias for completion handlers that receive either a success value or an error
    public typealias Completion = (Result<T, Error>) -> Void

    /// Type alias for error handling closures
    public typealias OnError = (Error) -> Void

    /// Array of pending completion handlers waiting for the result
    private var completions: [Completion] = []
    /// The completion result - when set, notifies all pending completion handlers
    private var result: Result<T, Error>? {
        didSet { result.map(notify) }
    }

    /// Returns true if the completer has been completed (either with success or failure)
    public var isCompleted: Bool { result != nil }

    /// Cleanup when the completer is deallocated
    /// Notifies all pending completions with an error if the completer was never completed
    deinit {
        if !completions.isEmpty {
            let destroyedError = NSError(
                domain: "Completer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Completer was deallocated before completion"]
            )
            for completion in completions {
                completion(.failure(destroyedError))
            }
        }
        completions.removeAll()
    }

    /// Adds a completion handler to the list of pending completions
    /// If already completed, immediately calls the completion handler with the result
    private func addCompletion(_ completion: @escaping Completion) {
        completions.append(completion)
        result.map(completion)
    }

    /// Completes the future with a successful result
    /// - Parameter result: The value to complete with
    /// - Note: Subsequent calls are ignored and will print a warning
    public func complete(_ result: T) {
        guard self.result == nil else {
            print("⚠️ Future already completed, ignoring subsequent fulfill.")
            return
        }
        self.result = .success(result)
    }

    /// Completes the future with an error
    /// - Parameter error: The error to complete with
    /// - Note: Subsequent calls are ignored and will print a warning
    public func complete(error: Error) {
        guard self.result == nil else {
            print("⚠️ Future already completed, ignoring subsequent error.")
            return
        }
        self.result = .failure(error)
    }

    /// Synchronously completes the future with a successful result
    /// Creates a task to call the async complete method
    /// - Parameter result: The value to complete with
    nonisolated public func completeSync(_ result: T) {
        Task { await complete(result) }
    }

    /// Synchronously completes the future with an error
    /// Creates a task to call the async complete method
    /// - Parameter error: The error to complete with
    nonisolated public func completeSync(error: Error) {
        Task { await complete(error: error) }
    }

    /// Notifies all pending completion handlers with the result and clears the list
    /// - Parameter result: The result to notify all handlers with
    private func notify(_ result: Result<T, Error>) {
        for completion in completions { completion(result) }
        completions.removeAll()
    }

    /// Waits for the completion result with an optional timeout
    /// - Parameter timeout: Optional timeout duration after which a timeout error is thrown
    /// - Returns: The completed value
    /// - Throws: Any error from completion or a timeout error
    public func future(timeout: Duration? = nil) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            var isResolved = false
            var timeoutTask: Task<Void, Never>?

            addCompletion { result in
                guard !isResolved else { return }
                isResolved = true
                timeoutTask?.cancel()
                switch result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }

            if let timeout = timeout {
                timeoutTask = Task {
                    try? await Task.sleep(for: timeout)
                    guard !isResolved else { return }
                    isResolved = true
                    continuation.resume(
                        throwing: NSError(
                            domain: "Future", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Timeout"]
                        ))
                }
            }
        }
    }

    /// Waits for the completion result with error handling and optional timeout
    /// - Parameters:
    ///   - timeout: Optional timeout duration after which the onError handler is called
    ///   - onError: Error handler called when an error occurs or timeout is reached
    /// - Returns: The completed value on success, nil on error or timeout
    public func future(timeout: Duration? = nil, onError: @escaping OnError) async -> T? {
        return await withCheckedContinuation { continuation in
            var isResolved = false
            var timeoutTask: Task<Void, Never>?

            addCompletion { result in
                guard !isResolved else { return }
                isResolved = true
                timeoutTask?.cancel()
                switch result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error):
                    onError(error)
                    continuation.resume(returning: nil)
                }
            }

            if let timeout = timeout {
                timeoutTask = Task {
                    try? await Task.sleep(for: timeout)
                    guard !isResolved else { return }
                    isResolved = true
                    onError(
                        NSError(
                            domain: "Future", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Timeout"]
                        ))
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
