import AppKit
import SwiftUI

/// A color the user picked for a provider card in Customize. Named macOS system hues only — never
/// free-form values — so every choice tracks light/dark and Increase Contrast like the rest of the
/// palette, and the stored raw value stays stable across releases.
///
/// When set, it replaces the brand color of the provider's Total Spend slice and legend dot; provider
/// marks stay monochrome. `nil` on `Provider.color` means "Automatic": the brand color.
enum ProviderColor: String, Codable, CaseIterable, Sendable {
    /// Ten hues: with Automatic, eleven swatches — the most that fit beside the label in the 320pt
    /// popover (see `ProviderColorSwatches`).
    case red, orange, yellow, green, teal, blue, indigo, purple, pink, gray

    var color: Color { Color(nsColor: nsColor) }

    var title: String { rawValue.capitalized }

    private var nsColor: NSColor {
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .teal: return .systemTeal
        case .blue: return .systemBlue
        case .indigo: return .systemIndigo
        case .purple: return .systemPurple
        case .pink: return .systemPink
        case .gray: return .systemGray
        }
    }
}
