import XCTest

@testable import YFlow

final class StreamTests: XCTestCase {

    func testStreamBasicSendAndListen() async throws {
        let stream = Stream<String>()
        var receivedValues: [String] = []

        let cancellable = stream.listen { value in
            receivedValues.append(value)
        }

        stream.send("Hello")
        stream.send("World")

        // Give some time for async operations
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(receivedValues, ["Hello", "World"])

        cancellable.cancel()
    }

    func testStreamMultipleListeners() async throws {
        let stream = Stream<Int>()
        var listener1Values: [Int] = []
        var listener2Values: [Int] = []

        let cancellable1 = stream.listen { value in
            listener1Values.append(value)
        }

        let cancellable2 = stream.listen { value in
            listener2Values.append(value)
        }

        stream.send(1)
        stream.send(2)

        // Give some time for async operations
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(listener1Values, [1, 2])
        XCTAssertEqual(listener2Values, [1, 2])

        cancellable1.cancel()
        cancellable2.cancel()
    }

    func testStreamNext() async throws {
        let stream = Stream<String>()

        Task {
            try await Task.sleep(for: .milliseconds(100))
            stream.send("First Value")
        }

        let nextValue = await stream.next()
        XCTAssertEqual(nextValue, "First Value")
    }

    func testStreamNextWithTimeout() async throws {
        let stream = Stream<String>()

        do {
            _ = try await stream.next(timeout: .milliseconds(100))
            XCTFail("Should have timed out")
        } catch {
            // Expected timeout error
            XCTAssertTrue(error.localizedDescription.contains("Timeout"))
        }
    }

    func testStreamNextWithPredicate() async throws {
        let stream = Stream<Int>()

        Task {
            try await Task.sleep(for: .milliseconds(50))
            stream.send(1)  // Should be filtered out
            stream.send(2)  // Should match (even number)
        }

        let evenNumber = await stream.next { $0 % 2 == 0 }
        XCTAssertEqual(evenNumber, 2)
    }

    func testStreamCancel() async throws {
        let stream = Stream<String>()
        var receivedValues: [String] = []

        let cancellable = stream.listen { value in
            receivedValues.append(value)
        }

        stream.send("Before Cancel")
        stream.cancel()
        stream.send("After Cancel")  // Should be ignored

        // Give some time for async operations
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(receivedValues, ["Before Cancel"])

        cancellable.cancel()
    }

    func testStreamCancellableAutoCancel() async throws {
        let stream = Stream<String>()
        var receivedValues: [String] = []
        var cancellable: StreamCancellable?

        // Set up listener
        cancellable = stream.listen { value in
            receivedValues.append(value)
        }

        stream.send("Test")

        // Give some time for the message to be processed
        try await Task.sleep(for: .milliseconds(50))

        // Verify we received the message
        XCTAssertEqual(receivedValues, ["Test"])

        // Clear the cancellable (simulating going out of scope)
        cancellable = nil

        // Give some time for deinit to be called
        try await Task.sleep(for: .milliseconds(100))

        stream.send("After Auto Cancel")

        // Give some time for potential async operations
        try await Task.sleep(for: .milliseconds(50))

        // Should still only have the first message since listener was auto-cancelled
        XCTAssertEqual(receivedValues, ["Test"])
    }
}
