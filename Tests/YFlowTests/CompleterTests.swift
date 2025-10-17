import XCTest

@testable import YFlow

final class CompleterTests: XCTestCase {

    func testCompleterBasicCompletion() async throws {
        let completer = Completer<String>()

        Task {
            try await Task.sleep(for: .milliseconds(100))
            await completer.complete("Test Result")
        }

        let result = try await completer.future()
        XCTAssertEqual(result, "Test Result")
    }

    func testCompleterTimeout() async throws {
        let completer = Completer<String>()

        do {
            _ = try await completer.future(timeout: .milliseconds(100))
            XCTFail("Should have timed out")
        } catch {
            // Expected timeout error
            XCTAssertTrue(error.localizedDescription.contains("Timeout"))
        }
    }

    func testCompleterMultipleWaiters() async throws {
        let completer = Completer<Int>()

        let task1 = Task {
            try await completer.future()
        }

        let task2 = Task {
            try await completer.future()
        }

        // Complete after a delay
        Task {
            try await Task.sleep(for: .milliseconds(50))
            await completer.complete(42)
        }

        let result1 = try await task1.value
        let result2 = try await task2.value

        XCTAssertEqual(result1, 42)
        XCTAssertEqual(result2, 42)
    }

    func testCompleterIsCompleted() async throws {
        let completer = Completer<String>()

        let isCompletedBefore = await completer.isCompleted
        XCTAssertFalse(isCompletedBefore)

        await completer.complete("Done")

        let isCompletedAfter = await completer.isCompleted
        XCTAssertTrue(isCompletedAfter)
    }

    func testCompleterErrorCompletion() async throws {
        let completer = Completer<String>()

        struct TestError: Error, Equatable {
            let message: String
        }

        Task {
            try await Task.sleep(for: .milliseconds(50))
            await completer.complete(error: TestError(message: "Test Error"))
        }

        do {
            _ = try await completer.future()
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error.message, "Test Error")
        }
    }
}
