//
//  VisionCoreMLYOLODetectorRecognizer.swift
//  MahjongTing
//
//  Created by caoyuzhang on 3/18/26.
//

import Foundation
@preconcurrency import Vision
import CoreML
import CoreImage
import ImageIO

enum YOLOTileRecognizerError: LocalizedError {
    case modelMissing(name: String)
    case noDetections
    case insufficientDetections(found: Int)

    var errorDescription: String? {
        switch self {
        case .modelMissing(let name):
            return "未找到检测模型：\(name).mlmodelc（请确认 best.mlpackage 已加入 Xcode 且勾选 Target Membership）"
        case .noDetections:
            return "没有检测到麻将牌，请调整拍摄角度、距离和光照后重试。"
        case .insufficientDetections(let found):
            return "检测到的牌数不足（\(found) 张），请确保一排摆放在框内后重试。"
        }
    }
}

final class VisionCoreMLYOLODetectorRecognizer: TileRecognizerProtocol {

    struct OverlayResult {
        let ids: [Int]
        let normalizedRowRect: CGRect?
    }

    private struct Detection {
        let id34: Int?
        let x: CGFloat
        let y: CGFloat
        let boundingBox: CGRect
        let confidence: Float
    }

    private let modelName: String
    private let model: VNCoreMLModel?

    private let minConfidence: Float = 0.20
    private let nmsIoUThreshold: CGFloat = 0.45

    init(modelName: String = "best") {
        self.modelName = modelName

        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            self.model = nil
            return
        }

        do {
            let mlModel = try MLModel(contentsOf: url)
            self.model = try VNCoreMLModel(for: mlModel)
        } catch {
            self.model = nil
        }
    }

    func recognize(snapshots: [ARFrameSnapshot]) async throws -> [Int] {
        guard !snapshots.isEmpty else {
            throw YOLOTileRecognizerError.insufficientDetections(found: 0)
        }
        guard let model else {
            throw YOLOTileRecognizerError.modelMissing(name: modelName)
        }

        let result = try recognizeBestCandidate(snapshots: snapshots, model: model)
        return result.ids
    }

    func recognizeWithOverlay(snapshots: [ARFrameSnapshot]) async throws -> OverlayResult {
        guard !snapshots.isEmpty else {
            throw YOLOTileRecognizerError.insufficientDetections(found: 0)
        }
        guard let model else {
            throw YOLOTileRecognizerError.modelMissing(name: modelName)
        }

        return try recognizeBestCandidate(snapshots: snapshots, model: model)
    }

    private func recognizeBestCandidate(snapshots: [ARFrameSnapshot], model: VNCoreMLModel) throws -> OverlayResult {
        var bestRow: [Detection] = []
        var bestScore: Float = -1
        var bestFound = 0

        for snap in snapshots {
            let observations = try observations(for: snap, model: model)
            let detections = (try? parseDetections(observations)) ?? []
            if detections.isEmpty { continue }

            let row = selectPrimaryRow(from: detections)
            let ids = sortedIds(from: row)
            let avgConfidence = row.isEmpty ? 0 : row.reduce(Float(0)) { $0 + $1.confidence } / Float(row.count)
            let score = Float(ids.count) * 10 + avgConfidence

            if ids.count > bestFound {
                bestFound = ids.count
            }

            if score > bestScore {
                bestScore = score
                bestRow = row
            }
        }

        let ids = sortedIds(from: bestRow)
        if ids.count < 13 {
            throw YOLOTileRecognizerError.insufficientDetections(found: max(bestFound, ids.count))
        }

        return OverlayResult(ids: ids, normalizedRowRect: Self.unionRect(bestRow.map { $0.boundingBox }))
    }

    private func observations(for snap: ARFrameSnapshot, model: VNCoreMLModel) throws -> [VNRecognizedObjectObservation] {
        let ci = CIImage(cvPixelBuffer: snap.rgb)
        let oriented = ci.oriented(forExifOrientation: Int32(snap.exifOrientation.rawValue))

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(ciImage: oriented, options: [:])
        try handler.perform([request])

        return (request.results as? [VNRecognizedObjectObservation]) ?? []
    }

    private func parseObservations(_ observations: [VNRecognizedObjectObservation]) throws -> [Int] {
        let detections = try parseDetections(observations)
        let row = selectPrimaryRow(from: detections)
        let ids = sortedIds(from: row)

        if ids.count < 13 {
            throw YOLOTileRecognizerError.insufficientDetections(found: ids.count)
        }

        return ids
    }

    private func parseDetections(_ observations: [VNRecognizedObjectObservation]) throws -> [Detection] {
        guard !observations.isEmpty else {
            throw YOLOTileRecognizerError.noDetections
        }

        var detections: [Detection] = []

        for obs in observations {
            guard let best = obs.labels.first else { continue }
            guard best.confidence >= minConfidence else { continue }

            guard let idx38 = Self.parseClassIdentifier(best.identifier) else { continue }
            let idx34 = Self.map38To34(idx38)

            detections.append(
                Detection(
                    id34: idx34,
                    x: obs.boundingBox.midX,
                    y: obs.boundingBox.midY,
                    boundingBox: obs.boundingBox,
                    confidence: best.confidence
                )
            )
        }

        guard !detections.isEmpty else {
            throw YOLOTileRecognizerError.noDetections
        }

        let valid = detections.compactMap { det -> Detection? in
            guard det.id34 != nil else { return nil }
            return det
        }

        guard !valid.isEmpty else {
            throw YOLOTileRecognizerError.noDetections
        }

        return nonMaximumSuppressed(valid)
    }

    private func selectPrimaryRow(from detections: [Detection]) -> [Detection] {
        let band: CGFloat = 0.15
        var bestRow: [Detection] = []
        var bestScore: Float = -1

        for center in detections {
            let row = detections.filter { abs($0.y - center.y) <= band }
            let avgConfidence = row.isEmpty ? 0 : row.reduce(Float(0)) { $0 + $1.confidence } / Float(row.count)
            let score = Float(row.count) * 10 + avgConfidence

            if score > bestScore {
                bestScore = score
                bestRow = row
            }
        }

        var chosen = bestRow.isEmpty ? detections : bestRow

        if chosen.count > 18 {
            chosen = Array(chosen.sorted(by: { $0.confidence > $1.confidence }).prefix(18))
        }

        return chosen
    }

    private func nonMaximumSuppressed(_ detections: [Detection]) -> [Detection] {
        var kept: [Detection] = []
        let sorted = detections.sorted { $0.confidence > $1.confidence }

        for detection in sorted {
            let overlapsExisting = kept.contains { existing in
                Self.intersectionOverUnion(detection.boundingBox, existing.boundingBox) >= nmsIoUThreshold
            }

            if !overlapsExisting {
                kept.append(detection)
            }
        }

        return kept
    }

    private func sortedIds(from detections: [Detection]) -> [Int] {
        return detections
            .sorted { $0.x < $1.x }
            .compactMap { $0.id34 }
    }

    private static func unionRect(_ rects: [CGRect]) -> CGRect? {
        guard var union = rects.first else { return nil }
        for rect in rects.dropFirst() {
            union = union.union(rect)
        }
        return union
    }

    private static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        if intersection.isNull || intersection.isEmpty { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        if unionArea <= 0 { return 0 }

        return intersectionArea / unionArea
    }

    /// 兼容两种情况：
    /// 1. 模型直接输出 "0"..."37"
    /// 2. 模型输出类别名，如 "1m" / "0p" / "UNKNOWN"
    private static func parseClassIdentifier(_ identifier: String) -> Int? {
        if let idx = Int(identifier) {
            return idx
        }

        let key = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let table: [String: Int] = [
            "1m": 0,  "1p": 1,  "1s": 2,  "1z": 3,
            "2m": 4,  "2p": 5,  "2s": 6,  "2z": 7,
            "3m": 8,  "3p": 9,  "3s": 10, "3z": 11,
            "4m": 12, "4p": 13, "4s": 14, "4z": 15,
            "5m": 16, "5p": 17, "5s": 18, "5z": 19,
            "6m": 20, "6p": 21, "6s": 22, "6z": 23,
            "7m": 24, "7p": 25, "7s": 26, "7z": 27,
            "8m": 28, "8p": 29, "8s": 30,
            "9m": 31, "9p": 32, "9s": 33,
            "unknown": 34,
            "0m": 35, "0p": 36, "0s": 37
        ]

        return table[key]
    }

    /// 当前 app 主体逻辑还是 34 类，所以先做 38 -> 34 的临时映射
    private static func map38To34(_ idx38: Int) -> Int? {
        switch idx38 {
        case 0:  return 0
        case 1:  return 9
        case 2:  return 18
        case 3:  return 27

        case 4:  return 1
        case 5:  return 10
        case 6:  return 19
        case 7:  return 28

        case 8:  return 2
        case 9:  return 11
        case 10: return 20
        case 11: return 29

        case 12: return 3
        case 13: return 12
        case 14: return 21
        case 15: return 30

        case 16: return 4
        case 17: return 13
        case 18: return 22
        case 19: return 33

        case 20: return 5
        case 21: return 14
        case 22: return 23
        case 23: return 32

        case 24: return 6
        case 25: return 15
        case 26: return 24
        case 27: return 31

        case 28: return 7
        case 29: return 16
        case 30: return 25

        case 31: return 8
        case 32: return 17
        case 33: return 26

        case 34:
            return nil

        case 35:
            return 4
        case 36:
            return 13
        case 37:
            return 22

        default:
            return nil
        }
    }
}
