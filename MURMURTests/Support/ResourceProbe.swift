import Darwin
import Foundation

/// Measures what a block of work costs: wall time, CPU time of the process and resident memory.
///
/// Numbers come from the process the tests run in (the simulator on the host Mac), so they show
/// how cost *scales* and catch regressions; they are not iPhone figures.
struct ResourceUsage {
    var wallSeconds: Double
    var cpuSeconds: Double
    var residentBefore: Int
    var residentAfter: Int

    var residentGrowthMB: Double { Double(residentAfter - residentBefore) / 1_048_576 }
    var residentAfterMB: Double { Double(residentAfter) / 1_048_576 }
}

enum ResourceProbe {
    static func measure(_ work: () throws -> Void) rethrows -> ResourceUsage {
        let residentBefore = residentBytes()
        let cpuBefore = cpuSeconds()
        let start = ContinuousClock.now
        try work()
        let wall = start.duration(to: .now)
        return ResourceUsage(
            wallSeconds: Double(wall.components.seconds) + Double(wall.components.attoseconds) / 1e18,
            cpuSeconds: cpuSeconds() - cpuBefore,
            residentBefore: residentBefore,
            residentAfter: residentBytes()
        )
    }

    /// User + system CPU time consumed by the whole process so far.
    static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ time: timeval) -> Double { Double(time.tv_sec) + Double(time.tv_usec) / 1e6 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }

    static func residentBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    /// One greppable line per measurement; `docs/PERFORMANCE.md` is written from these.
    static func report(_ name: String, _ fields: KeyValuePairs<String, String>) {
        let body = fields.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("METRIC \(name) \(body)")
    }
}
