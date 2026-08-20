import Foundation

enum PanelGeometry {
    static let statusItemGap: CGFloat = 6
    static let screenEdgeInset: CGFloat = 8
    static let minimumHeight: CGFloat = 1
    static let heightTolerance: CGFloat = 0.5

    static func resizing(
        _ frame: CGRect,
        toContentHeight height: CGFloat,
        width: CGFloat
    ) -> CGRect? {
        let target = max(height.rounded(.up), minimumHeight)
        guard abs(frame.height - target) > heightTolerance else {
            return nil
        }
        var resized = frame
        let top = frame.maxY
        resized.size = CGSize(width: width, height: target)
        resized.origin.y = top - target
        return resized
    }

    static func origin(
        below anchor: CGRect,
        size: CGSize,
        in visible: CGRect
    ) -> CGPoint {
        let x = min(
            max(anchor.midX - size.width / 2, visible.minX + screenEdgeInset),
            visible.maxX - size.width - screenEdgeInset
        )
        let y = anchor.minY - size.height - statusItemGap
        return CGPoint(x: x, y: max(y, visible.minY + screenEdgeInset))
    }
}
