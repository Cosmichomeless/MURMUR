#if DEBUG
import Foundation

/// A reproducible run of the app for screenshots and walkthroughs: a seeded library, a recorder that
/// needs no microphone and a throwaway file store. Debug builds only; it is compiled out of Release.
///
/// Launch with `-murmur-demo` (or `-murmur-demo-empty` for the first-run screen); add
/// `-murmur-demo-screen recorder|player` to open that screen directly.
enum DemoMode {
    static let flag = "-murmur-demo"
    static let emptyFlag = "-murmur-demo-empty"

    static var isEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains(flag) || arguments.contains(emptyFlag)
    }

    static var startsEmpty: Bool {
        ProcessInfo.processInfo.arguments.contains(emptyFlag)
    }

    enum Screen: String {
        case recorder
        case player
    }

    /// `-murmur-demo-screen recorder|player`
    static var startScreen: Screen? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-murmur-demo-screen"), index + 1 < arguments.count else { return nil }
        return Screen(rawValue: arguments[index + 1])
    }

    /// Fresh on every launch, so two runs show exactly the same thing. Never the real store.
    static func makeFileStore() -> RecordingFileStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MURMUR-Demo", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let store = RecordingFileStore(
            recordingsDirectory: root.appendingPathComponent("Recordings", isDirectory: true),
            temporaryDirectory: root.appendingPathComponent("Capture", isDirectory: true)
        )
        try? store.prepareDirectories()
        return store
    }
}
#endif
