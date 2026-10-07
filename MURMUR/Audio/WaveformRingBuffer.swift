/// Keeps the most recent `capacity` levels. Memory is fixed at creation and never grows.
struct WaveformRingBuffer: Sendable, Equatable {
    let capacity: Int
    private var storage: [Float]
    private var head = 0 // index of the oldest element once full
    private(set) var count = 0

    init(capacity: Int) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: 0, count: capacity)
    }

    mutating func append(_ level: Float) {
        if count < capacity {
            storage[(head + count) % capacity] = level
            count += 1
        } else {
            storage[head] = level
            head = (head + 1) % capacity
        }
    }

    /// Element `index` counted from the oldest (0) to the newest (`count - 1`).
    subscript(index: Int) -> Float {
        precondition(index >= 0 && index < count, "index out of range")
        return storage[(head + index) % capacity]
    }

    mutating func removeAll() {
        head = 0
        count = 0
    }

    var elements: [Float] {
        (0..<count).map { self[$0] }
    }
}
