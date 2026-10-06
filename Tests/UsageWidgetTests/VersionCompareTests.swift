import XCTest
@testable import UsageWidgetCore

final class VersionCompareTests: XCTestCase {

    // MARK: - components

    func testComponentsStripsLeadingV() {
        XCTAssertEqual(VersionCompare.components("v1.2.3"), [1, 2, 3])
    }

    func testComponentsWithoutV() {
        XCTAssertEqual(VersionCompare.components("1.2.3"), [1, 2, 3])
    }

    func testComponentsRejectsNonNumeric() {
        XCTAssertNil(VersionCompare.components("v1.2.0-beta"))
        XCTAssertNil(VersionCompare.components("not-a-version"))
        XCTAssertNil(VersionCompare.components(""))
    }

    // MARK: - isNewer

    func testIsNewerPatch() {
        XCTAssertTrue(VersionCompare.isNewer("v1.1.1", than: "v1.1.0"))
        XCTAssertFalse(VersionCompare.isNewer("v1.1.0", than: "v1.1.1"))
    }

    func testIsNewerComparesNumericallyNotLexically() {
        // "1.10.0" must beat "1.9.0" even though "1.10.0" < "1.9.0" as strings.
        XCTAssertTrue(VersionCompare.isNewer("v1.10.0", than: "v1.9.0"))
        XCTAssertFalse(VersionCompare.isNewer("v1.9.0", than: "v1.10.0"))
    }

    func testIsNewerHandlesMismatchedVPrefix() {
        XCTAssertTrue(VersionCompare.isNewer("v1.2.0", than: "1.1.0"))
    }

    func testIsNewerEqualVersionsIsFalse() {
        XCTAssertFalse(VersionCompare.isNewer("v1.1.0", than: "v1.1.0"))
    }

    func testIsNewerUnparsableIsFalse() {
        XCTAssertFalse(VersionCompare.isNewer("garbage", than: "v1.0.0"))
        XCTAssertFalse(VersionCompare.isNewer("v1.0.0", than: "garbage"))
    }

    // MARK: - latest

    func testLatestPicksHighest() {
        XCTAssertEqual(VersionCompare.latest(of: ["v1.0.0", "v1.2.0", "v1.1.0"]), "v1.2.0")
    }

    func testLatestIgnoresMalformedTags() {
        XCTAssertEqual(VersionCompare.latest(of: ["v1.0.0", "nightly", "v0.9.0"]), "v1.0.0")
    }

    func testLatestEmptyIsNil() {
        XCTAssertNil(VersionCompare.latest(of: []))
    }
}
