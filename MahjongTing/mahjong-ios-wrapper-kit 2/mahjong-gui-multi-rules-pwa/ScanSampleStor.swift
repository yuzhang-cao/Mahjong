import Foundation
import UIKit
import CoreImage
import ARKit

final class ScanSampleStore {

    static let shared = ScanSampleStore()

    /// 是否开启研究样本采集（建议做成设置项开关）
    var isEnabled: Bool = true

    private let ciContext: CIContext = CIContext()

    private init() {}

    /// 保存一次扫描会话：默认保存所有 snapshots（RGB + 可选 depth/conf）
    /// 返回：会话目录 URL
    func saveSession(snapshots: [ARFrameSnapshot],
                     note: String? = nil) throws -> URL {

        guard isEnabled else { throw NSError(domain: "ScanSampleStore", code: 1) }
        guard !snapshots.isEmpty else { throw NSError(domain: "ScanSampleStore", code: 2) }

        let root = try ensureRootDir()
        let sessionId = ISO8601DateFormatter().string(from: Date()) + "_" + UUID().uuidString
        let sessionDir = root.appendingPathComponent(sessionId, isDirectory: true)

        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        // 保存 meta
        let metaURL = sessionDir.appendingPathComponent("session_meta.json")
        let meta = makeMeta(snapshots: snapshots, note: note)
        let metaData = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
        try metaData.write(to: metaURL, options: [.atomic])

        // 保存每帧
        for (idx, s) in snapshots.enumerated() {
            let frameDir = sessionDir.appendingPathComponent(String(format: "frame_%03d", idx), isDirectory: true)
            try FileManager.default.createDirectory(at: frameDir, withIntermediateDirectories: true)

            try saveRGB(pixelBuffer: s.rgb, to: frameDir.appendingPathComponent("rgb.jpg"))

            if let depth = s.depth {
                try saveRawPixelBuffer(depth, to: frameDir.appendingPathComponent("depth_f32.bin"))
            }
            if let conf = s.depthConfidence {
                try saveRawPixelBuffer(conf, to: frameDir.appendingPathComponent("depth_conf_u8.bin"))
            }

            // 每帧参数（内参/位姿/时间戳）
            let frameMeta: [String: Any] = [
                "timestamp": s.timestamp,
                "intrinsics": matrixToArray(s.intrinsics),
                "cameraTransform": matrixToArray(s.cameraTransform)
            ]
            let frameMetaData = try JSONSerialization.data(withJSONObject: frameMeta, options: [.prettyPrinted, .sortedKeys])
            try frameMetaData.write(to: frameDir.appendingPathComponent("frame_meta.json"), options: [.atomic])
        }

        return sessionDir
    }

    // MARK: - Helpers

    private func ensureRootDir() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let root = docs.appendingPathComponent("ScanSamples", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private func saveRGB(pixelBuffer: CVPixelBuffer, to url: URL) throws {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw NSError(domain: "ScanSampleStore", code: 10)
        }
        let uiImage = UIImage(cgImage: cgImage)

        guard let jpeg = uiImage.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "ScanSampleStore", code: 11)
        }
        try jpeg.write(to: url, options: [.atomic])
    }

    /// 将 CVPixelBuffer 原始数据按“逐行 bytesPerRow”保存为 .bin
    /// depthMap 通常是 Float32；confidenceMap 通常是 UInt8
    private func saveRawPixelBuffer(_ pb: CVPixelBuffer, to url: URL) throws {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pb) else {
            throw NSError(domain: "ScanSampleStore", code: 20)
        }

        let width = CVPixelBufferGetWidth(pb)
        let height = CVPixelBufferGetHeight(pb)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)

        var data = Data()
        data.reserveCapacity(height * bytesPerRow)

        for row in 0..<height {
            let rowPtr = base.advanced(by: row * bytesPerRow)
            data.append(rowPtr.assumingMemoryBound(to: UInt8.self), count: bytesPerRow)
        }

        // 写一个很小的 header，方便你后续在 Python 读回来（宽/高/bytesPerRow）
        var header = Data()
        header.append(contentsOf: withUnsafeBytes(of: UInt32(width).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt32(height).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt32(bytesPerRow).littleEndian, Array.init))

        var out = Data()
        out.append(header)
        out.append(data)

        try out.write(to: url, options: [.atomic])
    }

    private func makeMeta(snapshots: [ARFrameSnapshot], note: String?) -> [String: Any] {
        var dict: [String: Any] = [
            "frameCount": snapshots.count,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        if let note = note { dict["note"] = note }
        return dict
    }

    private func matrixToArray(_ m: simd_float3x3) -> [Float] {
        return [
            m.columns.0.x, m.columns.0.y, m.columns.0.z,
            m.columns.1.x, m.columns.1.y, m.columns.1.z,
            m.columns.2.x, m.columns.2.y, m.columns.2.z
        ]
    }

    private func matrixToArray(_ m: simd_float4x4) -> [Float] {
        return [
            m.columns.0.x, m.columns.0.y, m.columns.0.z, m.columns.0.w,
            m.columns.1.x, m.columns.1.y, m.columns.1.z, m.columns.1.w,
            m.columns.2.x, m.columns.2.y, m.columns.2.z, m.columns.2.w,
            m.columns.3.x, m.columns.3.y, m.columns.3.z, m.columns.3.w
        ]
    }
}
