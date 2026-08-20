import Foundation
import XCTest
@testable import MyQuickFinderKit

final class PathDisplayTests: XCTestCase {
    func testFilesystemRootIsNamedWithASlash() {
        XCTAssertEqual(PathDisplay.name(for: URL(fileURLWithPath: "/")), "/")
    }

    func testTrailingSlashDoesNotProduceAnEmptyName() {
        XCTAssertEqual(PathDisplay.name(for: URL(fileURLWithPath: "/usr/bin/")), "bin")
    }

    func testHomeItselfAbbreviatesToTilde() {
        let home = URL(fileURLWithPath: "/tmp/qf-home")
        XCTAssertEqual(PathDisplay.abbreviatingHome(home, home: home), "~")
    }

    func testPathInsideHomeKeepsItsRemainder() {
        let home = URL(fileURLWithPath: "/tmp/qf-home")
        let target = URL(fileURLWithPath: "/tmp/qf-home/Documents/notes")
        XCTAssertEqual(PathDisplay.abbreviatingHome(target, home: home), "~/Documents/notes")
    }

    func testSiblingHomeWithSharedPrefixIsNotAbbreviated() {
        let home = URL(fileURLWithPath: "/tmp/qf-home")
        let target = URL(fileURLWithPath: "/tmp/qf-homestead/Documents")
        XCTAssertEqual(
            PathDisplay.abbreviatingHome(target, home: home),
            "/tmp/qf-homestead/Documents"
        )
    }

    func testPathOutsideHomeStaysAbsolute() {
        let home = URL(fileURLWithPath: "/tmp/qf-home")
        let target = URL(fileURLWithPath: "/usr/local/bin")
        XCTAssertEqual(PathDisplay.abbreviatingHome(target, home: home), "/usr/local/bin")
    }
}
