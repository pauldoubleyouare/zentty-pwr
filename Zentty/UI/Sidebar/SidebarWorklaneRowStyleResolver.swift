import AppKit

enum SidebarWorklaneRowStyleResolver {
    /// Resolved selected-row chrome: the near-opaque fill and a legible
    /// active-text color for that fill. The row's stroke is not here — a lane's
    /// border is owned end to end by `groupBorder`, so there is exactly one
    /// place that decides how a card is fenced.
    struct SelectedRowChrome {
        let background: NSColor
        let text: NSColor
    }

    /// The stroke fencing one worklane's card — header plus every pane row that
    /// belongs to that lane — off from the lanes above and below it.
    struct GroupBorder: Equatable {
        let color: NSColor
        let width: CGFloat
        /// Neon bloom cast behind the card. `nil` for everything except an
        /// active, lane-colored card on a dark sidebar.
        let glow: NSColor?
    }

    /// Group-border geometry.
    ///
    /// The card's content inset (`SidebarWorklaneRowButton.Layout.contentInset`,
    /// 6pt) is what caps the stroke: a 3pt border would leave 3pt of clearance
    /// to a hovered pane row's fill and read as cramped. 2pt idle / 2.5pt active
    /// keeps the boundary unmistakable while leaving the pane rows room to
    /// breathe, and 2.5pt lands on a whole pixel at 2x.
    enum GroupBorderMetrics {
        static let idle: CGFloat = 2
        static let active: CGFloat = 2.5
    }

    /// Selected-row fill / text for the current emphasis mode.
    ///
    /// - `.subtle`, or `.vivid` without a worklane color: returns the theme's
    ///   accent-derived values untouched, so those paths stay byte-for-byte as
    ///   the core theme change produced them.
    /// - `.vivid` WITH a worklane color: rebuilds the vivid recipe around the
    ///   lane color so the selected row reads as clearly lane-tinted, mirroring
    ///   how the focused pane border prefers the worklane color over
    ///   `theme.paneBorderFocused` (see `PaneContainerView.applyVisualState`).
    ///   The text is re-guaranteed against the lane fill via
    ///   `ensuringTextContrast(on:)`.
    static func selectedRowChrome(
        worklaneColor: WorklaneColor?,
        activeBackground: NSColor,
        activeText: NSColor,
        theme: ZenttyTheme
    ) -> SelectedRowChrome {
        guard theme.sidebarSelectionEmphasis == .vivid, let worklaneColor else {
            return SelectedRowChrome(
                background: activeBackground,
                text: activeText
            )
        }

        let isDark = theme.sidebarGlassAppearance == .dark
        let sidebarSurface = theme.sidebarBackground.composited(
            over: theme.windowBackground
        )
        // Mirror AppTheme's vivid fill recipe, swapping the theme accent for the
        // lane color. Worklane colors are fixed, saturated hues that are never
        // ~= the sidebar surface, so the accent contrast-floor guard AppTheme
        // needs is unnecessary here.
        let laneFill = worklaneColor.tint(alpha: 1)
            .mixed(towards: sidebarSurface, amount: isDark ? 0.55 : 0.45)
            .withAlphaComponent(theme.reducedTransparency ? 0.96 : 0.92)
        let laneText = activeText.ensuringTextContrast(
            on: laneFill.composited(over: sidebarSurface)
        )
        return SelectedRowChrome(
            background: laneFill,
            text: laneText
        )
    }

    /// The lane-colored fence around a worklane card.
    ///
    /// Every card gets the same 2pt geometry so the sidebar always reads as a
    /// stack of discrete lanes rather than a run-on list; the lane color decides
    /// whether that fence is neon or neutral. Uncolored lanes fall back to the
    /// theme's row borders, which is the only thing that kept the boundary
    /// before — just drawn at the group weight instead of a hairline.
    ///
    /// Alpha is appearance-split (`Alpha.GroupBorder`) because the light hexes
    /// are deep rather than bright and need more weight to hold an edge.
    static func groupBorder(
        worklaneColor: WorklaneColor?,
        isActive: Bool,
        isHovered: Bool,
        isPaneRowHovered: Bool,
        activeBorder: NSColor,
        inactiveBorder: NSColor,
        theme: ZenttyTheme
    ) -> GroupBorder {
        let width = isActive ? GroupBorderMetrics.active : GroupBorderMetrics.idle

        guard let worklaneColor else {
            return GroupBorder(
                color: isActive ? activeBorder : inactiveBorder,
                width: width,
                glow: nil
            )
        }

        let isDark = theme.sidebarGlassAppearance == .dark
        let alpha: CGFloat
        if isActive {
            alpha = isDark ? WorklaneColor.Alpha.GroupBorder.activeDark
                : WorklaneColor.Alpha.GroupBorder.activeLight
        } else if isHovered && !isPaneRowHovered {
            alpha = isDark ? WorklaneColor.Alpha.GroupBorder.hoveredDark
                : WorklaneColor.Alpha.GroupBorder.hoveredLight
        } else {
            alpha = isDark ? WorklaneColor.Alpha.GroupBorder.idleDark
                : WorklaneColor.Alpha.GroupBorder.idleLight
        }

        // The bloom is what makes the stroke read as neon rather than as a
        // plain outline, but it only works against a dark surface — on light it
        // muddies the card edge, so light gets the stroke alone.
        let glow: NSColor?
        if isActive && isDark && theme.reducedTransparency == false {
            glow = worklaneColor.tint(alpha: WorklaneColor.Alpha.groupGlow)
        } else {
            glow = nil
        }

        return GroupBorder(
            color: worklaneColor.tint(alpha: alpha),
            width: width,
            glow: glow
        )
    }

    /// The rule under a lane header's title, tinted to the lane.
    ///
    /// This is the quiet half of the header tie-in: a 1pt rule carries the hue
    /// without competing with the title text sitting above it.
    static func headerRuleColor(
        worklaneColor: WorklaneColor?,
        theme: ZenttyTheme
    ) -> NSColor {
        guard let worklaneColor else {
            return theme.sidebarBorder
        }

        return worklaneColor.tint(alpha: WorklaneColor.Alpha.headerRule)
    }

    static func tintColor(
        worklaneColor: WorklaneColor?,
        isActive: Bool,
        isHovered: Bool,
        isPaneRowHovered: Bool
    ) -> CGColor {
        guard let worklaneColor else {
            return NSColor.clear.cgColor
        }

        let alpha: CGFloat
        if isActive {
            alpha = WorklaneColor.Alpha.active
        } else if isHovered && !isPaneRowHovered {
            alpha = WorklaneColor.Alpha.hover
        } else {
            alpha = WorklaneColor.Alpha.inactive
        }

        return worklaneColor.tint(alpha: alpha).cgColor
    }

    static func backgroundColor(
        isActive: Bool,
        isWorking: Bool,
        isHovered: Bool,
        isPaneRowHovered: Bool,
        activeBackground: NSColor,
        hoverBackground: NSColor,
        inactiveBackground: NSColor,
        theme: ZenttyTheme
    ) -> NSColor {
        if isActive {
            guard isWorking else {
                return activeBackground
            }

            return activeBackground
                .mixed(towards: theme.sidebarGradientStart.brightenedForLabel, amount: 0.12)
        }

        if isHovered && !isPaneRowHovered {
            return hoverBackground
        }

        return inactiveBackground
    }

    static func resolvedBackgroundColor(
        isActive: Bool,
        isWorking: Bool,
        isHovered: Bool,
        isPaneRowHovered: Bool,
        isReorderDragActive: Bool,
        activeBackground: NSColor,
        hoverBackground: NSColor,
        inactiveBackground: NSColor,
        theme: ZenttyTheme
    ) -> NSColor {
        let background = backgroundColor(
            isActive: isActive,
            isWorking: isWorking,
            isHovered: isHovered,
            isPaneRowHovered: isPaneRowHovered,
            activeBackground: activeBackground,
            hoverBackground: hoverBackground,
            inactiveBackground: inactiveBackground,
            theme: theme
        )
        guard isReorderDragActive else {
            return background
        }

        let sidebarSurface = theme.sidebarBackground.composited(
            over: theme.windowBackground
        )
        return background
            .composited(over: sidebarSurface)
            .srgbClamped
            .withAlphaComponent(1)
    }

    static func paneRowInteractionColors(
        worklaneColor: WorklaneColor?,
        theme: ZenttyTheme
    ) -> (hover: NSColor, pressed: NSColor) {
        if let worklaneColor {
            return (
                worklaneColor.tint(alpha: WorklaneColor.Alpha.paneRowHover),
                worklaneColor.tint(alpha: WorklaneColor.Alpha.paneRowPressed)
            )
        }

        return (
            theme.sidebarButtonHoverBackground.withAlphaComponent(0.5),
            theme.sidebarButtonHoverBackground.withAlphaComponent(0.7)
        )
    }

    static func primaryTextColor(
        isActive: Bool,
        activeTextColor: NSColor,
        inactiveTextColor: NSColor
    ) -> NSColor {
        isActive ? activeTextColor : inactiveTextColor
    }

    /// The lane header's title color.
    ///
    /// An **active** card already sits on a lane-tinted fill, so tinting its
    /// title too would be the third statement of the same fact — it keeps the
    /// theme's active text. An **idle** colored card pulls the lane hue into
    /// what is otherwise flat tertiary text, which is what ties the header to
    /// the border around it.
    ///
    /// The hue is mixed toward the tertiary text rather than used raw — a raw
    /// lane color reads as a swatch, not a label — and the result is then
    /// pushed to AA against the sidebar surface. A deep light-appearance hex
    /// blended with light-appearance tertiary text lands below 4.5:1 on its
    /// own, so the push is what makes the tie-in safe to ship on light.
    static func topLabelTextColor(
        worklaneColor: WorklaneColor? = nil,
        isActive: Bool,
        activeTextColor: NSColor,
        theme: ZenttyTheme
    ) -> NSColor {
        guard isActive == false, let worklaneColor else {
            return isActive ? activeTextColor.withAlphaComponent(0.66) : theme.tertiaryText
        }

        let sidebarSurface = theme.sidebarBackground.composited(
            over: theme.windowBackground
        )
        let tinted = theme.tertiaryText.mixed(
            towards: worklaneColor.tint(alpha: 1),
            amount: WorklaneColor.headerLabelTintAmount
        )
        return pushedToContrast(tinted, on: sidebarSurface, minimum: 4.5)
    }

    /// Walk a color away from a surface until it clears `minimum`.
    ///
    /// `NSColor.ensuringTextContrast` bails to near-white or near-black in one
    /// step, which would throw the lane hue away entirely. Stepping toward the
    /// same extreme instead keeps as much of the hue as the contrast budget
    /// allows, and always terminates: white on a dark surface (and black on a
    /// light one) clears any reachable minimum.
    private static func pushedToContrast(
        _ color: NSColor,
        on surface: NSColor,
        minimum: CGFloat
    ) -> NSColor {
        guard color.contrastRatio(against: surface) < minimum else {
            return color
        }

        let target: NSColor = surface.isDarkThemeColor ? .white : .black
        var amount: CGFloat = 0
        var candidate = color
        while amount < 1, candidate.contrastRatio(against: surface) < minimum {
            amount += 0.08
            candidate = color.mixed(towards: target, amount: min(amount, 1))
        }
        return candidate
    }

    static func overflowTextColor(
        isActive: Bool,
        activeTextColor: NSColor,
        theme: ZenttyTheme
    ) -> NSColor {
        isActive ? activeTextColor.withAlphaComponent(0.54) : theme.tertiaryText
    }

    static func detailTextColor(
        emphasis: WorklaneSidebarDetailEmphasis,
        isActive: Bool,
        theme: ZenttyTheme
    ) -> NSColor {
        switch emphasis {
        case .primary:
            return isActive
                ? theme.sidebarButtonActiveText.withAlphaComponent(0.78)
                : theme.secondaryText
        case .secondary:
            return isActive
                ? theme.sidebarButtonActiveText.withAlphaComponent(0.62)
                : theme.tertiaryText
        }
    }

    static func panePrimaryTextColor(
        isFocused: Bool,
        isActive: Bool,
        activeTextColor: NSColor,
        inactiveTextColor: NSColor,
        theme: ZenttyTheme
    ) -> NSColor {
        let focusedBaseColor = isActive ? activeTextColor : inactiveTextColor
        return isFocused ? focusedBaseColor : theme.secondaryText
    }

    static func paneTrailingTextColor(
        isFocused: Bool,
        isActive: Bool,
        activeTextColor: NSColor,
        inactiveTextColor: NSColor,
        theme: ZenttyTheme
    ) -> NSColor {
        let focusedBaseColor = isActive ? activeTextColor : inactiveTextColor
        return isFocused ? focusedBaseColor.withAlphaComponent(0.62) : theme.tertiaryText
    }

    static func paneDetailTextColor(
        isFocused: Bool,
        isWorking: Bool,
        isActive: Bool,
        activeTextColor: NSColor,
        inactiveTextColor: NSColor,
        theme: ZenttyTheme
    ) -> NSColor {
        let focusedBaseColor = isActive ? activeTextColor : inactiveTextColor
        if isWorking {
            let emphasis = workingTextHighlightColor(
                isActive: isActive,
                inactiveTextColor: inactiveTextColor
            )
            return isFocused ? emphasis.withAlphaComponent(0.68) : emphasis.withAlphaComponent(0.60)
        }

        return isFocused ? focusedBaseColor.withAlphaComponent(0.62) : theme.tertiaryText
    }

    static func statusTextColor(
        attentionState: WorklaneAttentionState?,
        theme: ZenttyTheme
    ) -> NSColor {
        switch attentionState {
        case .running:
            return theme.statusRunning
        case .needsInput:
            return theme.statusNeedsInput
        case .unresolvedStop:
            return theme.statusStopped
        case .ready:
            return theme.statusReady
        case nil:
            return theme.secondaryText
        }
    }

    static func statusShimmerBaseColor(
        statusColor: NSColor,
        theme: ZenttyTheme
    ) -> NSColor {
        if theme.sidebarGlassAppearance == .dark {
            return statusColor.adjustedHSB(
                saturationBy: 0.18,
                brightnessBy: 0.10
            )
        }

        return statusColor.adjustedHSB(
            saturationBy: 0.14,
            brightnessBy: -0.04
        )
    }

    static func shimmerColor(
        baseTextColor: NSColor,
        worklaneColor: WorklaneColor?,
        coloredEmphasis: SidebarShimmerColorResolver.ColoredEmphasis,
        treatment: SidebarShimmerColorResolver.Treatment,
        isActive: Bool,
        theme: ZenttyTheme
    ) -> NSColor {
        SidebarShimmerColorResolver.shimmerColor(
            baseTextColor: baseTextColor,
            worklaneColor: worklaneColor,
            coloredEmphasis: coloredEmphasis,
            treatment: treatment,
            isActive: isActive,
            theme: theme
        )
    }

    static func renderedBaseTextColor(
        _ textColor: NSColor,
        isShimmering: Bool,
        treatment: SidebarShimmerColorResolver.Treatment
    ) -> NSColor {
        guard isShimmering else {
            return textColor
        }

        switch treatment {
        case .highlight:
            return textColor.withAlphaComponent(textColor.alphaComponent * 0.78)
        case .shadow:
            return textColor
        }
    }

    private static func workingTextHighlightColor(
        isActive: Bool,
        inactiveTextColor: NSColor
    ) -> NSColor {
        if isActive {
            return .white
        }

        return inactiveTextColor.mixed(towards: .white, amount: 0.72)
    }
}
