import Foundation
import XCTest
@testable import MyQuickFinderKit

final class BreadcrumbTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/tmp/qf-home")
    private let deepPath = "/tmp/qf-home/code-studio/Gallery/vendor/bundle/ruby/4.0.0/gems"
        + "/fastlane-2.238.0/fastlane/lib/fastlane/plugins/template/lib/fastlane/plugin/%plugin_name%/helper"

    func testHomeItselfCollapsesToTheRootAlone() {
        let crumb = Breadcrumb.make(for: home, home: home)
        XCTAssertEqual(crumb.root.name, "~")
        XCTAssertTrue(crumb.collapsed.isEmpty)
        XCTAssertTrue(crumb.trailing.isEmpty)
        XCTAssertEqual(crumb.current.name, "~")
        XCTAssertNil(crumb.parent)
    }

    func testGoingUpFromHomeLeavesHomeAndRerootsAtTheVolume() {
        XCTAssertEqual(Breadcrumb.parentDirectory(of: home)?.path, "/tmp")
        let crumb = Breadcrumb.make(for: URL(fileURLWithPath: "/tmp"), home: home)
        XCTAssertEqual(crumb.root.name, "/")
        XCTAssertEqual(crumb.trailing.map(\.name), ["tmp"])
    }

    func testTheVolumeRootHasNowhereLeftToGoUp() {
        XCTAssertNil(Breadcrumb.parentDirectory(of: URL(fileURLWithPath: "/")))
    }

    func testTwoLevelsStayFullyVisible() {
        let crumb = Breadcrumb.make(
            for: home.appending(path: "code-studio/Gallery"),
            home: home
        )
        XCTAssertFalse(crumb.isCollapsed)
        XCTAssertEqual(crumb.trailing.map(\.name), ["code-studio", "Gallery"])
    }

    func testDeepPathKeepsRootAndLastTwoSegments() {
        let crumb = Breadcrumb.make(for: URL(fileURLWithPath: deepPath), home: home)
        XCTAssertTrue(crumb.isCollapsed)
        XCTAssertEqual(crumb.root.name, "~")
        XCTAssertEqual(crumb.trailing.map(\.name), ["%plugin_name%", "helper"])
        XCTAssertEqual(crumb.collapsed.count, 16)
        XCTAssertEqual(crumb.current.name, "helper")
    }

    func testAncestorMenuIsOrderedShallowToDeepAndNumberedByLevel() {
        let crumb = Breadcrumb.make(for: URL(fileURLWithPath: deepPath), home: home)
        let ancestors = crumb.ancestors
        XCTAssertEqual(ancestors.count, 18)
        XCTAssertEqual(ancestors.first?.depth, 0)
        XCTAssertEqual(ancestors[1].name, "code-studio")
        XCTAssertEqual(ancestors[1].depth, 1)
        XCTAssertEqual(ancestors.map(\.depth), Array(0 ..< ancestors.count))
        XCTAssertEqual(ancestors.last?.name, "%plugin_name%")
    }

    func testEverySegmentCarriesTheURLItJumpsTo() {
        let crumb = Breadcrumb.make(
            for: home.appending(path: "code-studio/Gallery/vendor"),
            home: home
        )
        XCTAssertEqual(crumb.collapsed.first?.url.path, "/tmp/qf-home/code-studio")
        XCTAssertEqual(crumb.trailing.first?.url.path, "/tmp/qf-home/code-studio/Gallery")
        XCTAssertEqual(crumb.parent?.url.path, "/tmp/qf-home/code-studio/Gallery")
    }

    func testPathOutsideHomeIsRootedAtTheVolume() {
        let crumb = Breadcrumb.make(for: URL(fileURLWithPath: "/usr/bin"), home: home)
        XCTAssertEqual(crumb.root.name, "/")
        XCTAssertEqual(crumb.root.url.path, "/")
        XCTAssertEqual(crumb.trailing.map(\.name), ["usr", "bin"])
    }

    func testSiblingHomeWithSharedPrefixIsNotTreatedAsInsideHome() {
        let crumb = Breadcrumb.make(
            for: URL(fileURLWithPath: "/tmp/qf-homestead/Documents"),
            home: home
        )
        XCTAssertEqual(crumb.root.name, "/")
        XCTAssertEqual(crumb.trailing.map(\.name), ["qf-homestead", "Documents"])
    }
}
