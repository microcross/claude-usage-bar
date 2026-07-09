import XCTest
import AppKit
import SwiftUI
@testable import UsageWidgetUI

final class DonutViewColorTests: XCTestCase {
    func testColorThresholds() {
        XCTAssertEqual(DonutView.color(for: 0), .green)
        XCTAssertEqual(DonutView.color(for: 49), .green)
        XCTAssertEqual(DonutView.color(for: 50), .yellow)
        XCTAssertEqual(DonutView.color(for: 79), .yellow)
        XCTAssertEqual(DonutView.color(for: 80), .red)
        XCTAssertEqual(DonutView.color(for: 100), .red)
    }
}

final class MenuBarIconTests: XCTestCase {
    private func assertValidImage(_ image: NSImage) {
        XCTAssertTrue(image.isTemplate)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testImageNilNil() {
        assertValidImage(MenuBarIcon.image(session: nil, weekly: nil))
    }

    func testImageMixed() {
        assertValidImage(MenuBarIcon.image(session: 16, weekly: 52))
    }

    func testImageZeros() {
        assertValidImage(MenuBarIcon.image(session: 0, weekly: 0))
    }

    func testImageFull() {
        assertValidImage(MenuBarIcon.image(session: 100, weekly: 100))
    }
}

final class SessionKeyStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionKeyStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRoundtrip() {
        let url = tempDir.appendingPathComponent("session_key")
        SessionKeyStore.write("abc123", to: url)
        XCTAssertEqual(SessionKeyStore.read(from: url), "abc123")
    }

    func testReadMissingFileReturnsNil() {
        let url = tempDir.appendingPathComponent("does_not_exist")
        XCTAssertNil(SessionKeyStore.read(from: url))
    }

    func testWhitespaceTrimmed() {
        let url = tempDir.appendingPathComponent("session_key")
        SessionKeyStore.write("  spaced-key\n\n", to: url)
        XCTAssertEqual(SessionKeyStore.read(from: url), "spaced-key")
    }

    func testEmptyContentReturnsNil() {
        let url = tempDir.appendingPathComponent("session_key")
        SessionKeyStore.write("   \n", to: url)
        XCTAssertNil(SessionKeyStore.read(from: url))
    }
}
