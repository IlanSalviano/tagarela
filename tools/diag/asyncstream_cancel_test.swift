import Foundation
var cont: AsyncStream<Int>.Continuation!
let stream = AsyncStream<Int> { c in cont = c }
cont.onTermination = { r in print("onTermination fired: \(r)") }
let sem = DispatchSemaphore(value: 0)
Task {
    let consumer1 = Task { for await v in stream { print("consumer1 got \(v)") }; print("consumer1 loop ended") }
    try? await Task.sleep(nanoseconds: 50_000_000)
    print("yield(1) while consumer1 awaits ->", cont.yield(1))
    try? await Task.sleep(nanoseconds: 50_000_000)
    print("cancelling consumer1 (it is awaiting next())")
    consumer1.cancel()
    try? await Task.sleep(nanoseconds: 100_000_000)
    print("yield(2) after cancel ->", cont.yield(2))
    let consumer2 = Task { var n = 0; for await v in stream { print("consumer2 got \(v)"); n += 1 }; print("consumer2 loop ended, received \(n) values") }
    _ = await consumer2.value
    sem.signal()
}
sem.wait()
