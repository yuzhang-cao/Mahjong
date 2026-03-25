//
//  VisionCoreMLYOLODetectorRecognizer.swift
//  MahjongTing
//
//  Created by caoyuzhang on 3/18/26.
//

import Foundation
import Vision
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

    private struct Detection {
        let id34: Int?
        let x: CGFloat
        let y: CGFloat
        let confidence: Float
    }

    private let modelName: String
    private let model: VNCoreMLModel?
    private let orientation: CGImagePropertyOrientation = .right

    /// 先保守一点，后面如果漏检多，再降到 0.25
    private let minConfidence: Float = 0.35

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

        let snap = snapshots[snapshots.count / 2]
        let ci = CIImage(cvPixelBuffer: snap.rgb)
        let oriented = ci.oriented(forExifOrientation: Int32(orientation.rawValue))

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []

                do {
                    let ids = try self.parseObservations(observations)
                    continuation.resume(returning: ids)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            /// YOLO 检测先用 scaleFill 跑通；后面若发现框有系统性偏差，再调
            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(ciImage: oriented, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func parseObservations(_ observations: [VNRecognizedObjectObservation]) throws -> [Int] {
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
                    confidence: best.confidence
                )
            )
        }

        guard !detections.isEmpty else {
            throw YOLOTileRecognizerError.noDetections
        }

        /// 过滤 UNKNOWN（当前先丢弃），剩下的按“一排”聚类
        let valid = detections.compactMap { det -> Detection? in
            guard det.id34 != nil else { return nil }
            return det
        }

        guard !valid.isEmpty else {
            throw YOLOTileRecognizerError.noDetections
        }

        let ys = valid.map { $0.y }.sorted()
        let medianY = ys[ys.count / 2]

        /// 一排手牌，取 y 中心接近中位数的一簇
        let band: CGFloat = 0.15
        let oneRow = valid.filter { abs($0.y - medianY) <= band }

        let row: [Detection]
        if oneRow.count >= 10 {
            row = oneRow
        } else {
            /// 如果过滤过严，回退到全部
            row = valid
        }

        var chosen = row

        /// 极端情况下如果框太多，只保留最可信的 18 张，再按 x 排序
        if chosen.count > 18 {
            chosen = Array(chosen.sorted(by: { $0.confidence > $1.confidence }).prefix(18))
        }

        let sorted = chosen.sorted { $0.x < $1.x }
        let ids = sorted.compactMap { $0.id34 }

        if ids.count < 13 {
            throw YOLOTileRecognizerError.insufficientDetections(found: ids.count)
        }

        return ids
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
        // 1m 1p 1s 1z
        case 0:  return 0    // 1m
        case 1:  return 9    // 1p
        case 2:  return 18   // 1s
        case 3:  return 27   // 1z = 東

        // 2m 2p 2s 2z
        case 4:  return 1    // 2m
        case 5:  return 10   // 2p
        case 6:  return 19   // 2s
        case 7:  return 28   // 2z = 南

        // 3m 3p 3s 3z
        case 8:  return 2    // 3m
        case 9:  return 11   // 3p
        case 10: return 20   // 3s
        case 11: return 29   // 3z = 西

        // 4m 4p 4s 4z
        case 12: return 3    // 4m
        case 13: return 12   // 4p
        case 14: return 21   // 4s
        case 15: return 30   // 4z = 北

        // 5m 5p 5s 5z
        case 16: return 4    // 5m
        case 17: return 13   // 5p
        case 18: return 22   // 5s
        case 19: return 33   // 5z = 白

        // 6m 6p 6s 6z
        case 20: return 5    // 6m
        case 21: return 14   // 6p
        case 22: return 23   // 6s
        case 23: return 32   // 6z = 發

        // 7m 7p 7s 7z
        case 24: return 6    // 7m
        case 25: return 15   // 7p
        case 26: return 24   // 7s
        case 27: return 31   // 7z = 中

        // 8m 8p 8s
        case 28: return 7    // 8m
        case 29: return 16   // 8p
        case 30: return 25   // 8s

        // 9m 9p 9s
        case 31: return 8    // 9m
        case 32: return 17   // 9p
        case 33: return 26   // 9s

        // UNKNOWN
        case 34:
            return nil

        // 赤五先临时映射回普通五
        case 35:
            return 4    // 0m -> 5m
        case 36:
            return 13   // 0p -> 5p
        case 37:
            return 22   // 0s -> 5s

        default:
            return nil
        }
    }
}
