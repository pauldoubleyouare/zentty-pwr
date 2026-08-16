import Foundation

enum AgentIPCProtocol {
    static let version = 1
    static let selfPIDPlaceholder = "__ZENTTY_SELF_PID__"
    /// Read timeout (seconds) the wrapper uses while blocked on the phase-2
    /// `awaitConsent` response. The app must resolve the consent panel and write
    /// its reply strictly before this elapses; the app-side wait stays below it
    /// by `consentPanelTimeoutMargin`. Shared so the two values can't drift into
    /// an inverted ordering across the app/CLI targets.
    static let awaitConsentTimeoutSeconds = 300
    /// Seconds the app-side consent wait stays below the wrapper timeout.
    static let consentPanelTimeoutMargin = 30
}

/// Filesystem roots holding Zentty's per-process runtime state: the IPC socket
/// and the ephemeral agent home overlays underneath it (`launch/…`).
///
/// Lives here, next to the other app/CLI shared constants, because both targets
/// need to recognise such a path after the fact: when a stale overlay directory
/// leaks into an agent's environment (`KIMI_CODE_HOME`, `CODEX_HOME`) it must be
/// rejected rather than mistaken for the user's real home.
enum ZenttyRuntimePaths {
    /// Current root, relative to the user's home: `~/.config/zentty/run`.
    /// Deliberately *not* under `~/Library/Caches`, which the OS and cleaner
    /// utilities are entitled to empty at any moment — including out from under
    /// a running instance, which silently severs every pane's connection to the
    /// app until it restarts.
    static let currentRootComponents = [".config", "zentty", "run"]

    /// The pre-relocation root. Still matched so overlay paths captured by a
    /// long-lived agent process before the move are still recognised as ours.
    static let legacyRootComponents = ["Library", "Caches", "Zentty"]

    /// The directory holding this machine's runtime state. Callers build the
    /// real root through here so it cannot drift from the substring used by
    /// `isRuntimeOverlayPath` — a drift would silently stop stale overlays from
    /// being recognised, with no failing build to catch it.
    static func currentRootURL(homeDirectory: URL) -> URL {
        url(under: homeDirectory, components: currentRootComponents)
    }

    static func legacyRootURL(homeDirectory: URL) -> URL {
        url(under: homeDirectory, components: legacyRootComponents)
    }

    static func isRuntimeOverlayPath(_ path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        return standardized.range(of: matchFragment(for: currentRootComponents)) != nil
            || standardized.range(of: matchFragment(for: legacyRootComponents)) != nil
    }

    private static func url(under homeDirectory: URL, components: [String]) -> URL {
        components.reduce(homeDirectory) { $0.appendingPathComponent($1, isDirectory: true) }
    }

    private static func matchFragment(for components: [String]) -> String {
        "/" + components.joined(separator: "/") + "/"
    }
}

enum AgentIPCRequestKind: String, Codable, Equatable {
    case ipc
    case bootstrap
    case pane
    case discover
    case server
    case tmuxCompat = "tmux_compat"
    /// Second phase of the integration-consent handshake. After a `bootstrap`
    /// response carries `consentRequired`, the wrapper re-issues an
    /// `awaitConsent` request (with a long read timeout) that the app holds
    /// open while the consent panel is shown, then answers with the resolved
    /// launch plan. See AgentIntegrationConsent + the IPC handler.
    case awaitConsent = "await_consent"
}

enum AgentBootstrapTool: String, Codable, Equatable, CaseIterable {
    case amp
    case claude
    case codex
    case copilot
    case cursor
    case droid
    case gemini
    case kimi
    case opencode
    case pi
    case omp
    case grok
    case agy
    case hermes
    case vibe
    case smallHarness = "small-harness"

    /// Names of the real CLI binary (or binaries) this wrapped tool resolves to on PATH.
    /// For most tools this matches `rawValue`, but cursor's CLI is shipped as `cursor-agent`
    /// (with `agent` as a user-facing alias) while `cursor` itself is the IDE launcher.
    var realBinaryNames: [String] {
        switch self {
        case .cursor:
            return ["cursor-agent"]
        case .amp, .claude, .codex, .copilot, .droid, .gemini, .opencode, .pi, .omp, .grok, .agy, .hermes, .smallHarness:
            return [rawValue]
        case .kimi:
            return [rawValue, "kimi-cli"]
        case .vibe:
            return [rawValue, "mistral-vibe"]
        }
    }

    /// The wrapped agent whose real binary matches the leading token of a shell
    /// command, or `nil` if the command isn't one of our agent CLIs. Mirrors how
    /// the PATH wrapper itself decides a command is an agent (binary-name match),
    /// so a restored pane is treated as an "agent pane" iff its command would
    /// actually trip the wrapper.
    static func wrappedAgent(forCommand command: String) -> AgentBootstrapTool? {
        guard let binaryName = wrappedAgentBinaryName(forCommand: command) else { return nil }
        return allCases.first { $0.realBinaryNames.contains(binaryName) }
    }

    private static func wrappedAgentBinaryName(forCommand command: String) -> String? {
        let words = shellWords(from: command)
        guard var executable = words.first else { return nil }

        if (executable as NSString).lastPathComponent == "env" {
            guard let envExecutable = words.dropFirst().first(where: { !isEnvironmentAssignment($0) }) else {
                return nil
            }
            executable = envExecutable
        }

        return (executable as NSString).lastPathComponent
    }

    private static func isEnvironmentAssignment(_ word: String) -> Bool {
        guard let equalsIndex = word.firstIndex(of: "="),
              equalsIndex > word.startIndex
        else { return false }

        let name = word[..<equalsIndex]
        guard let first = name.first,
              first == "_" || first.isLetter
        else { return false }

        return name.allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
    }

    /// Minimal shell-word splitting for restored launch commands. It is not a full
    /// shell parser; it only preserves quoted whitespace well enough to skip
    /// `env NAME=value` prefixes and inspect the real executable token.
    private static func shellWords(from command: String) -> [String] {
        enum Quote {
            case none
            case single
            case double
        }

        var words: [String] = []
        var current = ""
        var hasCurrentWord = false
        var quote: Quote = .none
        var isEscaped = false

        for character in command {
            if isEscaped {
                current.append(character)
                hasCurrentWord = true
                isEscaped = false
                continue
            }

            switch quote {
            case .none:
                if character == "\\" {
                    isEscaped = true
                    hasCurrentWord = true
                } else if character == "'" {
                    quote = .single
                    hasCurrentWord = true
                } else if character == "\"" {
                    quote = .double
                    hasCurrentWord = true
                } else if character.isWhitespace {
                    if hasCurrentWord {
                        words.append(current)
                        current = ""
                        hasCurrentWord = false
                    }
                } else {
                    current.append(character)
                    hasCurrentWord = true
                }
            case .single:
                if character == "'" {
                    quote = .none
                } else {
                    current.append(character)
                }
            case .double:
                if character == "\"" {
                    quote = .none
                } else if character == "\\" {
                    isEscaped = true
                } else {
                    current.append(character)
                }
            }
        }

        if isEscaped {
            current.append("\\")
        }
        if hasCurrentWord {
            words.append(current)
        }
        return words
    }
}

struct AgentIPCRequest: Codable, Equatable {
    let version: Int
    let id: String
    let kind: AgentIPCRequestKind
    let arguments: [String]
    let standardInput: String?
    let environment: [String: String]
    let expectsResponse: Bool
    let subcommand: String?
    let tool: AgentBootstrapTool?

    init(
        version: Int = AgentIPCProtocol.version,
        id: String = UUID().uuidString,
        kind: AgentIPCRequestKind,
        arguments: [String],
        standardInput: String?,
        environment: [String: String],
        expectsResponse: Bool,
        subcommand: String? = nil,
        tool: AgentBootstrapTool? = nil
    ) {
        self.version = version
        self.id = id
        self.kind = kind
        self.arguments = arguments
        self.standardInput = standardInput
        self.environment = environment
        self.expectsResponse = expectsResponse
        self.subcommand = subcommand
        self.tool = tool
    }

}

struct AgentLaunchAction: Codable, Equatable {
    let subcommand: String
    let arguments: [String]
    let standardInput: String?
}

struct AgentLaunchPlan: Codable, Equatable {
    let executablePath: String
    let arguments: [String]
    let setEnvironment: [String: String]
    let unsetEnvironment: [String]
    let preLaunchActions: [AgentLaunchAction]
}

struct PaneListEntry: Codable, Equatable {
    let index: Int
    let id: String
    let column: Int
    let title: String
    let workingDirectory: String?
    let isFocused: Bool
    let agentTool: String?
    let agentStatus: String?
}

struct DiscoveredWindow: Codable, Equatable {
    let id: String
    let order: Int
    let isFocused: Bool
    let worklaneCount: Int
    let paneCount: Int
}

struct DiscoveredWorklane: Codable, Equatable {
    let id: String
    let windowID: String
    let order: Int
    let title: String?
    let isFocused: Bool
    let paneCount: Int
    let columnCount: Int
    let focusedPaneID: String?
}

struct DiscoveredPane: Codable, Equatable {
    let id: String
    let windowID: String
    let worklaneID: String
    let index: Int
    let column: Int
    let title: String
    let workingDirectory: String?
    let isFocused: Bool
    let agentTool: String?
    let agentStatus: String?
    let controlToken: String?
}

// MARK: - CLI JSON Output

/// One pane in the JSON emitted by the `--json` discovery commands
/// (`zentty list`, `zentty list panes`, `zentty pane list`).
///
/// Separate from `DiscoveredPane` — the IPC wire type — because the CLI's JSON
/// is a contract for external tools and carries two guarantees the wire type
/// does not:
///
/// 1. **Every key is always present.** Synthesized `Codable` drops `nil`
///    optionals, so a consumer would see keys appear and disappear between
///    runs. This type encodes `null` instead.
/// 2. **Nothing is truncated.** `title` is the full pane title, however long;
///    the human-readable tables truncate, JSON never does.
///
/// `cwd` / `agent` / `status` are the names external tools address; the longer
/// `workingDirectory` / `agentTool` / `agentStatus` keep the wire-type spelling
/// so existing `zentty pane list --json` consumers keep working. Each pair
/// always carries the same value.
struct PaneJSONEntry: Encodable, Equatable {
    let id: String
    let windowID: String
    let worklaneID: String
    let index: Int
    let column: Int
    /// Full pane title, never truncated. Empty when the pane has no title.
    let title: String
    let cwd: String?
    let isFocused: Bool
    let agent: String?
    let status: String?
    let controlToken: String?

    init(pane: DiscoveredPane) {
        id = pane.id
        windowID = pane.windowID
        worklaneID = pane.worklaneID
        index = pane.index
        column = pane.column
        title = pane.title
        cwd = pane.workingDirectory
        isFocused = pane.isFocused
        agent = pane.agentTool
        status = pane.agentStatus
        controlToken = pane.controlToken
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case windowID
        case worklaneID
        case index
        case column
        case title
        case cwd
        case workingDirectory
        case isFocused
        case agent
        case agentTool
        case status
        case agentStatus
        case controlToken
    }

    // Written by hand rather than synthesized: the synthesized encoder uses
    // `encodeIfPresent` for optionals and would omit the key entirely.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(windowID, forKey: .windowID)
        try container.encode(worklaneID, forKey: .worklaneID)
        try container.encode(index, forKey: .index)
        try container.encode(column, forKey: .column)
        try container.encode(title, forKey: .title)
        try container.encode(cwd, forKey: .cwd)
        try container.encode(cwd, forKey: .workingDirectory)
        try container.encode(isFocused, forKey: .isFocused)
        try container.encode(agent, forKey: .agent)
        try container.encode(agent, forKey: .agentTool)
        try container.encode(status, forKey: .status)
        try container.encode(status, forKey: .agentStatus)
        try container.encode(controlToken, forKey: .controlToken)
    }
}

/// One worklane in the JSON emitted by the `--json` discovery commands
/// (`zentty list worklanes`, `zentty worklane list`). Same two guarantees as
/// `PaneJSONEntry`: every key present, `title` never truncated.
struct WorklaneJSONEntry: Encodable, Equatable {
    let id: String
    let windowID: String
    let order: Int
    /// Full worklane title, never truncated. `null` when the worklane has none.
    let title: String?
    let isFocused: Bool
    let paneCount: Int
    let columnCount: Int
    let focusedPaneID: String?

    init(worklane: DiscoveredWorklane) {
        id = worklane.id
        windowID = worklane.windowID
        order = worklane.order
        title = worklane.title
        isFocused = worklane.isFocused
        paneCount = worklane.paneCount
        columnCount = worklane.columnCount
        focusedPaneID = worklane.focusedPaneID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case windowID
        case order
        case title
        case isFocused
        case paneCount
        case columnCount
        case focusedPaneID
    }

    // Hand-written for the same reason as `PaneJSONEntry.encode(to:)`.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(windowID, forKey: .windowID)
        try container.encode(order, forKey: .order)
        try container.encode(title, forKey: .title)
        try container.encode(isFocused, forKey: .isFocused)
        try container.encode(paneCount, forKey: .paneCount)
        try container.encode(columnCount, forKey: .columnCount)
        try container.encode(focusedPaneID, forKey: .focusedPaneID)
    }
}

struct ServerListEntry: Codable, Equatable {
    let id: String
    let origin: String
    let url: String
    let display: String
    let worklaneID: String
    let paneID: String?
    let source: String
    let ports: [Int]
    let confidence: String
    let updatedAt: String
    /// Relevance tier: "primary", "shown", or "hidden". Optional for decode
    /// tolerance across version-skewed app/CLI pairs (added in response v2).
    let tier: String?
    /// Relevance reasons, e.g. ["ignored_port:9229", "running_pane"] (v2).
    let reasons: [String]?
}

struct ServerListResult: Codable, Equatable {
    let version: Int
    let primaryServerID: String?
    let servers: [ServerListEntry]
}

struct AgentIPCResponseResult: Codable, Equatable {
    let launchPlan: AgentLaunchPlan?
    let paneList: [PaneListEntry]?
    let discoveredWindows: [DiscoveredWindow]?
    let discoveredWorklanes: [DiscoveredWorklane]?
    let discoveredPanes: [DiscoveredPane]?
    let serverState: ServerListResult?
    /// Optional text payload returned from tmux-compat subcommands like
    /// `capture-pane`, `list-panes`, `display-message`. The CLI writes this
    /// directly to stdout.
    let stdout: String?
    /// Set on a `bootstrap` response when the agent's integration needs
    /// first-run consent before its hooks may be written to the user's config.
    /// The wrapper, on seeing this, re-issues an `awaitConsent` request that
    /// blocks (long timeout) until the user answers the consent panel. Optional
    /// for decode tolerance across version-skewed app/CLI pairs.
    let consentRequired: Bool?

    init(
        launchPlan: AgentLaunchPlan? = nil,
        paneList: [PaneListEntry]? = nil,
        discoveredWindows: [DiscoveredWindow]? = nil,
        discoveredWorklanes: [DiscoveredWorklane]? = nil,
        discoveredPanes: [DiscoveredPane]? = nil,
        serverState: ServerListResult? = nil,
        stdout: String? = nil,
        consentRequired: Bool? = nil
    ) {
        self.launchPlan = launchPlan
        self.paneList = paneList
        self.discoveredWindows = discoveredWindows
        self.discoveredWorklanes = discoveredWorklanes
        self.discoveredPanes = discoveredPanes
        self.serverState = serverState
        self.stdout = stdout
        self.consentRequired = consentRequired
    }
}

struct AgentIPCResponseError: Codable, Equatable {
    let code: String
    let message: String
}

struct AgentIPCResponse: Codable, Equatable {
    let version: Int
    let id: String
    let ok: Bool
    let result: AgentIPCResponseResult?
    let error: AgentIPCResponseError?

    init(
        version: Int = AgentIPCProtocol.version,
        id: String,
        ok: Bool,
        result: AgentIPCResponseResult? = nil,
        error: AgentIPCResponseError? = nil
    ) {
        self.version = version
        self.id = id
        self.ok = ok
        self.result = result
        self.error = error
    }
}
