# YFlow

English | [中文](README_CN.md)

A modern Swift asynchronous programming toolkit providing thread-safe `Completer` (Future/Promise) and `Stream` implementations, designed specifically for Swift concurrency.

## 🌟 Features

### Completer (Async Completer)

- ✅ **Thread Safe**: Built on Swift Actor model, ensuring concurrent safety
- ✅ **Type Safe**: Generic support with compile-time type checking
- ✅ **Timeout Support**: Built-in configurable timeout mechanism
- ✅ **Memory Safe**: Automatic lifecycle management, preventing memory leaks
- ✅ **Multiple Awaits**: Support multiple callers waiting for the same result
- ✅ **Error Handling**: Complete error propagation and handling mechanism

### Stream (Async Stream)

- 📡 **Event Streaming**: Support event distribution to multiple listeners
- 🎯 **Type Safe**: Generic support with compile-time type guarantees
- 🚫 **Cancellable**: Support independent listener cancellation and global cancellation
- ⏱️ **Timeout Control**: `next()` method supports timeout mechanism
- 🔍 **Conditional Filtering**: Support condition-based event listening
- 🧵 **Thread Safe**: Uses concurrent queues to ensure data consistency

## 📦 Installation

### Swift Package Manager

Add the dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/SeeyouYsen/YFlow.git", from: "1.0.0")
]
```

Or in Xcode:
1. Select **File** → **Add Package Dependencies...**
2. Enter repository URL: `https://github.com/SeeyouYsen/YFlow.git`
3. Select version range and add to your project

### Platform Requirements

- iOS 16.0+
- macOS 13.0+
- watchOS 9.0+
- tvOS 16.0+

### Manual Installation

Add the `Sources/YFlow/Completer.swift` and `Sources/YFlow/Stream.swift` files to your project.

## 🚀 Quick Start

### Completer Basic Usage

```swift
import Foundation
import YFlow

// Create a Completer
let completer = Completer<String>()

// Wait for result in async task
Task {
    do {
        let result = try await completer.future()
        print("Received result: \(result)")
    } catch {
        print("Error occurred: \(error)")
    }
}

// Complete in another async task
Task {
    try await Task.sleep(for: .seconds(2))
    await completer.complete("Hello, World!")
}
```

### Stream Basic Usage

```swift
import YFlow

// Create a Stream
let stream = Stream<String>()

// Add listener
let cancellable = stream.listen { value in
    print("Received message: \(value)")
}

// Send message
stream.send("Hello, Stream!")

// Cancel listening
cancellable.cancel()
```

## 📖 Detailed Usage Guide

### Completer Usage

#### Waiting with Timeout

```swift
import YFlow

let completer = Completer<Int>()

Task {
    do {
        // Set 5 seconds timeout
        let result = try await completer.future(timeout: .seconds(5))
        print("Result: \(result)")
    } catch {
        print("Timeout or other error: \(error)")
    }
}

// Complete operation
Task {
    try await Task.sleep(for: .seconds(3))
    await completer.complete(42)
}
```

#### Error Handling

```swift
import YFlow

let completer = Completer<Data>()

// Method 1: Handle errors using throws
Task {
    do {
        let data = try await completer.future()
        print("Data length: \(data.count)")
    } catch {
        print("Failed to get data: \(error)")
    }
}

// Method 2: Handle errors using callback
Task {
    let data = await completer.future { error in
        print("Error callback: \(error)")
    }
    if let data = data {
        print("Data length: \(data.count)")
    }
}

// Complete with error
Task {
    try await Task.sleep(for: .seconds(1))
    await completer.complete(error: URLError(.networkConnectionLost))
}
```

#### Multiple Awaits for Same Result

```swift
import YFlow

let completer = Completer<String>()

// Multiple tasks can wait for the same result simultaneously
Task {
    let result1 = try? await completer.future()
    print("Task 1 received: \(result1 ?? "nil")")
}

Task {
    let result2 = try? await completer.future()
    print("Task 2 received: \(result2 ?? "nil")")
}

// Only need to complete once
Task {
    try await Task.sleep(for: .seconds(2))
    await completer.complete("Shared result")
}
```

### Stream Usage

#### Multiple Listeners

```swift
import YFlow

let stream = Stream<String>()

// Add multiple listeners
let cancellable1 = stream.listen { value in
    print("Listener 1: \(value)")
}

let cancellable2 = stream.listen { value in
    print("Listener 2: \(value)")
}

// Send message (all listeners will receive)
stream.send("Broadcast message")

// Cancel independently
cancellable1.cancel()
stream.send("Only listener 2 can receive this")
```

#### Waiting for Next Value

```swift
import YFlow

let stream = Stream<Int>()

// Method 1: Wait without timeout
Task {
    let nextValue = await stream.next()
    print("Next value: \(nextValue)")
}

// Method 2: Wait with timeout
Task {
    do {
        let nextValue = try await stream.next(timeout: .seconds(5))
        print("Next value: \(nextValue)")
    } catch {
        print("Wait timeout")
    }
}

// Send value
Task {
    try await Task.sleep(for: .seconds(1))
    stream.send(42)
}
```

#### Conditional Filtering

```swift
import YFlow

let stream = Stream<Int>()

// Wait for even number
Task {
    let evenNumber = await stream.next { $0 % 2 == 0 }
    print("Received even number: \(evenNumber)")
}

// Conditional wait with timeout
Task {
    do {
        let largeNumber = try await stream.next(
            where: { $0 > 100 },
            timeout: .seconds(10)
        )
        print("Received large number: \(largeNumber)")
    } catch {
        print("Wait timeout")
    }
}

// Send multiple values
stream.send(1)   // Filtered out
stream.send(4)   // Matches even condition
stream.send(150) // Matches large number condition
```

#### Global Cancellation

```swift
import YFlow

let stream = Stream<String>()

let cancellable1 = stream.listen { print("Listener 1: \($0)") }
let cancellable2 = stream.listen { print("Listener 2: \($0)") }

// Cancel entire Stream
stream.cancel()

// Subsequent sends will be ignored
stream.send("This message won't be processed")
```

## 🎯 Real-world Use Cases

### 1. Network Request Wrapper

```swift
import YFlow

class APIService {
    func fetchUser(id: String) -> Completer<User> {
        let completer = Completer<User>()

        Task {
            do {
                let user = try await URLSession.shared.data(from: URL(string: "api/users/\(id)")!)
                let userData = try JSONDecoder().decode(User.self, from: user.0)
                await completer.complete(userData)
            } catch {
                await completer.complete(error: error)
            }
        }

        return completer
    }
}

// Usage
let apiService = APIService()
let userCompleter = apiService.fetchUser(id: "123")
let user = try await userCompleter.future(timeout: .seconds(10))
```

### 2. Real-time Data Stream

```swift
import YFlow
import CoreLocation

class LocationStream {
    private let locationStream = Stream<CLLocation>()
    private let locationManager = CLLocationManager()

    func startLocationUpdates() -> Stream<CLLocation> {
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        return locationStream
    }

    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locations.forEach { locationStream.send($0) }
    }
}

// Usage
let locationService = LocationStream()
let stream = locationService.startLocationUpdates()

let cancellable = stream.listen { location in
    print("New location: \(location.coordinate)")
}

// Wait for location meeting conditions
let preciseLocation = try await stream.next(
    where: { $0.horizontalAccuracy < 10 },
    timeout: .seconds(30)
)
```

### 3. User Interface Events

```swift
import YFlow
import UIKit

class ButtonEventStream {
    private let tapStream = Stream<Void>()

    @IBAction func buttonTapped(_ sender: UIButton) {
        tapStream.send(())
    }

    func onTap() -> Stream<Void> {
        return tapStream
    }
}

// Usage
let buttonStream = ButtonEventStream()
let stream = buttonStream.onTap()

// Listen for consecutive taps
let cancellable = stream.listen {
    print("Button was tapped")
}

// Wait for user confirmation
Task {
    await stream.next() // Wait for user tap
    print("User confirmed the operation")
}
```

## 📚 API Reference

### Completer

#### Initialization

```swift
public init()
```

#### Properties

```swift
public var isCompleted: Bool { get }
```

#### Methods

```swift
public func complete(_ result: T)
public func complete(error: Error)
public func completeSync(_ result: T)
public func completeSync(error: Error)
public func future(timeout: Duration? = nil) async throws -> T
public func future(timeout: Duration? = nil, onError: @escaping OnError) async -> T?
```

### Stream

#### Initialization

```swift
public init()
```

#### Methods

```swift
public func send(_ value: T)
public func listen(_ listener: @escaping Listener) -> StreamCancellable
public func cancel()
public func next() async -> T
public func next(timeout: Duration) async throws -> T
public func next(where predicate: @escaping (T) -> Bool) async -> T
public func next(where predicate: @escaping (T) -> Bool, timeout: Duration) async throws -> T
```

### StreamCancellable

#### Methods

```swift
public func cancel()
```

## 🛡️ Thread Safety Guarantees

### Completer

- Built on Swift Actor, naturally thread-safe
- Methods can be called from any thread
- Internal state automatically synchronized, no manual locking required

### Stream

- Uses concurrent queues (`DispatchQueue.concurrent`) to ensure thread safety
- Read operations execute concurrently, write operations use barrier for exclusivity
- Listener callbacks execute outside locks to avoid deadlocks

## ⚠️ Important Notes

1. **One-time Completion**: Each Completer can only be completed once, subsequent calls are ignored
2. **Memory Management**: StreamCancellable automatically cancels in deinit, but manual cancel() is recommended
3. **Error Handling**: Recommend using `do-catch` or error callbacks to handle potential errors
4. **Timeout Settings**: Set reasonable timeout for long-running operations
5. **Stream Cancellation**: After calling `stream.cancel()`, all subsequent operations are ignored

## 🧪 Unit Tests

The project includes comprehensive unit tests ensuring functionality correctness and stability. Run tests:

```bash
swift test
```

## 💡 Example Application

The project includes a complete SwiftUI example application demonstrating various uses of Completer and Stream.

## 🤝 Contributing

Issues and Pull Requests are welcome!

## 📄 License

This project is open source under the MIT License. See [LICENSE](LICENSE) file for details.

---

**Author**: SeeyouYsen  
**Created**: October 13, 2025  
**Need Help?** If you encounter problems or have suggestions, feel free to submit an Issue!