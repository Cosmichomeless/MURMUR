import Foundation

/// Where the policy and support live. The repository is public, so its rendered files are the
/// pages App Store Connect points to.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://github.com/Cosmichomeless/MURMUR/blob/main/docs/privacy.md")!
    static let support = URL(string: "https://github.com/Cosmichomeless/MURMUR/blob/main/docs/support.md")!
    static let issues = URL(string: "https://github.com/Cosmichomeless/MURMUR/issues")!
}
