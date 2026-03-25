//
//  SingleTilePatchExtractor.swift
//  MahjongTing
//
//  Created by caoyuzhang on 1/18/26.
//

import Foundation
import Vision
import CoreImage
import ImageIO

enum SingleTilePatchError: LocalizedError {
    case noRectangle
    case tooManyRectangles
    case cropFailed

    var errorDescription: String? {
        switch self {
        case .noRectangle: return "未检测到麻将牌矩形，请把单张牌放入画面并保证边缘完整。"
        case .tooManyRectangles: return "检测到多张牌/杂物，请保证画面里只有一张牌。"
        case .cropFailed: return "裁剪失败，请重试。"
        }
    }
}

final class SingleTilePatchExtractor {

    /// 你当前识别器也是 .right（竖屏 ARKit 常用）:contentReference[oaicite:6]{index=6}
    private let orientation: CGImagePropertyOrientation = .right

    func extract(from pixelBuffer: CVPixelBuffer) throws -> CIImage {
        let base = CIImage(cvPixelBuffer: pixelBuffer)
        let image = base.oriented(forExifOrientation: Int32(orientation.rawValue))

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 6
        request.minimumConfidence = 0.45
        request.minimumSize = 0.08
        request.minimumAspectRatio = 0.35
        request.maximumAspectRatio = 0.95

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        let rects = (request.results as? [VNRectangleObservation]) ?? []
        if rects.isEmpty { throw SingleTilePatchError.noRectangle }
        if rects.count >= 3 { throw SingleTilePatchError.tooManyRectangles }

        // 选面积最大的矩形
        var best = rects[0]
        var bestArea = best.boundingBox.width * best.boundingBox.height
        var i = 1
        while i < rects.count {
            let r = rects[i]
            let area = r.boundingBox.width * r.boundingBox.height
            if area > bestArea {
                best = r
                bestArea = area
            }
            i += 1
        }

        return try cropPerspective(from: image, rect: best)
    }

    private func cropPerspective(from image: CIImage, rect: VNRectangleObservation) throws -> CIImage {
        let w = image.extent.width
        let h = image.extent.height

        func p(_ n: CGPoint) -> CGPoint {
            return CGPoint(x: n.x * w, y: n.y * h)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw SingleTilePatchError.cropFailed
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: p(rect.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: p(rect.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: p(rect.bottomLeft)), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: p(rect.bottomRight)), forKey: "inputBottomRight")

        guard let out = filter.outputImage else {
            throw SingleTilePatchError.cropFailed
        }
        return out
    }
}
