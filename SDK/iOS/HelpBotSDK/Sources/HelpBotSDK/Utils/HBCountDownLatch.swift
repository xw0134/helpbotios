import Foundation

/**
 轻量 CountDownLatch（iOS），用于跨线程等待事件完成。

 - 禁止在主线程等待：避免死锁/卡顿（SDK 内部会做保护，宿主也应遵守）。
 */
final class HBCountDownLatch {
    private let condition = NSCondition()
    private var count: Int

    init(_ count: Int) {
        self.count = max(count, 0)
    }

    func countDown() {
        condition.lock()
        if count > 0 {
            count -= 1
            if count == 0 {
                condition.broadcast()
            }
        }
        condition.unlock()
    }

    func await(timeoutMs: Int) -> Bool {
        let timeout = TimeInterval(max(timeoutMs, 0)) / 1000.0
        let deadline = Date().addingTimeInterval(timeout)

        condition.lock()
        defer { condition.unlock() }

        while count > 0 {
            if !condition.wait(until: deadline) {
                break
            }
        }
        return count == 0
    }
}


