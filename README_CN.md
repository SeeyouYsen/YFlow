# YFlow

[English](README.md) | 中文

一个现代化的 Swift 异步编程工具库，提供线程安全的 `Completer`（Future/Promise）和 `Stream` 实现，专为 Swift 并发设计。

## 🌟 特性

### Completer（异步完成器）

- ✅ **线程安全**：基于 Swift Actor 模型，确保并发安全
- ✅ **类型安全**：支持泛型，编译时类型检查
- ✅ **超时支持**：内置可配置的超时机制
- ✅ **内存安全**：自动管理生命周期，避免内存泄漏
- ✅ **多次等待**：支持多个调用者同时等待同一结果
- ✅ **错误处理**：完整的错误传播和处理机制

### Stream（异步流）

- � **事件流**：支持多个监听器的事件分发
- 🎯 **类型安全**：泛型支持，编译时类型保证
- 🚫 **可取消**：支持监听器的独立取消和全局取消
- ⏱️ **超时控制**：`next()` 方法支持超时机制
- 🔍 **条件过滤**：支持基于条件的事件监听
- 🧵 **线程安全**：使用并发队列确保数据一致性

## 📦 安装

### Swift Package Manager

在你的 `Package.swift` 文件中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/SeeyouYsen/YFlow.git", from: "0.0.1")
]
```

或者在 Xcode 中：
1. 选择 **File** → **Add Package Dependencies...**
2. 输入仓库 URL：`https://github.com/SeeyouYsen/YFlow.git`
3. 选择版本范围并添加到你的项目

### 平台要求

- iOS 16.0+
- macOS 13.0+
- watchOS 9.0+
- tvOS 16.0+

### 手动安装

将 `Sources/YFlow/Completer.swift` 文件添加到你的项目中即可。

## 🚀 快速开始

### Completer 基本用法

```swift
import Foundation
import YFlow

// 创建一个 Completer
let completer = Completer<String>()

// 在异步任务中等待结果
Task {
    do {
        let result = try await completer.future()
        print("收到结果: \(result)")
    } catch {
        print("发生错误: \(error)")
    }
}

// 在另一个异步任务中完成
Task {
    try await Task.sleep(for: .seconds(2))
    await completer.complete("Hello, World!")
}
```

### Stream 基本用法

```swift
import YFlow

// 创建一个 Stream
let stream = Stream<String>()

// 添加监听器
let cancellable = stream.listen { value in
    print("收到消息: \(value)")
}

// 发送消息
stream.send("Hello, Stream!")

// 取消监听
cancellable.cancel()
```

## 📖 详细使用指南

### Completer 使用

#### 带超时的等待

```swift
import YFlow

let completer = Completer<Int>()

Task {
    do {
        // 设置 5 秒超时
        let result = try await completer.future(timeout: .seconds(5))
        print("结果: \(result)")
    } catch {
        print("超时或其他错误: \(error)")
    }
}

// 完成操作
Task {
    try await Task.sleep(for: .seconds(3))
    await completer.complete(42)
}
```

#### 错误处理

```swift
import YFlow

let completer = Completer<Data>()

// 方式1：使用 throws 处理错误
Task {
    do {
        let data = try await completer.future()
        print("数据长度: \(data.count)")
    } catch {
        print("获取数据失败: \(error)")
    }
}

// 方式2：使用回调处理错误
Task {
    let data = await completer.future { error in
        print("错误回调: \(error)")
    }
    if let data = data {
        print("数据长度: \(data.count)")
    }
}

// 以错误完成
Task {
    try await Task.sleep(for: .seconds(1))
    await completer.complete(error: URLError(.networkConnectionLost))
}
```

#### 多次等待同一结果

```swift
import YFlow

let completer = Completer<String>()

// 多个任务可以同时等待同一个结果
Task {
    let result1 = try? await completer.future()
    print("任务1收到: \(result1 ?? "nil")")
}

Task {
    let result2 = try? await completer.future()
    print("任务2收到: \(result2 ?? "nil")")
}

// 只需要完成一次
Task {
    try await Task.sleep(for: .seconds(2))
    await completer.complete("共享结果")
}
```

### Stream 使用

#### 多监听器

```swift
import YFlow

let stream = Stream<String>()

// 添加多个监听器
let cancellable1 = stream.listen { value in
    print("监听器1: \(value)")
}

let cancellable2 = stream.listen { value in
    print("监听器2: \(value)")
}

// 发送消息（所有监听器都会收到）
stream.send("广播消息")

// 独立取消
cancellable1.cancel()
stream.send("只有监听器2能收到")
```

#### 等待下一个值

```swift
import YFlow

let stream = Stream<Int>()

// 方式1：无超时等待
Task {
    let nextValue = await stream.next()
    print("下一个值: \(nextValue)")
}

// 方式2：带超时等待
Task {
    do {
        let nextValue = try await stream.next(timeout: .seconds(5))
        print("下一个值: \(nextValue)")
    } catch {
        print("等待超时")
    }
}

// 发送值
Task {
    try await Task.sleep(for: .seconds(1))
    stream.send(42)
}
```

#### 条件过滤

```swift
import YFlow

let stream = Stream<Int>()

// 等待偶数
Task {
    let evenNumber = await stream.next { $0 % 2 == 0 }
    print("收到偶数: \(evenNumber)")
}

// 带超时的条件等待
Task {
    do {
        let largeNumber = try await stream.next(
            where: { $0 > 100 },
            timeout: .seconds(10)
        )
        print("收到大数: \(largeNumber)")
    } catch {
        print("等待超时")
    }
}

// 发送多个值
stream.send(1)  // 被过滤
stream.send(4)  // 匹配偶数条件
stream.send(150) // 匹配大数条件
```

#### 全局取消

```swift
import YFlow

let stream = Stream<String>()

let cancellable1 = stream.listen { print("监听器1: \($0)") }
let cancellable2 = stream.listen { print("监听器2: \($0)") }

// 取消整个 Stream
stream.cancel()

// 之后的发送将被忽略
stream.send("这条消息不会被处理")
```

## 🎯 实际应用场景

### 1. 网络请求封装

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

// 使用
let apiService = APIService()
let userCompleter = apiService.fetchUser(id: "123")
let user = try await userCompleter.future(timeout: .seconds(10))
```

### 2. 实时数据流

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

// 使用
let locationService = LocationStream()
let stream = locationService.startLocationUpdates()

let cancellable = stream.listen { location in
    print("新位置: \(location.coordinate)")
}

// 等待满足条件的位置
let preciseLocation = try await stream.next(
    where: { $0.horizontalAccuracy < 10 },
    timeout: .seconds(30)
)
```

### 3. 用户界面事件

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

// 使用
let buttonStream = ButtonEventStream()
let stream = buttonStream.onTap()

// 监听连续点击
let cancellable = stream.listen {
    print("按钮被点击")
}

// 等待用户确认
Task {
    await stream.next() // 等待用户点击
    print("用户确认了操作")
}
```

## 📚 API 参考

### Completer

#### 初始化

```swift
public init()
```

#### 属性

```swift
public var isCompleted: Bool { get }
```

#### 方法

```swift
public func complete(_ result: T)
public func complete(error: Error)
public func completeSync(_ result: T)
public func completeSync(error: Error)
public func future(timeout: Duration? = nil) async throws -> T
public func future(timeout: Duration? = nil, onError: @escaping OnError) async -> T?
```

### Stream

#### 初始化

```swift
public init()
```

#### 方法

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

#### 方法

```swift
public func cancel()
```

## 🛡️ 线程安全保证

### Completer

- 基于 Swift Actor 实现，天然线程安全
- 可以在任何线程中调用方法
- 内部状态自动同步，无需手动加锁

### Stream

- 使用并发队列（`DispatchQueue.concurrent`）确保线程安全
- 读操作并发执行，写操作使用 barrier 独占
- 监听器回调在锁外执行，避免死锁

## ⚠️ 注意事项

1. **一次性完成**：每个 Completer 只能完成一次，后续调用会被忽略
2. **内存管理**：StreamCancellable 会在 deinit 时自动取消，但建议主动调用 cancel()
3. **错误处理**：建议使用 `do-catch` 或错误回调处理可能的错误
4. **超时设置**：长时间运行的操作建议设置合理的超时时间
5. **Stream 取消**：调用 `stream.cancel()` 后，所有后续操作都会被忽略

## 🧪 单元测试

项目包含完整的单元测试，确保功能的正确性和稳定性。运行测试：

```bash
swift test
```

## � 示例应用

项目包含一个完整的 SwiftUI 示例应用，展示了 Completer 和 Stream 的各种用法。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE) 文件。

---

**作者**: SeeyouYsen  
**创建时间**: 2025 年 10 月 13 日  
**需要帮助？** 如果你遇到问题或有建议，欢迎提交 Issue！

---

*本 README 文档由 AI 辅助生成，为 YFlow 项目提供全面的说明文档。*
