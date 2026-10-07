/// Reduces an unbounded stream of levels to a bounded summary that keeps the peaks.
///
/// Each bin holds the maximum of `stride` consecutive levels. Whenever the bins reach
/// `2 * binCount` they are merged in pairs (by max) and `stride` doubles, so a recording of any
/// length uses at most `2 * binCount + 1` floats and the summary always spans the whole recording.
struct WaveformDownsampler: Sendable, Equatable {
    let binCount: Int
    private(set) var stride = 1
    private var bins: [Float] = []
    private var pendingMax: Float = 0
    private var pendingCount = 0

    init(binCount: Int) {
        precondition(binCount > 0, "binCount must be positive")
        self.binCount = binCount
        bins.reserveCapacity(2 * binCount)
    }

    mutating func append(_ level: Float) {
        pendingMax = max(pendingMax, level)
        pendingCount += 1
        guard pendingCount == stride else { return }

        bins.append(pendingMax)
        pendingMax = 0
        pendingCount = 0

        if bins.count == 2 * binCount {
            mergePairs()
        }
    }

    /// The summary so far: between `binCount` and `2 * binCount` bins once enough audio has been
    /// seen, fewer for short recordings. The trailing partial bin is included.
    var result: [Float] {
        pendingCount > 0 ? bins + [pendingMax] : bins
    }

    private mutating func mergePairs() {
        var merged: [Float] = []
        merged.reserveCapacity(2 * binCount)
        for index in Swift.stride(from: 0, to: bins.count, by: 2) {
            merged.append(max(bins[index], bins[index + 1]))
        }
        bins = merged
        self.stride *= 2
    }
}
