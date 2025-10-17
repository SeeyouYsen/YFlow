import YFlow

// Example usage of Completer and Stream

@main
struct CompleterExample {
    static func main() async {
        print("🚀 Completer Example Started")

        await completerExample()
        await streamExample()

        print("✅ All examples completed!")
    }

    static func completerExample() async {
        print("\n📝 Completer Example:")

        let completer = Completer<String>()

        // Start async operation
        Task {
            try await Task.sleep(for: .seconds(1))
            await completer.complete("Hello from Completer!")
        }

        // Wait for result
        do {
            let result = try await completer.future(timeout: .seconds(2))
            print("Received: \(result)")
        } catch {
            print("Error: \(error)")
        }
    }

    static func streamExample() async {
        print("\n🔄 Stream Example:")

        let stream = Stream<Int>()

        // Add listener
        let cancellable = stream.listen { value in
            print("Stream received: \(value)")
        }

        // Send some values
        stream.send(1)
        stream.send(2)
        stream.send(3)

        // Wait for next even number
        Task {
            let evenNumber = await stream.next { $0 % 2 == 0 }
            print("Next even number: \(evenNumber)")
        }

        // Send more values
        try? await Task.sleep(for: .milliseconds(100))
        stream.send(4)
        stream.send(5)

        // Give some time for processing
        try? await Task.sleep(for: .milliseconds(200))

        cancellable.cancel()
    }
}
