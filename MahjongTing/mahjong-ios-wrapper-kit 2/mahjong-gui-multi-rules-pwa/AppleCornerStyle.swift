import SwiftUI

enum AppleCornerRadius {
    static let compact: CGFloat = 8
    static let badge: CGFloat = 10
    static let control: CGFloat = 12
    static let panel: CGFloat = 16
    static let overlayGuide: CGFloat = 18
}

enum AppleCornerShape {
    static func continuous(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

extension View {
    func appleClip(_ radius: CGFloat) -> some View {
        clipShape(AppleCornerShape.continuous(radius))
    }

    func appleStroke(_ color: Color, radius: CGFloat, lineWidth: CGFloat = 1) -> some View {
        overlay(
            AppleCornerShape.continuous(radius)
                .stroke(color, lineWidth: lineWidth)
        )
    }
}
