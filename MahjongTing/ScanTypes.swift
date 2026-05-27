import Foundation
import CoreVideo
import ImageIO

struct FrameSnapshot {
    let image: CVPixelBuffer
    let timestamp: TimeInterval
    let exifOrientation: CGImagePropertyOrientation
}

enum ScanState: Equatable {
    case idle
    case noPermission
    case running
    case captured(count: Int)
    case failed(message: String)
}

protocol TileRecognizerProtocol {
    func recognize(snapshots: [FrameSnapshot]) async throws -> [Int]
}
