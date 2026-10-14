import Darwin
import Foundation
import os

/// Measures how long a quick capture takes from the user's request to the first audio on disk.
///
/// The request is the moment the intent ran, which is the earliest point the app can see (the time
/// the system takes to launch the app before that is not covered, except in the "since launch"
/// figure). Read the numbers in Console.app, subsystem `com.cosmichomeless.murmur`, category
/// `quick-capture`.
enum StartLatency {
    private static let logger = Logger(subsystem: "com.cosmichomeless.murmur", category: "quick-capture")

    static func report(sinceRequest: Duration) {
        let ms = sinceRequest.milliseconds
        if let launch = processStart {
            let sinceLaunch = Date.now.timeIntervalSince(launch) * 1000
            logger.info("first audio \(ms, format: .fixed(precision: 0)) ms after the request, \(sinceLaunch, format: .fixed(precision: 0)) ms after the process started")
        } else {
            logger.info("first audio \(ms, format: .fixed(precision: 0)) ms after the request")
        }
    }

    /// When this process started, from the kernel. Only the first recording after a launch is
    /// a cold start; for later ones the figure just says how long the app has been alive.
    static let processStart: Date? = {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return nil }
        let time = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000)
    }()
}

extension Duration {
    var milliseconds: Double {
        let parts = components
        return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1_000_000_000_000_000
    }
}
