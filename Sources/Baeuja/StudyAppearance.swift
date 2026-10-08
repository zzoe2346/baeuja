import SwiftUI

enum ReaderTypography {
    static let defaultSize = 18.0
    static let sizeRange = 14.0...36.0
}

/// Keep native action styles available on the app's macOS 14 minimum target.
private struct StudyActionStyle: ViewModifier {
    var prominent: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

extension View {
    func studyActionStyle(prominent: Bool = false) -> some View {
        modifier(StudyActionStyle(prominent: prominent))
    }
}
