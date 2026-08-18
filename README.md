<!-- LOGO -->
<h1>
<p align="center">
  <img src="assets/icon-pwr.png" alt="Zentty PWR" width="128">
  <br>Zentty PWR
</h1>
  <p align="center">
    A personal fork of <a href="https://github.com/dedene/zentty">Zentty</a>, the native macOS terminal for agent-driven development.
    <br />
    Same app underneath. A few changes that matter to one workflow.
    <br />
    <a href="#whats-different-here">What's different</a>
    ·
    <a href="#build">Build</a>
    ·
    <a href="#upstream">Upstream</a>
  </p>
</p>

> Not a product, and not a competing distribution. This exists so one person's
> machines can run the same customized build. Everything good here is Zentty's;
> see [Upstream](#upstream) for credit and [License](#license) for terms.

## What's different here

- **Worklane borders.** Each worklane group is outlined with a 2-3px border in its own color, so lane boundaries read at a glance instead of blending into one long list.
- **Neon worklane palette.** Higher-chroma complementary colors, with saturation and luminance adjusted per light/dark appearance so they stay legible either way.
- **`--json` actually works on `list` commands.** Upstream accepts the flag but the parent command consumed it before the subcommand could see it, so the human table printed regardless. Fixed by sharing one options group instead of declaring the flag twice.
- **Pane and worklane JSON carry stable identity.** Each object now includes its raw ID plus the full, untruncated title, so an external tool can resolve a pane ID to its current title. The human tables still truncate, as before.
- **Distinct name and icon.** The app installs as `Zentty-PWR.app` and ships its own icon, so it is never confused with an upstream install. The bundle identifier is deliberately unchanged, which keeps existing worklane and session state intact.

Everything else, including features, keybindings and behavior, is upstream Zentty. See the [upstream README](https://github.com/dedene/zentty#readme) for the full feature list, and [Zentty CLI](docs/cli.md) for command-line usage.

## Install

No releases are published here. Build from source:

```bash
git clone https://github.com/pauldoubleyouare/zentty-pwr.git
cd zentty-pwr
./scripts/build_ghosttykit.sh
xcodebuild -scheme Zentty -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build build \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
./scripts/install_to_applications.sh
```

Building locally matters: a copied `.app` picks up a quarantine flag and gets blocked, while one you build yourself does not.

Unlike upstream, these builds are not notarized, and Sparkle auto-update is not configured. Pull and rebuild to update.

### Permission prompts and the signing identity

macOS keys permission grants (Desktop, Documents, Downloads, Full Disk Access, Accessibility) to an app's code signature. `xcodebuild` produces an ad-hoc signature, which has no stable identity, so every rebuild looks like a brand-new app and macOS re-prompts for everything. Terminal apps hit this hard: every permission a session or hook needs comes back after each build.

`scripts/install_to_applications.sh` fixes that by signing each build with the same local certificate before it lands in `/Applications`. Create the certificate once:

1. Open Keychain Access.
2. Menu: Keychain Access > Certificate Assistant > Create a Certificate.
3. Name: `Zentty PWR Local`. Identity Type: Self Signed Root. Certificate Type: Code Signing.
4. Create, then Done.

The script refuses to run if the certificate is missing. Set `SIGN_IDENTITY` to use a different name, or a real Developer ID if you have one. The previous install is kept at `/Applications/Zentty-PWR.app.previous`.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode
- `zig` on `PATH`
- `gettext` on `PATH`

## Build

Zentty requires a local `GhosttyKit.xcframework` before the app can build normally.

Build the framework:

```bash
./scripts/build_ghosttykit.sh
```

Then build the app:

```bash
xcodebuild -project Zentty.xcodeproj -scheme Zentty -destination 'platform=macOS' build
```

If you need to regenerate the Xcode project from [`project.yml`](project.yml):

```bash
bundle exec fastlane mac generate_project
```

More detail about the Ghostty bootstrap flow lives in [`docs/ghosttykit-setup.md`](docs/ghosttykit-setup.md).

## Test

Run the full test suite:

```bash
ZENTTY_TEST_DISPLAY_PROVIDER=betterdisplay scripts/test-on-virtual-display
```

Note: several tests assert against the upstream maintainer's home directory and
fail anywhere else. They fail on a clean checkout of upstream too, so treat that
set as a known-red baseline rather than a regression.

## Upstream

Zentty is built and maintained by [Peter Dedene](https://github.com/dedene) and Zenjoy BV. The worklane model, the Ghostty integration, the agent-status sidebar, and effectively all of the engineering are theirs. This fork is a thin layer on top.

To pull upstream changes in:

```bash
git remote add upstream https://github.com/dedene/zentty.git
git fetch upstream
git merge upstream/main
```

Changes here that are generally useful get sent back as pull requests rather than kept private.

## License

GNU General Public License v3.0 only (`GPL-3.0-only`), inherited from upstream. See [`LICENSE`](LICENSE).

If your organization cannot or does not want to comply with GPLv3, alternative commercial licensing may be available from Zenjoy BV. Contact `hallo@zenjoy.be`.

## Trademarks

The GPL covers the code, not the branding. Per [`TRADEMARKS.md`](TRADEMARKS.md), the Zentty name, logo and icons are not licensed for redistribution.

This fork ships its own icon and installs under its own app name for that reason. It is a personal build, not a distribution, and it is not affiliated with or endorsed by Zenjoy BV.
