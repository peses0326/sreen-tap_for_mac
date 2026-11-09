import CoreGraphics

public enum ThumbnailBitmap {
    // Normalize OS results as well as the requested dimensions. Some capture paths
    // return a larger surface; rejecting that image would silently show only an icon.
    public static func make(from image: CGImage) -> CGImage? {
        let (width, height) = ThumbnailSize.fit(width: Double(image.width), height: Double(image.height))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

public enum SwitcherClick: Equatable {
    case select(Int)
    case cancel
}

public enum SwitcherHitTest {
    public static func cell(index: Int, width: CGFloat, columns: Int) -> CGRect {
        let columnCount = max(1, columns)
        let cellWidth = (width - 40) / CGFloat(columnCount)
        return CGRect(x: 20 + CGFloat(index % columnCount) * cellWidth,
                      y: 62 + CGFloat(index / columnCount) * 184, width: cellWidth - 8, height: 176)
    }
    public static func click(at point: CGPoint, width: CGFloat, columns: Int, count: Int, offset: Int) -> SwitcherClick {
        for index in 0..<max(0, count) where cell(index: index, width: width, columns: columns).contains(point) {
            return .select(offset + index)
        }
        return .cancel
    }
}
