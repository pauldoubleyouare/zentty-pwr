import XCTest
@testable import Zentty

final class AgentIPCDiscoveryTests: XCTestCase {
    func test_agent_ipc_request_round_trips_discover_payload() throws {
        let request = AgentIPCRequest(
            id: "discover-1",
            kind: .discover,
            arguments: ["--window-id", "window-main"],
            standardInput: nil,
            environment: [:],
            expectsResponse: true,
            subcommand: "panes"
        )

        let decoded = try JSONDecoder().decode(
            AgentIPCRequest.self,
            from: try JSONEncoder().encode(request)
        )

        XCTAssertEqual(decoded, request)
    }

    func test_agent_ipc_response_round_trips_discovery_payloads() throws {
        let response = AgentIPCResponse(
            id: "discover-1",
            ok: true,
            result: AgentIPCResponseResult(
                discoveredWindows: [
                    DiscoveredWindow(
                        id: "wd_main",
                        order: 1,
                        isFocused: true,
                        worklaneCount: 2,
                        paneCount: 4
                    ),
                ],
                discoveredWorklanes: [
                    DiscoveredWorklane(
                        id: "wl_main",
                        windowID: "wd_main",
                        order: 1,
                        title: nil,
                        isFocused: true,
                        paneCount: 2,
                        columnCount: 1,
                        focusedPaneID: "pn_main"
                    ),
                ],
                discoveredPanes: [
                    DiscoveredPane(
                        id: "pn_main",
                        windowID: "wd_main",
                        worklaneID: "wl_main",
                        index: 1,
                        column: 1,
                        title: "shell",
                        workingDirectory: "/tmp/project",
                        isFocused: true,
                        agentTool: "Codex",
                        agentStatus: "running",
                        controlToken: "pane-token"
                    ),
                ]
            )
        )

        let decoded = try JSONDecoder().decode(
            AgentIPCResponse.self,
            from: try JSONEncoder().encode(response)
        )

        XCTAssertEqual(decoded, response)
    }

    func test_agent_ipc_authentication_accepts_discovered_pane_token() {
        let authentication = AgentIPCAuthentication(secret: "unit-test-secret")
        let target = AgentIPCTarget(
            windowID: WindowID("window-main"),
            worklaneID: WorklaneID("worklane-main"),
            paneID: PaneID("pane-main")
        )

        let token = authentication.token(
            windowID: target.windowID,
            worklaneID: target.worklaneID,
            paneID: target.paneID
        )

        XCTAssertTrue(authentication.isValid(
            token: token,
            windowID: target.windowID,
            worklaneID: target.worklaneID,
            paneID: target.paneID
        ))
        XCTAssertFalse(authentication.isValid(
            token: token,
            windowID: target.windowID,
            worklaneID: target.worklaneID,
            paneID: PaneID("pane-other")
        ))
    }
}

/// Covers the JSON contract that `zentty ... --json` publishes to external
/// tools: every key always present, and nothing truncated. The human tables
/// truncate titles to 16 characters and print no pane ID, so JSON is the only
/// surface that can answer "what is the current title of pane pn_XYZ".
final class DiscoveryJSONEntryTests: XCTestCase {
    /// A title far longer than the 16-character TITLE column in the tables and
    /// the 42-character cap in the `zentty list` tree.
    private static let longTitle =
        "claude — refactor WorklaneStore pane identity minting and backfill the "
        + "closed-pane restore stack so titles survive a relaunch"

    private func pane(
        id: String = "pn_alpha",
        title: String = "shell",
        workingDirectory: String? = "/tmp/project",
        agentTool: String? = "claude",
        agentStatus: String? = "working",
        controlToken: String? = nil
    ) -> DiscoveredPane {
        DiscoveredPane(
            id: id,
            windowID: "wd_main",
            worklaneID: "wl_main",
            index: 2,
            column: 1,
            title: title,
            workingDirectory: workingDirectory,
            isFocused: true,
            agentTool: agentTool,
            agentStatus: agentStatus,
            controlToken: controlToken
        )
    }

    private func encodedObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func encodedArray(_ value: some Encodable) throws -> [[String: Any]] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )
    }

    // MARK: - Panes

    func test_pane_json_entry_never_truncates_the_title() throws {
        let object = try encodedObject(
            PaneJSONEntry(pane: pane(title: Self.longTitle))
        )

        XCTAssertEqual(object["title"] as? String, Self.longTitle)
        XCTAssertGreaterThan(Self.longTitle.count, 42)
    }

    func test_pane_json_entry_carries_the_raw_pane_worklane_and_window_ids() throws {
        let object = try encodedObject(PaneJSONEntry(pane: pane(id: "pn_7f3c1a")))

        XCTAssertEqual(object["id"] as? String, "pn_7f3c1a")
        XCTAssertEqual(object["worklaneID"] as? String, "wl_main")
        XCTAssertEqual(object["windowID"] as? String, "wd_main")
    }

    func test_pane_json_entry_exposes_cwd_agent_and_status() throws {
        let object = try encodedObject(PaneJSONEntry(pane: pane()))

        XCTAssertEqual(object["cwd"] as? String, "/tmp/project")
        XCTAssertEqual(object["agent"] as? String, "claude")
        XCTAssertEqual(object["status"] as? String, "working")

        // The wire-type spellings stay in place so existing
        // `zentty pane list --json` consumers keep working.
        XCTAssertEqual(object["workingDirectory"] as? String, "/tmp/project")
        XCTAssertEqual(object["agentTool"] as? String, "claude")
        XCTAssertEqual(object["agentStatus"] as? String, "working")
    }

    func test_pane_json_entry_emits_null_rather_than_dropping_absent_keys() throws {
        let object = try encodedObject(
            PaneJSONEntry(
                pane: pane(
                    workingDirectory: nil,
                    agentTool: nil,
                    agentStatus: nil,
                    controlToken: nil
                )
            )
        )

        let expectedKeys: Set<String> = [
            "id", "windowID", "worklaneID", "index", "column", "title",
            "cwd", "workingDirectory", "isFocused",
            "agent", "agentTool", "status", "agentStatus", "controlToken",
        ]
        XCTAssertEqual(Set(object.keys), expectedKeys)

        for key in ["cwd", "workingDirectory", "agent", "agentTool", "status", "agentStatus", "controlToken"] {
            XCTAssertTrue(object[key] is NSNull, "\(key) should encode as null, not be omitted")
        }
    }

    func test_pane_json_entry_keeps_an_empty_title_as_an_empty_string() throws {
        let object = try encodedObject(PaneJSONEntry(pane: pane(title: "")))

        XCTAssertEqual(object["title"] as? String, "")
    }

    /// The acceptance case: one command, parse JSON, map a `pn_…` ID to its
    /// current full title.
    func test_pane_id_resolves_to_its_full_title_in_encoded_list_output() throws {
        let panes = [
            pane(id: "pn_aaa", title: "left"),
            pane(id: "pn_XYZ", title: Self.longTitle),
            pane(id: "pn_zzz", title: "right"),
        ].map(PaneJSONEntry.init(pane:))

        let objects = try encodedArray(panes)
        let match = try XCTUnwrap(objects.first { $0["id"] as? String == "pn_XYZ" })

        XCTAssertEqual(match["title"] as? String, Self.longTitle)
    }

    // MARK: - Worklanes

    func test_worklane_json_entry_carries_the_raw_id_and_full_title() throws {
        let object = try encodedObject(
            WorklaneJSONEntry(
                worklane: DiscoveredWorklane(
                    id: "wl_4c2e",
                    windowID: "wd_main",
                    order: 1,
                    title: Self.longTitle,
                    isFocused: true,
                    paneCount: 3,
                    columnCount: 2,
                    focusedPaneID: "pn_alpha"
                )
            )
        )

        XCTAssertEqual(object["id"] as? String, "wl_4c2e")
        XCTAssertEqual(object["title"] as? String, Self.longTitle)
    }

    func test_worklane_json_entry_emits_null_rather_than_dropping_absent_keys() throws {
        let object = try encodedObject(
            WorklaneJSONEntry(
                worklane: DiscoveredWorklane(
                    id: "wl_4c2e",
                    windowID: "wd_main",
                    order: 1,
                    title: nil,
                    isFocused: false,
                    paneCount: 0,
                    columnCount: 1,
                    focusedPaneID: nil
                )
            )
        )

        let expectedKeys: Set<String> = [
            "id", "windowID", "order", "title",
            "isFocused", "paneCount", "columnCount", "focusedPaneID",
        ]
        XCTAssertEqual(Set(object.keys), expectedKeys)
        XCTAssertTrue(object["title"] is NSNull)
        XCTAssertTrue(object["focusedPaneID"] is NSNull)
    }
}
