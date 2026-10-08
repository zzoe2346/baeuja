import Foundation

// Read the system-selected bundle localization for app titles.
enum AppName {
    static var display: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "배우자"
    }
}
