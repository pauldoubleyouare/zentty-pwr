import AppKit
import XCTest
@testable import Zentty

@MainActor
final class WorklaneColorTests: XCTestCase {
    func test_every_case_has_a_non_empty_localized_name() {
        for color in WorklaneColor.allCases {
            XCTAssertFalse(color.localizedName.isEmpty, "Missing localized name for \(color.rawValue)")
        }
    }

    func test_every_case_round_trips_through_raw_value() throws {
        for color in WorklaneColor.allCases {
            let decoded = try XCTUnwrap(WorklaneColor(rawValue: color.rawValue))
            XCTAssertEqual(decoded, color)
        }
    }

    func test_every_case_round_trips_through_json() throws {
        for color in WorklaneColor.allCases {
            let data = try JSONEncoder().encode(color)
            let decoded = try JSONDecoder().decode(WorklaneColor.self, from: data)
            XCTAssertEqual(decoded, color)
        }
    }

    func test_tint_preserves_requested_alpha() {
        let alphas: [CGFloat] = [
            WorklaneColor.Alpha.inactive,
            WorklaneColor.Alpha.hover,
            WorklaneColor.Alpha.active,
        ]
        for color in WorklaneColor.allCases {
            for alpha in alphas {
                let nsColor = color.tint(alpha: alpha).usingColorSpace(.sRGB)
                XCTAssertEqual(nsColor?.alphaComponent ?? -1, alpha, accuracy: 0.001,
                               "Alpha mismatch for \(color.rawValue) at \(alpha)")
            }
        }
    }

    func test_unknown_raw_value_decodes_to_nil() {
        XCTAssertNil(WorklaneColor(rawValue: "chartreuse"))
        XCTAssertNil(WorklaneColor(rawValue: ""))
    }

    // MARK: - Neon palette

    /// The lane color is drawn as a 2pt border around a worklane card, which is
    /// a non-text UI component: WCAG 1.4.11 puts the floor at 3:1 against the
    /// surface behind it. Checked per appearance, because dark and light
    /// resolve to different hexes.
    func test_every_hue_clears_the_non_text_contrast_floor_on_its_own_surface() {
        for (appearance, theme) in [(NSAppearance.Name.darkAqua, darkTheme), (.aqua, lightTheme)] {
            let surface = theme.sidebarBackground.composited(over: theme.windowBackground)
            for color in WorklaneColor.allCases {
                let tint = resolvedTint(color, appearance: appearance)
                XCTAssertGreaterThanOrEqual(
                    tint.contrastRatio(against: surface),
                    3.0,
                    "\(color.rawValue) on \(appearance.rawValue) is \(tint.themeHexString), "
                        + "too weak against the sidebar surface to hold a lane border"
                )
            }
        }
    }

    /// A picker of twelve is only useful if a user can tell which lane is which
    /// at a glance, so no two hues may perceptually collapse together.
    func test_no_two_hues_collapse_into_each_other() {
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            let tints = WorklaneColor.allCases.map {
                ($0, resolvedTint($0, appearance: appearance))
            }
            for index in tints.indices {
                for other in tints.indices where other > index {
                    XCTAssertGreaterThan(
                        tints[index].1.srgbDistance(to: tints[other].1),
                        0.19,
                        "\(tints[index].0.rawValue) and \(tints[other].0.rawValue) are too close "
                            + "to tell apart on \(appearance.rawValue)"
                    )
                }
            }
        }
    }

    /// The palette is twelve hues arranged as six complementary pairs, so any
    /// two lanes a user picks off opposite sides of the wheel read as a
    /// deliberate combination.
    func test_palette_is_six_complementary_pairs() throws {
        let pairs: [(WorklaneColor, WorklaneColor)] = [
            (.red, .teal),
            (.orange, .cyan),
            (.amber, .blue),
            (.yellow, .indigo),
            (.lime, .purple),
            (.green, .pink),
        ]

        for (lhs, rhs) in pairs {
            let lhsHue = try XCTUnwrap(hue(of: resolvedTint(lhs, appearance: .darkAqua)))
            let rhsHue = try XCTUnwrap(hue(of: resolvedTint(rhs, appearance: .darkAqua)))
            var separation = abs(lhsHue - rhsHue) * 360
            if separation > 180 {
                separation = 360 - separation
            }
            XCTAssertGreaterThan(
                separation,
                155,
                "\(lhs.rawValue) and \(rhs.rawValue) are meant to be complements, "
                    + "but sit only \(Int(separation))° apart"
            )
        }
    }

    /// Neon cannot be one hex. Dark keeps the brightness and trims saturation;
    /// light keeps the saturation and spends the brightness, so the color does
    /// not vibrate on a near-white sidebar.
    func test_dark_variant_is_brighter_and_light_variant_is_more_saturated() throws {
        for color in WorklaneColor.allCases {
            let dark = try XCTUnwrap(hsb(of: resolvedTint(color, appearance: .darkAqua)))
            let light = try XCTUnwrap(hsb(of: resolvedTint(color, appearance: .aqua)))

            XCTAssertGreaterThan(
                dark.brightness,
                light.brightness,
                "\(color.rawValue) must be brighter on dark than on light"
            )
            XCTAssertGreaterThan(
                light.saturation,
                dark.saturation,
                "\(color.rawValue) must hold more chroma on light than on dark"
            )
            XCTAssertEqual(
                dark.hue,
                light.hue,
                accuracy: 0.02,
                "\(color.rawValue) must be the same hue in both appearances"
            )
        }
    }

    /// Every hue is a real hue — the appearance split must never bottom out
    /// into a gray that no longer reads as a lane color.
    func test_every_hue_stays_saturated_in_both_appearances() throws {
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            for color in WorklaneColor.allCases {
                let components = try XCTUnwrap(hsb(of: resolvedTint(color, appearance: appearance)))
                XCTAssertGreaterThan(
                    components.saturation,
                    0.4,
                    "\(color.rawValue) washed out on \(appearance.rawValue)"
                )
            }
        }
    }

    // MARK: - Helpers

    private var darkTheme: ZenttyTheme { theme(dark: true) }
    private var lightTheme: ZenttyTheme { theme(dark: false) }

    private func theme(dark: Bool) -> ZenttyTheme {
        ZenttyTheme(
            resolvedTheme: GhosttyResolvedTheme(
                background: NSColor(hexString: dark ? "#0A0C10" : "#FBFBFD")!,
                foreground: NSColor(hexString: dark ? "#F0F3F6" : "#1A1C1F")!,
                cursorColor: NSColor(hexString: dark ? "#71B7FF" : "#3366CC")!,
                selectionBackground: nil,
                selectionForeground: nil,
                palette: [:],
                backgroundOpacity: dark ? 0.9 : 1.0,
                backgroundBlurRadius: 25
            )
        )
    }

    /// `WorklaneColor.tint` is a dynamic `NSColor`, so it only resolves to the
    /// dark or light hex under a matching drawing appearance.
    private func resolvedTint(
        _ color: WorklaneColor,
        appearance name: NSAppearance.Name
    ) -> NSColor {
        var resolved = NSColor.clear
        NSAppearance(named: name)?.performAsCurrentDrawingAppearance {
            resolved = color.tint(alpha: 1).srgbClamped
        }
        return resolved
    }

    private func hsb(of color: NSColor) -> (
        hue: CGFloat,
        saturation: CGFloat,
        brightness: CGFloat
    )? {
        guard let converted = color.usingColorSpace(.deviceRGB) else {
            return nil
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        converted.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness)
    }

    private func hue(of color: NSColor) -> CGFloat? {
        hsb(of: color)?.hue
    }
}
