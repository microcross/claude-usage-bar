import XCTest
import Foundation
@testable import UsageWidgetCore

final class UsageParserTests: XCTestCase {

    private func json(_ s: String) -> Any {
        try! JSONSerialization.jsonObject(with: Data(s.utf8))
    }

    private func dict(_ s: String) -> [String: Any] {
        json(s) as! [String: Any]
    }

    private func array(_ s: String) -> [[String: Any]] {
        json(s) as! [[String: Any]]
    }

    // MARK: - parseWindow

    func testParseWindowRealFixture() {
        let d = dict(#"{"utilization": 16, "resets_at": "2026-07-09T11:20:00.467057+00:00"}"#)
        let window = UsageParser.parseWindow(from: d)
        XCTAssertEqual(window?.utilizationPct, 16.0)
        XCTAssertNotNil(window?.resetsAt)
    }

    func testParseWindowFractionalSeconds() {
        let d = dict(#"{"utilization": 42.5, "resets_at": "2026-07-09T11:20:00.467057+00:00"}"#)
        let window = UsageParser.parseWindow(from: d)
        XCTAssertNotNil(window?.resetsAt, "fractional-seconds date must parse")
        XCTAssertEqual(window?.utilizationPct, 42.5)
    }

    func testParseWindowNonFractionalSeconds() {
        let d = dict(#"{"utilization": 10, "resets_at": "2026-07-09T11:20:00+00:00"}"#)
        let window = UsageParser.parseWindow(from: d)
        XCTAssertNotNil(window?.resetsAt, "non-fractional date must also parse")
    }

    func testParseWindowNilInput() {
        XCTAssertNil(UsageParser.parseWindow(from: nil))
    }

    func testParseWindowGarbageResetsAt() {
        let d = dict(#"{"utilization": 5, "resets_at": "not-a-date"}"#)
        let window = UsageParser.parseWindow(from: d)
        XCTAssertEqual(window?.utilizationPct, 5.0)
        XCTAssertNil(window?.resetsAt)
    }

    func testParseWindowMissingResetsAt() {
        let d = dict(#"{"utilization": 33}"#)
        let window = UsageParser.parseWindow(from: d)
        XCTAssertEqual(window?.utilizationPct, 33.0)
        XCTAssertNil(window?.resetsAt)
    }

    func testParseWindowMissingUtilizationDefaultsToZero() {
        let d = dict(#"{"resets_at": "2026-07-09T11:20:00.467057+00:00"}"#)
        let window = UsageParser.parseWindow(from: d)
        XCTAssertEqual(window?.utilizationPct, 0.0)
        XCTAssertNotNil(window?.resetsAt)
    }

    // MARK: - selectChatOrgUUID

    func testSelectChatOrgPrefersChatCapabilityNotFirst() {
        // API-only org FIRST, chat org SECOND -> must return the SECOND.
        let orgs = array(#"""
        [
          {"uuid": "api-org-uuid", "capabilities": ["api"]},
          {"uuid": "chat-org-uuid", "capabilities": ["chat", "claude_pro"]}
        ]
        """#)
        XCTAssertEqual(UsageParser.selectChatOrgUUID(from: orgs), "chat-org-uuid")
    }

    func testSelectChatOrgEmptyArray() {
        XCTAssertNil(UsageParser.selectChatOrgUUID(from: []))
    }

    func testSelectChatOrgFallbackToFirstWhenNoChat() {
        let orgs = array(#"[{"uuid": "only-org", "capabilities": ["api"]}]"#)
        XCTAssertEqual(UsageParser.selectChatOrgUUID(from: orgs), "only-org")
    }

    // MARK: - apiErrorMessage

    func testApiErrorMessageDetected() {
        let d = dict(#"{"type":"error","error":{"message":"Invalid authorization for organization"}}"#)
        XCTAssertEqual(UsageParser.apiErrorMessage(in: d), "Invalid authorization for organization")
    }

    func testApiErrorMessageDefaultWhenMissing() {
        let d = dict(#"{"type":"error"}"#)
        XCTAssertEqual(UsageParser.apiErrorMessage(in: d), "Session expired.")
    }

    func testApiErrorMessageNilForNormalPayload() {
        let d = dict(#"{"five_hour":{"utilization":16}}"#)
        XCTAssertNil(UsageParser.apiErrorMessage(in: d))
    }
}
