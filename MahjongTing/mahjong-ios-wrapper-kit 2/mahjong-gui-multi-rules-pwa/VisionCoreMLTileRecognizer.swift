//
//  VisionCoreMLTileRecognizer.swift
//  MahjongTing
//
//  Created by caoyuzhang on 3/19/26.
//

import Foundation
import Vision
import CoreML
import CoreImage
import ImageIO

enum TileRecognizerError: LocalizedError {
    case modelMissing(name: String)
    case insufficientDetections(found: Int)
    case invalidClassIdentifier(_ id: String)

    var errorDescription: String? {
        switch self {
        case .modelMissing(let name):
            return "未找到识别模型：\(name).mlmodel（请把模型添加进 Xcode 并勾选 Target Membership）"
        case .insufficientDetections(let found):
            return "检测到的牌数不足（\(found) 张）。请确保一排摆放、无遮挡、光线充足后重拍。"
        case .invalidClassIdentifier(let id):
            return "模型输出的类别标签无法解析：\(id)（建议输出 \"0\"..\"33\"）"
        }
    }
}

final class VisionCoreMLTileRecognizer: TileRecognizerProtocol {

    private let classifier: CoreMLTileClassifier
    private let detector: VisionRectangleTileDetector
    private let ciContext: CIContext = CIContext()

    /// 竖屏 ARKit 帧常见需要右转为正向（你若发现结果旋转/错位，只需要改这个 orientation）
    private let orientation: CGImagePropertyOrientation = .right

    init(classifierModelName: String) {
        self.classifier = CoreMLTileClassifier(modelName: classifierModelName)
        self.detector = VisionRectangleTileDetector()
    }

    func recognize(snapshots: [ARFrameSnapshot]) async throws -> [Int] {
        guard !snapshots.isEmpty else { throw TileRecognizerError.insufficientDetections(found: 0) }

        // 清晰度择优
        let snap = snapshots[snapshots.count / 2]

        // 1) 将 CVPixelBuffer 转为“方向校正后的 CIImage”
        let ci = CIImage(cvPixelBuffer: snap.rgb)
        let oriented = ci.oriented(forExifOrientation: Int32(orientation.rawValue))

        // 2) 矩形检测（找出一排牌的矩形）
        let rects = try await detector.detectOneRowRectangles(on: oriented)

        // 3) 张数校验：允许 13..18（含杠）
        if rects.count < 13 { throw TileRecognizerError.insufficientDetections(found: rects.count) }

        // 4) 若多于 18，取最可信的前 18（按面积降序）
        let chosen: [VNRectangleObservation]
        if rects.count > 18 {
            let sortedByArea = rects.sorted { a, b in
                let areaA = a.boundingBox.width * a.boundingBox.height
                let areaB = b.boundingBox.width * b.boundingBox.height
                return areaA > areaB
            }
            chosen = Array(sortedByArea.prefix(18))
        } else {
            chosen = rects
        }

        // 5) 从左到右排序（以 bbox 中心 x）
        let sorted = chosen.sorted { a, b in
            let ax = a.boundingBox.midX
            let bx = b.boundingBox.midX
            return ax < bx
        }

        // 6) 逐张透视矫正裁剪 + 分类
        var result: [Int] = []
        result.reserveCapacity(sorted.count)

        for obs in sorted {
            let crop = try cropPerspective(from: oriented, rect: obs)
            let idx = try await classifier.classify(ciImage: crop)
            result.append(idx)
        }

        return result
    }

    // 透视矫正裁剪（用 VNRectangleObservation 的四点）
    private func cropPerspective(from image: CIImage, rect: VNRectangleObservation) throws -> CIImage {
        let w = image.extent.width
        let h = image.extent.height

        func p(_ n: CGPoint) -> CGPoint {
            // Vision 的 normalized point：原点在左下；CIImage 也是左下原点
            return CGPoint(x: n.x * w, y: n.y * h)
        }

        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: p(rect.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: p(rect.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: p(rect.bottomLeft)), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: p(rect.bottomRight)), forKey: "inputBottomRight")

        guard let out = filter.outputImage else {
            throw NSError(domain: "cropPerspective", code: -1)
        }
        return out
    }
}

// MARK: - Detector（不依赖训练模型，先用矩形检测打通）
final class VisionRectangleTileDetector {

    /// 针对“一排麻将牌”的矩形检测参数（可后续再调）
    private let maximumObservations: Int = 28

    func detectOneRowRectangles(on image: CIImage) async throws -> [VNRectangleObservation] {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = maximumObservations

        // 麻将牌常见宽高比：宽 < 高（取一个宽松区间，后续可调）
        request.minimumAspectRatio = 0.40
        request.maximumAspectRatio = 0.80

        // 牌在画面里不能太小
        request.minimumSize = 0.04

        // 适度提高置信度，减少杂物矩形
        request.minimumConfidence = 0.455

        let handler = VNImageRequestHandler(ciImage: image, options: [:])

        try handler.perform([request])
        let rects = (request.results as? [VNRectangleObservation]) ?? []

        // “一排”过滤：取 y 中心落在中位数附近的一簇
        guard !rects.isEmpty else { return [] }

        let centersY = rects.map { $0.boundingBox.midY }.sorted()
        let medianY = centersY[centersY.count / 2]

        // 阈值越小越严格；一排摆放可以更严格些
        let band: CGFloat = 0.08

        let oneRow = rects.filter { abs($0.boundingBox.midY - medianY) <= band }

        return oneRow
    }
}

// MARK: - Classifier（需要你提供 .mlmodel）
final class CoreMLTileClassifier {

    private let modelName: String
    private let model: VNCoreMLModel?

    init(modelName: String) {
        self.modelName = modelName

        // 运行时从 Bundle 里找编译后的 .mlmodelc
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            // 没有模型：不崩溃，留空，让 classify 时抛错
            self.model = nil
            return
        }

        do {
            let ml = try MLModel(contentsOf: url)
            self.model = try VNCoreMLModel(for: ml)
        } catch {
            // 模型加载失败：不崩溃，留空，让 classify 时抛错
            self.model = nil
        }
    }

    func classify(ciImage: CIImage) async throws -> Int {
        guard let model = model else {
            throw TileRecognizerError.modelMissing(name: modelName)
        }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard
            let results = request.results as? [VNClassificationObservation],
            let best = results.first
        else {
            throw NSError(domain: "classify", code: -1)
        }

        // 强烈建议你的模型输出 identifier 为 "0".."33"
        if let idx = Int(best.identifier) {
            return idx
        }
        throw TileRecognizerError.invalidClassIdentifier(best.identifier)
    }
}
