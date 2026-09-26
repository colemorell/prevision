import SwiftUI

enum Brand {
    static let cta = Color.accentColor
    static let canvas = Color(uiColor: .secondarySystemBackground)

    enum Typography {
        static let title = Font.title3.weight(.semibold)
        static let body = Font.body
        static let label = Font.subheadline.weight(.medium)
        static let caption = Font.caption
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 16
    }

    enum Motion {
        static let standard = Animation.easeInOut(duration: 0.3)
        static let placementDuration: TimeInterval = 0.45
    }
}
