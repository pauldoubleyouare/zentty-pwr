import AppKit
import Foundation

enum WorklaneColor: String, CaseIterable, Codable, Sendable {
    case red
    case orange
    case amber
    case yellow
    case lime
    case green
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink

    enum Alpha {
        static let inactive: CGFloat = 0.12
        static let hover: CGFloat = 0.18
        static let active: CGFloat = 0.22
        static let paneRowHover: CGFloat = 0.30
        static let paneRowPressed: CGFloat = 0.42
        static let focusedBorder: CGFloat = 0.55
        static let focusedGlow: CGFloat = 0.50

        /// Strength of the lane-colored stroke that fences a worklane's card off
        /// from its neighbours in the sidebar.
        ///
        /// Light appearance runs hotter than dark: the light hexes are deep
        /// (brightness pulled down so neon does not vibrate on a pale surface),
        /// so they need more alpha to carry the same edge weight.
        enum GroupBorder {
            static let idleDark: CGFloat = 0.62
            static let hoveredDark: CGFloat = 0.82
            static let activeDark: CGFloat = 1.0
            static let idleLight: CGFloat = 0.72
            static let hoveredLight: CGFloat = 0.88
            static let activeLight: CGFloat = 1.0
        }

        /// Neon bloom cast by the active lane card. Dark only — on a light
        /// surface a colored bloom reads as smudge, not glow.
        static let groupGlow: CGFloat = 0.55

        /// The hairline rule under a lane header title.
        static let headerRule: CGFloat = 0.55
    }

    /// How much of the lane hue is mixed into the lane header's title text.
    /// Low enough that the label still reads as a label, high enough that the
    /// header is unmistakably the same lane as the border around it.
    static let headerLabelTintAmount: CGFloat = 0.62

    var localizedName: String {
        switch self {
        case .red: return NSLocalizedString("Red", comment: "Worklane color")
        case .orange: return NSLocalizedString("Orange", comment: "Worklane color")
        case .amber: return NSLocalizedString("Amber", comment: "Worklane color")
        case .yellow: return NSLocalizedString("Yellow", comment: "Worklane color")
        case .lime: return NSLocalizedString("Lime", comment: "Worklane color")
        case .green: return NSLocalizedString("Green", comment: "Worklane color")
        case .teal: return NSLocalizedString("Teal", comment: "Worklane color")
        case .cyan: return NSLocalizedString("Cyan", comment: "Worklane color")
        case .blue: return NSLocalizedString("Blue", comment: "Worklane color")
        case .indigo: return NSLocalizedString("Indigo", comment: "Worklane color")
        case .purple: return NSLocalizedString("Purple", comment: "Worklane color")
        case .pink: return NSLocalizedString("Pink", comment: "Worklane color")
        }
    }

    private struct Hex {
        let dark: UInt32
        let light: UInt32
    }

    /// The neon wheel.
    ///
    /// Twelve hues laid out as **six complementary pairs**, each pair within
    /// 18° of true opposition, so any two lanes a user picks read as a
    /// deliberate combination rather than an accident:
    ///
    ///     red 352° ↔ teal 168°      orange 18° ↔ cyan 192°
    ///     amber 40° ↔ blue 214°     yellow 60° ↔ indigo 252°
    ///     lime 90° ↔ purple 286°    green 142° ↔ pink 324°
    ///
    /// Each case is one hue rendered twice, because a single hex cannot be neon
    /// on both surfaces:
    ///
    /// - **dark**: near-full brightness, saturation held back only as far as
    ///   each hue needs to stay electric instead of neon-white. This is the
    ///   glowing-tube end of the palette.
    /// - **light**: full saturation with brightness pulled down. Full-brightness
    ///   neon on a pale sidebar vibrates and drops below any usable contrast,
    ///   so light keeps the chroma and spends the luminance instead.
    ///
    /// Two properties are enforced by `WorklaneColorTests` rather than trusted:
    /// every hex clears WCAG 1.4.11's 3:1 non-text floor against its own
    /// appearance's sidebar surface, and no two cases collapse into each other
    /// (minimum pairwise sRGB separation 0.19 in both appearances).
    private var hex: Hex {
        switch self {
        case .red: return Hex(dark: 0xFF667A, light: 0xCF112A)
        case .orange: return Hex(dark: 0xFF7B42, light: 0xC4430C)
        case .amber: return Hex(dark: 0xFFB624, light: 0x9E6900)
        case .yellow: return Hex(dark: 0xFFFF1F, light: 0x69690A)
        case .lime: return Hex(dark: 0x91FA28, light: 0x346900)
        case .green: return Hex(dark: 0x31F579, light: 0x02732C)
        case .teal: return Hex(dark: 0x26F0C7, light: 0x0C7862)
        case .cyan: return Hex(dark: 0x38D7FF, light: 0x067E9C)
        case .blue: return Hex(dark: 0x61A5FF, light: 0x005CD4)
        case .indigo: return Hex(dark: 0x9D85FF, light: 0x6241E8)
        case .purple: return Hex(dark: 0xE07AFF, light: 0xAC09DE)
        case .pink: return Hex(dark: 0xFF70C6, light: 0xB81A78)
        }
    }

    func tint(alpha: CGFloat) -> NSColor {
        let hex = self.hex
        let rawValue = self.rawValue
        return NSColor(name: NSColor.Name("worklaneColor.\(rawValue)")) { appearance in
            let packed: UInt32
            if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil {
                packed = hex.dark
            } else {
                packed = hex.light
            }
            let r = CGFloat((packed >> 16) & 0xFF) / 255.0
            let g = CGFloat((packed >> 8) & 0xFF) / 255.0
            let b = CGFloat(packed & 0xFF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
        }
    }
}
