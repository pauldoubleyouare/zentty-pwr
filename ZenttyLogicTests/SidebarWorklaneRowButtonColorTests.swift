import AppKit
import XCTest
@testable import Zentty

@MainActor
final class SidebarWorklaneRowButtonColorTests: AppKitTestCase {
    func test_style_resolver_tint_uses_hover_alpha_only_when_pane_row_is_not_hovered() {
        let tint = SidebarWorklaneRowStyleResolver.tintColor(
            worklaneColor: .red,
            isActive: false,
            isHovered: true,
            isPaneRowHovered: false
        )
        let paneHoveredTint = SidebarWorklaneRowStyleResolver.tintColor(
            worklaneColor: .red,
            isActive: false,
            isHovered: true,
            isPaneRowHovered: true
        )

        XCTAssertEqual(tint.alpha, WorklaneColor.Alpha.hover, accuracy: 0.001)
        XCTAssertEqual(paneHoveredTint.alpha, WorklaneColor.Alpha.inactive, accuracy: 0.001)
    }

    func test_no_color_leaves_tint_layer_clear() {
        let row = makeRow()
        row.configure(with: makeSummary(color: nil, isActive: false), theme: ZenttyTheme.fallback(for: nil), animated: false)
        let cg = row.debugSnapshotForTesting.tintLayerBackgroundColor ?? NSColor.clear.cgColor
        XCTAssertEqual(cg.alpha, 0, accuracy: 0.001)
    }

    func test_inactive_colored_row_uses_inactive_alpha() {
        let row = makeRow()
        row.configure(with: makeSummary(color: .red, isActive: false), theme: ZenttyTheme.fallback(for: nil), animated: false)
        let alpha = row.debugSnapshotForTesting.tintLayerBackgroundColor?.alpha ?? -1
        XCTAssertEqual(alpha, WorklaneColor.Alpha.inactive, accuracy: 0.001)
    }

    func test_hovered_colored_row_uses_hover_alpha() {
        let row = makeRow()
        row.configure(with: makeSummary(color: .blue, isActive: false), theme: ZenttyTheme.fallback(for: nil), animated: false)
        row.performDebugInteractionForTesting(.setHovered(true))
        let alpha = row.debugSnapshotForTesting.tintLayerBackgroundColor?.alpha ?? -1
        XCTAssertEqual(alpha, WorklaneColor.Alpha.hover, accuracy: 0.001)
    }

    func test_active_colored_row_uses_active_alpha() {
        let row = makeRow()
        row.configure(with: makeSummary(color: .green, isActive: true), theme: ZenttyTheme.fallback(for: nil), animated: false)
        let alpha = row.debugSnapshotForTesting.tintLayerBackgroundColor?.alpha ?? -1
        XCTAssertEqual(alpha, WorklaneColor.Alpha.active, accuracy: 0.001)
    }

    func test_clearing_color_resets_tint() {
        let row = makeRow()
        let theme = ZenttyTheme.fallback(for: nil)
        row.configure(with: makeSummary(color: .purple, isActive: false), theme: theme, animated: false)
        XCTAssertGreaterThan(row.debugSnapshotForTesting.tintLayerBackgroundColor?.alpha ?? 0, 0)

        row.configure(with: makeSummary(color: nil, isActive: false), theme: theme, animated: false)
        XCTAssertEqual(row.debugSnapshotForTesting.tintLayerBackgroundColor?.alpha ?? -1, 0, accuracy: 0.001)
    }

    func test_colored_inactive_working_row_shimmer_preserves_worklane_hue_and_brightens_on_dark_sidebar() throws {
        let row = makeRow()
        let theme = darkTheme(foreground: "#F0F3F6")

        row.configure(
            with: makeSummary(color: .blue, isActive: false, isWorking: true),
            theme: theme,
            animated: false
        )

        let baseColor = WorklaneColor.blue.tint(alpha: 1)
        let base = try XCTUnwrap(hsbComponents(baseColor))
        let shimmerColor = row.debugSnapshotForTesting.shimmerColor
        let shimmer = try XCTUnwrap(hsbComponents(shimmerColor))

        XCTAssertEqual(shimmer.hue, base.hue, accuracy: 0.02)
        // Measured as luminance, not HSB brightness. The neon palette's dark
        // hexes are already at full brightness, so the highlight can only get
        // brighter by heading for white — which necessarily costs saturation.
        // Luminance is both the property that survives that trade and the one
        // the eye actually reads as "the shimmer swept past".
        XCTAssertGreaterThan(
            shimmerColor.srgbClamped.withAlphaComponent(1).perceivedLuminance,
            baseColor.srgbClamped.perceivedLuminance
        )
        XCTAssertLessThan(shimmer.saturation, base.saturation)
    }

    func test_colored_active_working_row_shimmer_preserves_hue_and_uses_darker_shade() throws {
        let row = makeRow()
        let theme = darkTheme(foreground: "#F0F3F6")

        row.configure(
            with: makeSummary(color: .purple, isActive: true, isWorking: true),
            theme: theme,
            animated: false
        )

        let base = try XCTUnwrap(hsbComponents(WorklaneColor.purple.tint(alpha: 1)))
        let shimmer = try XCTUnwrap(hsbComponents(row.debugSnapshotForTesting.shimmerColor))

        XCTAssertEqual(shimmer.hue, base.hue, accuracy: 0.02)
        XCTAssertGreaterThanOrEqual(shimmer.saturation, base.saturation)
        XCTAssertLessThan(shimmer.brightness, base.brightness)
    }

    func test_colored_worklane_status_shimmer_keeps_semantic_hue() throws {
        let row = makeRow()
        let theme = darkTheme(foreground: "#F0F3F6")

        row.configure(
            with: makeSummary(
                color: .pink,
                statusText: "Running",
                attentionState: .running,
                taskProgress: PaneAgentTaskProgress(doneCount: 2, totalCount: 5),
                isWorking: true
            ),
            theme: theme,
            animated: false
        )

        let base = try XCTUnwrap(hsbComponents(WorklaneColor.pink.tint(alpha: 1)))
        let expected = try XCTUnwrap(hsbComponents(statusShimmerBaseColor(theme)))
        let shimmer = try XCTUnwrap(hsbComponents(row.debugSnapshotForTesting.statusShimmerColor))

        XCTAssertNotEqual(shimmer.hue, base.hue, accuracy: 0.02)
        XCTAssertEqual(shimmer.hue, expected.hue, accuracy: 0.02)
        XCTAssertEqual(row.debugSnapshotForTesting.statusTextColor.srgbClamped, theme.statusRunning.srgbClamped)
        XCTAssertEqual(row.debugSnapshotForTesting.statusProgressColor.srgbClamped, theme.statusRunning.srgbClamped)
    }

    func test_compacting_status_uses_running_status_color() throws {
        let row = makeRow()
        let theme = darkTheme(foreground: "#F0F3F6")

        row.configure(
            with: makeSummary(
                color: nil,
                statusText: "Compacting",
                attentionState: .running,
                isWorking: true
            ),
            theme: theme,
            animated: false
        )

        XCTAssertEqual(row.debugSnapshotForTesting.statusTextColor.srgbClamped, theme.statusRunning.srgbClamped)
    }

    func test_colored_worklane_focused_pane_title_shimmer_is_desaturated_while_status_stays_semantic() throws {
        let row = makeRow(width: 320, height: 110)
        let theme = darkTheme(foreground: "#F0F3F6")

        row.configure(
            with: makeSummary(
                color: .pink,
                paneRows: [
                    WorklaneSidebarPaneRow(
                        paneID: PaneID("pane-agent"),
                        primaryText: "Claude Code",
                        trailingText: "main",
                        detailText: ".../zentty",
                        statusText: "Running",
                        attentionState: .running,
                        isFocused: true,
                        isWorking: true
                    ),
                ],
                isWorking: true
            ),
            theme: theme,
            animated: false
        )

        let base = try XCTUnwrap(hsbComponents(WorklaneColor.pink.tint(alpha: 1)))
        let expectedStatus = try XCTUnwrap(hsbComponents(statusShimmerBaseColor(theme)))
        let primaryShimmer = try XCTUnwrap(row.debugSnapshotForTesting.firstPanePrimaryShimmerColor)
        let statusShimmer = try XCTUnwrap(row.debugSnapshotForTesting.firstPaneStatusShimmerColor)
        let primaryComponents = try XCTUnwrap(hsbComponents(primaryShimmer))

        XCTAssertEqual(primaryComponents.hue, base.hue, accuracy: 0.02)
        XCTAssertLessThan(primaryComponents.saturation, base.saturation)
        XCTAssertLessThan(primaryShimmer.srgbClamped.alphaComponent, statusShimmer.srgbClamped.alphaComponent)
        XCTAssertEqual(try XCTUnwrap(hsbComponents(statusShimmer)).hue, expectedStatus.hue, accuracy: 0.02)
        XCTAssertEqual(row.debugSnapshotForTesting.firstPaneStatusTextColor?.srgbClamped, theme.statusRunning.srgbClamped)
    }

    func test_colored_worklane_unfocused_pane_title_shimmer_is_much_more_neutral_than_focused_title() throws {
        let focusedRow = makeRow(width: 320, height: 110)
        let unfocusedRow = makeRow(width: 320, height: 110)
        let theme = darkTheme(foreground: "#F0F3F6")

        focusedRow.configure(
            with: makeSummary(
                color: .pink,
                paneRows: [makePaneRow(isFocused: true)],
                isWorking: true
            ),
            theme: theme,
            animated: false
        )
        unfocusedRow.configure(
            with: makeSummary(
                color: .pink,
                paneRows: [makePaneRow(isFocused: false)],
                isWorking: true
            ),
            theme: theme,
            animated: false
        )

        let focusedShimmer = try XCTUnwrap(focusedRow.debugSnapshotForTesting.firstPanePrimaryShimmerColor)
        let unfocusedShimmer = try XCTUnwrap(unfocusedRow.debugSnapshotForTesting.firstPanePrimaryShimmerColor)
        let focused = try XCTUnwrap(hsbComponents(focusedShimmer))
        let unfocused = try XCTUnwrap(hsbComponents(unfocusedShimmer))

        XCTAssertLessThan(unfocused.saturation, focused.saturation)
        XCTAssertLessThan(unfocused.brightness, focused.brightness)
        XCTAssertLessThan(unfocusedShimmer.srgbClamped.alphaComponent, focusedShimmer.srgbClamped.alphaComponent)
    }

    // MARK: - Vivid selected-row per-worklane color

    func test_subtle_selected_chrome_with_lane_color_is_identity_dark() {
        assertSubtleSelectedChromeIsIdentity(theme: makeTheme(dark: true, emphasis: .subtle))
    }

    func test_subtle_selected_chrome_with_lane_color_is_identity_light() {
        assertSubtleSelectedChromeIsIdentity(theme: makeTheme(dark: false, emphasis: .subtle))
    }

    func test_vivid_selected_chrome_without_color_is_identity() {
        let theme = makeTheme(dark: true, emphasis: .vivid)
        let bg = NSColor(srgbRed: 0.2, green: 0.3, blue: 0.4, alpha: 0.9)
        let text = NSColor.white

        let chrome = SidebarWorklaneRowStyleResolver.selectedRowChrome(
            worklaneColor: nil,
            activeBackground: bg,
            activeText: text,
            theme: theme
        )

        assertColorsEqual(chrome.background, bg)
        assertColorsEqual(chrome.text, text.srgbClamped)
    }

    func test_vivid_selected_chrome_with_lane_color_is_lane_tinted_dark() throws {
        try assertVividLaneChrome(theme: makeTheme(dark: true, emphasis: .vivid), color: .blue)
    }

    func test_vivid_selected_chrome_with_lane_color_is_lane_tinted_light() throws {
        try assertVividLaneChrome(theme: makeTheme(dark: false, emphasis: .vivid), color: .pink)
    }

    func test_vivid_selected_chrome_lane_fill_is_clearly_separated_from_idle() {
        let theme = makeTheme(dark: true, emphasis: .vivid)
        let chrome = SidebarWorklaneRowStyleResolver.selectedRowChrome(
            worklaneColor: .green,
            activeBackground: theme.sidebarButtonActiveBackground,
            activeText: theme.sidebarButtonActiveText,
            theme: theme
        )
        let surface = theme.sidebarBackground.composited(over: theme.windowBackground)
        let selected = chrome.background.composited(over: surface)
        let idle = theme.sidebarButtonInactiveBackground.composited(over: surface)

        XCTAssertGreaterThan(srgbDistance(selected, idle), 0.12)
    }

    func test_vivid_selected_chrome_text_stays_legible_on_lane_fill() throws {
        for color in WorklaneColor.allCases {
            for dark in [true, false] {
                let theme = makeTheme(dark: dark, emphasis: .vivid)
                let chrome = SidebarWorklaneRowStyleResolver.selectedRowChrome(
                    worklaneColor: color,
                    activeBackground: theme.sidebarButtonActiveBackground,
                    activeText: theme.sidebarButtonActiveText,
                    theme: theme
                )
                let surface = theme.sidebarBackground.composited(over: theme.windowBackground)
                let fill = chrome.background.composited(over: surface)
                XCTAssertGreaterThanOrEqual(
                    chrome.text.contrastRatio(against: fill),
                    4.5,
                    "Lane \(color.rawValue) (dark=\(dark)) selected text must clear WCAG AA on its fill"
                )
            }
        }
    }

    func test_vivid_active_lane_row_background_is_lane_tinted_and_differs_from_idle() throws {
        let theme = makeTheme(dark: true, emphasis: .vivid)
        let activeRow = makeRow()
        activeRow.configure(with: makeSummary(color: .blue, isActive: true), theme: theme, animated: false)
        let idleRow = makeRow()
        idleRow.configure(with: makeSummary(color: .blue, isActive: false), theme: theme, animated: false)

        let activeBackground = try XCTUnwrap(activeRow.debugSnapshotForTesting.backgroundColor)
        let idleBackground = try XCTUnwrap(idleRow.debugSnapshotForTesting.backgroundColor)

        let laneHue = try XCTUnwrap(hsbComponents(WorklaneColor.blue.tint(alpha: 1))).hue
        let activeHue = try XCTUnwrap(hsbComponents(activeBackground)).hue
        XCTAssertEqual(activeHue, laneHue, accuracy: 0.06)
        XCTAssertGreaterThan(srgbDistance(activeBackground, idleBackground), 0.1)
    }

    // MARK: - Worklane group border

    func test_group_border_is_lane_colored_and_thick_enough_to_fence_the_card() throws {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        let border = SidebarWorklaneRowStyleResolver.groupBorder(
            worklaneColor: .cyan,
            isActive: false,
            isHovered: false,
            isPaneRowHovered: false,
            activeBorder: theme.sidebarButtonActiveBorder,
            inactiveBorder: theme.sidebarButtonInactiveBorder,
            theme: theme
        )

        let laneHue = try XCTUnwrap(hsbComponents(WorklaneColor.cyan.tint(alpha: 1))).hue
        XCTAssertEqual(try XCTUnwrap(hsbComponents(border.color)).hue, laneHue, accuracy: 0.02)
        XCTAssertGreaterThanOrEqual(border.width, 2)
        XCTAssertLessThanOrEqual(border.width, 3)
    }

    func test_group_border_gains_weight_and_opacity_as_the_lane_activates() {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        func border(isActive: Bool, isHovered: Bool) -> SidebarWorklaneRowStyleResolver.GroupBorder {
            SidebarWorklaneRowStyleResolver.groupBorder(
                worklaneColor: .pink,
                isActive: isActive,
                isHovered: isHovered,
                isPaneRowHovered: false,
                activeBorder: theme.sidebarButtonActiveBorder,
                inactiveBorder: theme.sidebarButtonInactiveBorder,
                theme: theme
            )
        }

        let idle = border(isActive: false, isHovered: false)
        let hovered = border(isActive: false, isHovered: true)
        let active = border(isActive: true, isHovered: false)

        XCTAssertLessThan(idle.color.alphaComponent, hovered.color.alphaComponent)
        XCTAssertLessThan(hovered.color.alphaComponent, active.color.alphaComponent)
        XCTAssertEqual(idle.width, hovered.width)
        XCTAssertGreaterThan(active.width, idle.width)
    }

    func test_uncolored_lane_still_gets_a_group_weight_fence_from_the_theme() {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        let border = SidebarWorklaneRowStyleResolver.groupBorder(
            worklaneColor: nil,
            isActive: false,
            isHovered: false,
            isPaneRowHovered: false,
            activeBorder: theme.sidebarButtonActiveBorder,
            inactiveBorder: theme.sidebarButtonInactiveBorder,
            theme: theme
        )

        assertColorsEqual(border.color, theme.sidebarButtonInactiveBorder)
        XCTAssertEqual(border.width, SidebarWorklaneRowStyleResolver.GroupBorderMetrics.idle)
        XCTAssertNil(border.glow)
    }

    func test_group_border_hover_defers_to_a_hovered_pane_row() {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        func border(isPaneRowHovered: Bool) -> SidebarWorklaneRowStyleResolver.GroupBorder {
            SidebarWorklaneRowStyleResolver.groupBorder(
                worklaneColor: .lime,
                isActive: false,
                isHovered: true,
                isPaneRowHovered: isPaneRowHovered,
                activeBorder: theme.sidebarButtonActiveBorder,
                inactiveBorder: theme.sidebarButtonInactiveBorder,
                theme: theme
            )
        }

        XCTAssertLessThan(
            border(isPaneRowHovered: true).color.alphaComponent,
            border(isPaneRowHovered: false).color.alphaComponent
        )
    }

    func test_group_border_runs_hotter_on_light_where_the_hexes_are_deeper() {
        func alpha(dark: Bool) -> CGFloat {
            SidebarWorklaneRowStyleResolver.groupBorder(
                worklaneColor: .indigo,
                isActive: false,
                isHovered: false,
                isPaneRowHovered: false,
                activeBorder: .clear,
                inactiveBorder: .clear,
                theme: makeTheme(dark: dark, emphasis: .subtle)
            ).color.alphaComponent
        }

        XCTAssertGreaterThan(alpha(dark: false), alpha(dark: true))
    }

    func test_active_lane_glows_on_dark_and_never_on_light() throws {
        func glow(dark: Bool, isActive: Bool) -> NSColor? {
            SidebarWorklaneRowStyleResolver.groupBorder(
                worklaneColor: .purple,
                isActive: isActive,
                isHovered: false,
                isPaneRowHovered: false,
                activeBorder: .clear,
                inactiveBorder: .clear,
                theme: makeTheme(dark: dark, emphasis: .subtle)
            ).glow
        }

        let laneHue = try XCTUnwrap(hsbComponents(WorklaneColor.purple.tint(alpha: 1))).hue
        let darkGlow = try XCTUnwrap(glow(dark: true, isActive: true))
        XCTAssertEqual(try XCTUnwrap(hsbComponents(darkGlow)).hue, laneHue, accuracy: 0.02)
        XCTAssertNil(glow(dark: true, isActive: false))
        XCTAssertNil(glow(dark: false, isActive: true))
    }

    func test_reduced_transparency_drops_the_glow_but_keeps_the_border() throws {
        let theme = ZenttyTheme(
            resolvedTheme: GhosttyResolvedTheme(
                background: NSColor(hexString: "#0A0C10")!,
                foreground: NSColor(hexString: "#F0F3F6")!,
                cursorColor: NSColor(hexString: "#71B7FF")!,
                selectionBackground: nil,
                selectionForeground: nil,
                palette: [:],
                backgroundOpacity: 0.9,
                backgroundBlurRadius: 25
            ),
            reduceTransparency: true
        )
        let border = SidebarWorklaneRowStyleResolver.groupBorder(
            worklaneColor: .green,
            isActive: true,
            isHovered: false,
            isPaneRowHovered: false,
            activeBorder: .clear,
            inactiveBorder: .clear,
            theme: theme
        )

        XCTAssertNil(border.glow)
        XCTAssertGreaterThan(border.color.alphaComponent, 0.9)
    }

    func test_row_paints_the_lane_group_border_and_glow() throws {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        let row = makeRow()
        row.configure(with: makeSummary(color: .cyan, isActive: true), theme: theme, animated: false)

        let snapshot = row.debugSnapshotForTesting
        let laneHue = try XCTUnwrap(hsbComponents(WorklaneColor.cyan.tint(alpha: 1))).hue
        let borderColor = try XCTUnwrap(snapshot.groupBorderColor)
        XCTAssertEqual(try XCTUnwrap(hsbComponents(borderColor)).hue, laneHue, accuracy: 0.02)
        XCTAssertEqual(
            snapshot.groupBorderWidth,
            SidebarWorklaneRowStyleResolver.GroupBorderMetrics.active,
            accuracy: 0.001
        )

        let glow = try XCTUnwrap(snapshot.groupGlowColor)
        XCTAssertEqual(try XCTUnwrap(hsbComponents(glow)).hue, laneHue, accuracy: 0.02)
        XCTAssertGreaterThan(snapshot.groupGlowRadius, 0)
    }

    func test_uncolored_row_paints_a_neutral_fence_without_a_glow() throws {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        let row = makeRow()
        row.configure(with: makeSummary(color: nil, isActive: false), theme: theme, animated: false)

        let snapshot = row.debugSnapshotForTesting
        XCTAssertEqual(
            snapshot.groupBorderWidth,
            SidebarWorklaneRowStyleResolver.GroupBorderMetrics.idle,
            accuracy: 0.001
        )
        XCTAssertNil(snapshot.groupGlowColor)
        XCTAssertGreaterThan(try XCTUnwrap(snapshot.groupBorderColor).alphaComponent, 0)
    }

    // MARK: - Lane header tie-in

    func test_header_rule_carries_the_lane_hue() throws {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        let rule = SidebarWorklaneRowStyleResolver.headerRuleColor(
            worklaneColor: .amber,
            theme: theme
        )

        let laneHue = try XCTUnwrap(hsbComponents(WorklaneColor.amber.tint(alpha: 1))).hue
        XCTAssertEqual(try XCTUnwrap(hsbComponents(rule)).hue, laneHue, accuracy: 0.02)
        XCTAssertEqual(rule.alphaComponent, WorklaneColor.Alpha.headerRule, accuracy: 0.001)
    }

    func test_header_rule_without_a_lane_color_stays_on_the_theme_border() {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        assertColorsEqual(
            SidebarWorklaneRowStyleResolver.headerRuleColor(worklaneColor: nil, theme: theme),
            theme.sidebarBorder
        )
    }

    func test_idle_lane_header_title_picks_up_the_lane_hue_and_stays_legible() throws {
        for color in WorklaneColor.allCases {
            for dark in [true, false] {
                let theme = makeTheme(dark: dark, emphasis: .subtle)
                let surface = theme.sidebarBackground.composited(over: theme.windowBackground)
                let tinted = SidebarWorklaneRowStyleResolver.topLabelTextColor(
                    worklaneColor: color,
                    isActive: false,
                    activeTextColor: theme.sidebarButtonActiveText,
                    theme: theme
                )

                XCTAssertGreaterThanOrEqual(
                    tinted.contrastRatio(against: surface),
                    4.5,
                    "Lane \(color.rawValue) (dark=\(dark)) header title must clear WCAG AA"
                )
                XCTAssertGreaterThan(
                    tinted.srgbDistance(to: theme.tertiaryText),
                    0.05,
                    "Lane \(color.rawValue) (dark=\(dark)) header title must read as lane-tinted"
                )
            }
        }
    }

    func test_uncolored_and_active_lane_headers_keep_the_theme_title_colors() {
        let theme = makeTheme(dark: true, emphasis: .subtle)

        assertColorsEqual(
            SidebarWorklaneRowStyleResolver.topLabelTextColor(
                worklaneColor: nil,
                isActive: false,
                activeTextColor: theme.sidebarButtonActiveText,
                theme: theme
            ),
            theme.tertiaryText
        )
        // An active card already sits on a lane-tinted fill; tinting its title
        // as well would be the same signal three times over.
        assertColorsEqual(
            SidebarWorklaneRowStyleResolver.topLabelTextColor(
                worklaneColor: .red,
                isActive: true,
                activeTextColor: theme.sidebarButtonActiveText,
                theme: theme
            ),
            theme.sidebarButtonActiveText.withAlphaComponent(0.66)
        )
    }

    func test_row_paints_the_lane_header_rule() throws {
        let theme = makeTheme(dark: true, emphasis: .subtle)
        let row = makeRow(width: 280, height: 110)
        row.configure(
            with: makeSummary(color: .teal, topLabel: "peter@m1-pro-peter:~"),
            theme: theme,
            animated: false
        )

        let rule = try XCTUnwrap(row.debugSnapshotForTesting.headerRuleColor)
        let laneHue = try XCTUnwrap(hsbComponents(WorklaneColor.teal.tint(alpha: 1))).hue
        XCTAssertEqual(try XCTUnwrap(hsbComponents(rule)).hue, laneHue, accuracy: 0.02)
    }

    private func assertSubtleSelectedChromeIsIdentity(theme: ZenttyTheme) {
        let bg = NSColor(srgbRed: 0.11, green: 0.22, blue: 0.33, alpha: 0.88)
        let text = NSColor(srgbRed: 0.95, green: 0.96, blue: 0.97, alpha: 1)

        let chrome = SidebarWorklaneRowStyleResolver.selectedRowChrome(
            worklaneColor: .red,
            activeBackground: bg,
            activeText: text,
            theme: theme
        )

        assertColorsEqual(chrome.background, bg)
        assertColorsEqual(chrome.text, text.srgbClamped)
    }

    private func assertVividLaneChrome(theme: ZenttyTheme, color: WorklaneColor) throws {
        let chrome = SidebarWorklaneRowStyleResolver.selectedRowChrome(
            worklaneColor: color,
            activeBackground: theme.sidebarButtonActiveBackground,
            activeText: theme.sidebarButtonActiveText,
            theme: theme
        )

        let laneHue = try XCTUnwrap(hsbComponents(color.tint(alpha: 1))).hue
        let fillHue = try XCTUnwrap(hsbComponents(chrome.background)).hue
        XCTAssertEqual(fillHue, laneHue, accuracy: 0.06)

        // Fill reads as a real, near-opaque tint (not the low-alpha wash).
        XCTAssertGreaterThan(chrome.background.alphaComponent, 0.9)
    }

    private func makeTheme(
        dark: Bool,
        emphasis: AppConfig.Appearance.SidebarSelectionEmphasis
    ) -> ZenttyTheme {
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
            ),
            reduceTransparency: false,
            sidebarSelectionEmphasis: emphasis
        )
    }

    private func srgbDistance(_ lhs: NSColor, _ rhs: NSColor) -> CGFloat {
        let a = lhs.srgbClamped
        let b = rhs.srgbClamped
        let dr = a.redComponent - b.redComponent
        let dg = a.greenComponent - b.greenComponent
        let db = a.blueComponent - b.blueComponent
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    private func assertColorsEqual(
        _ lhs: NSColor,
        _ rhs: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let a = lhs.srgbClamped
        let b = rhs.srgbClamped
        XCTAssertEqual(a.redComponent, b.redComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(a.greenComponent, b.greenComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(a.blueComponent, b.blueComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(a.alphaComponent, b.alphaComponent, accuracy: 0.001, file: file, line: line)
    }

    private func makeRow(width: CGFloat = 280, height: CGFloat = 72) -> SidebarWorklaneRowButton {
        let row = SidebarWorklaneRowButton(
            worklaneID: WorklaneID("worklane-main"),
            reducedMotionProvider: { false }
        )
        row.frame = NSRect(x: 0, y: 0, width: width, height: height)
        row.widthAnchor.constraint(equalToConstant: width).isActive = true
        return row
    }

    private func makeSummary(
        color: WorklaneColor?,
        isActive: Bool = false,
        topLabel: String? = nil,
        statusText: String? = nil,
        paneRows: [WorklaneSidebarPaneRow] = [],
        attentionState: WorklaneAttentionState? = nil,
        taskProgress: PaneAgentTaskProgress? = nil,
        isWorking: Bool = false
    ) -> WorklaneSidebarSummary {
        WorklaneSidebarSummary(
            worklaneID: WorklaneID("worklane-main"),
            badgeText: "1",
            topLabel: topLabel,
            primaryText: "project",
            statusText: statusText,
            paneRows: paneRows,
            attentionState: attentionState,
            taskProgress: taskProgress,
            isWorking: isWorking,
            isActive: isActive,
            color: color
        )
    }

    private func makePaneRow(isFocused: Bool) -> WorklaneSidebarPaneRow {
        WorklaneSidebarPaneRow(
            paneID: PaneID("pane-agent"),
            primaryText: "Claude Code",
            trailingText: "main",
            detailText: ".../zentty",
            statusText: "Running",
            attentionState: .running,
            isFocused: isFocused,
            isWorking: true
        )
    }

    private func darkTheme(foreground: String) -> ZenttyTheme {
        ZenttyTheme(
            resolvedTheme: GhosttyResolvedTheme(
                background: NSColor(hexString: "#0A0C10")!,
                foreground: NSColor(hexString: foreground)!,
                cursorColor: NSColor(hexString: "#71B7FF")!,
                selectionBackground: nil,
                selectionForeground: nil,
                palette: [:],
                backgroundOpacity: 0.9,
                backgroundBlurRadius: 25
            )
        )
    }

    private func hsbComponents(_ color: NSColor) -> (
        hue: CGFloat,
        saturation: CGFloat,
        brightness: CGFloat,
        alpha: CGFloat
    )? {
        guard let converted = color.usingColorSpace(.deviceRGB) else {
            return nil
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        converted.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness, alpha)
    }

    private func statusShimmerBaseColor(_ theme: ZenttyTheme) -> NSColor {
        theme.statusRunning.adjustedHSB(
            saturationBy: 0.18,
            brightnessBy: 0.10
        )
    }
}
