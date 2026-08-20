import XCTest
@testable import MyQuickFinder

final class PanelGeometryTests: XCTestCase {
    private let width: CGFloat = 380

    func testAHeightChangeSmallerThanTheToleranceIsNotWorthAResize() {
        let frame = CGRect(x: 0, y: 0, width: width, height: 200)

        XCTAssertNil(PanelGeometry.resizing(frame, toContentHeight: 200, width: width))
        XCTAssertNil(PanelGeometry.resizing(frame, toContentHeight: 199.7, width: width))
        XCTAssertNotNil(PanelGeometry.resizing(frame, toContentHeight: 201, width: width))
    }

    func testTheTopEdgeStaysPutWhenThePanelGrowsDownwards() {
        let frame = CGRect(x: 40, y: 500, width: width, height: 200)

        let grown = PanelGeometry.resizing(frame, toContentHeight: 300, width: width)

        XCTAssertEqual(grown?.maxY, frame.maxY, "面板挂在状态栏下方，长高时上沿不能跟着动")
        XCTAssertEqual(grown?.height, 300)
        XCTAssertEqual(grown?.origin.x, 40)
    }

    func testTheTopEdgeAlsoStaysPutWhenThePanelShrinks() {
        let frame = CGRect(x: 40, y: 500, width: width, height: 300)

        let shrunk = PanelGeometry.resizing(frame, toContentHeight: 120, width: width)

        XCTAssertEqual(shrunk?.maxY, frame.maxY)
        XCTAssertEqual(shrunk?.height, 120)
    }

    func testAFractionalContentHeightRoundsUpSoNothingIsClipped() {
        let frame = CGRect(x: 0, y: 0, width: width, height: 100)

        XCTAssertEqual(
            PanelGeometry.resizing(frame, toContentHeight: 240.2, width: width)?.height,
            241
        )
    }

    func testAnEmptyPanelStillKeepsAPositiveHeight() {
        let frame = CGRect(x: 0, y: 0, width: width, height: 100)

        XCTAssertEqual(PanelGeometry.resizing(frame, toContentHeight: 0, width: width)?.height, 1)
    }

    func testThePanelHangsCentredUnderTheStatusItem() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 850)
        let anchor = CGRect(x: 700, y: 826, width: 24, height: 24)

        let origin = PanelGeometry.origin(
            below: anchor,
            size: CGSize(width: width, height: 300),
            in: visible
        )

        XCTAssertEqual(origin.x, anchor.midX - width / 2)
        XCTAssertEqual(origin.y, anchor.minY - 300 - PanelGeometry.statusItemGap)
    }

    func testAStatusItemNearTheRightEdgeDoesNotPushThePanelOffScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 850)
        let anchor = CGRect(x: 1420, y: 826, width: 24, height: 24)

        let origin = PanelGeometry.origin(
            below: anchor,
            size: CGSize(width: width, height: 300),
            in: visible
        )

        XCTAssertEqual(origin.x, visible.maxX - width - PanelGeometry.screenEdgeInset)
    }

    func testAStatusItemOnASecondScreenIsClampedToThatScreenLeftEdge() {
        let visible = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let anchor = CGRect(x: -1915, y: 1056, width: 24, height: 24)

        let origin = PanelGeometry.origin(
            below: anchor,
            size: CGSize(width: width, height: 300),
            in: visible
        )

        XCTAssertEqual(origin.x, visible.minX + PanelGeometry.screenEdgeInset)
    }

    func testAPanelTallerThanTheScreenStopsAtTheBottomInset() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 850)
        let anchor = CGRect(x: 700, y: 826, width: 24, height: 24)

        let origin = PanelGeometry.origin(
            below: anchor,
            size: CGSize(width: width, height: 1200),
            in: visible
        )

        XCTAssertEqual(origin.y, visible.minY + PanelGeometry.screenEdgeInset)
    }
}
