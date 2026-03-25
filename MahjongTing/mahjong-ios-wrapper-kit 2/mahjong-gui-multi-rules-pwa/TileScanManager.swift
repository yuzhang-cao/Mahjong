import Foundation
import Combine
import AVFoundation
import ARKit
import UIKit

struct ARFrameSnapshot {
    let rgb: CVPixelBuffer
    let depth: CVPixelBuffer?
    let depthConfidence: CVPixelBuffer?
    let intrinsics: simd_float3x3
    let cameraTransform: simd_float4x4
    let timestamp: TimeInterval
}

enum TileScanState: Equatable {
    case idle
    case noPermission
    case running
    case captured(count: Int)
    case failed(message: String)
}

final class TileScanManager: NSObject, ObservableObject, ARSessionDelegate {

    @Published private(set) var state: TileScanState = .idle
    @Published private(set) var lastPreviewImage: UIImage? = nil
    @Published private(set) var snapshots: [ARFrameSnapshot] = []

    /// 是否启用 sceneDepth（可选增强；你后续研究/数据采集用）
    var enableSceneDepth: Bool = true

    private weak var session: ARSession?
    private let ciContext: CIContext = CIContext()

    // burst 参数
    private var isCapturing: Bool = false
    private var captureTargetCount: Int = 0
    private var captureInterval: TimeInterval = 0.12
    private var lastCaptureTime: TimeInterval = 0

    // 预览刷新节流
    private var lastPreviewTime: TimeInterval = 0
    private let previewInterval: TimeInterval = 0.15

    func attach(session: ARSession) {
        self.session = session
        session.delegate = self
    }

    func requestCameraPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            completion(true)
            return
        }
        if status == .denied || status == .restricted {
            completion(false)
            return
        }
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async {
                completion(ok)
            }
        }
    }

    func startSession() {
        guard let session = self.session else { return }

        guard ARWorldTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                self.state = .failed(message: "当前设备不支持 ARKit World Tracking。")
            }
            return
        }

        let config = ARWorldTrackingConfiguration()
        config.isAutoFocusEnabled = true

        // 关键：用 supportsFrameSemantics 判断是否支持深度语义
        var semantics: ARWorldTrackingConfiguration.FrameSemantics = []

        if enableSceneDepth,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            semantics.insert(.sceneDepth)
        }

        if enableSceneDepth,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            semantics.insert(.smoothedSceneDepth)
        }

        config.frameSemantics = semantics

        session.run(config, options: [.resetTracking, .removeExistingAnchors])

        DispatchQueue.main.async {
            self.state = .running
        }
    }


    func stopSession() {
        session?.pause()
        DispatchQueue.main.async {
            self.state = .idle
        }
    }

    /// 快门式扫描：在短时间内抓取 N 帧（用于后续识别投票）
    func captureBurst(targetCount: Int = 5, interval: TimeInterval = 0.12) {
        guard case .running = state else { return }

        self.snapshots.removeAll(keepingCapacity: true)
        self.captureTargetCount = max(1, targetCount)
        self.captureInterval = max(0.05, interval)
        self.lastCaptureTime = 0
        self.isCapturing = true
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        // 1) 预览图节流更新
        let t = frame.timestamp
        if t - lastPreviewTime >= previewInterval {
            lastPreviewTime = t
            let uiImage = makeUIImage(from: frame.capturedImage)
            DispatchQueue.main.async {
                self.lastPreviewImage = uiImage
            }
        }

        // 2) burst 抓帧
        guard isCapturing else { return }

        if lastCaptureTime == 0 || (t - lastCaptureTime) >= captureInterval {
            lastCaptureTime = t

            let depthMap = frame.sceneDepth?.depthMap
            let confMap = frame.sceneDepth?.confidenceMap

            let snap = ARFrameSnapshot(
                rgb: frame.capturedImage,
                depth: depthMap,
                depthConfidence: confMap,
                intrinsics: frame.camera.intrinsics,
                cameraTransform: frame.camera.transform,
                timestamp: frame.timestamp
            )

            snapshots.append(snap)

            if snapshots.count >= captureTargetCount {
                isCapturing = false
                DispatchQueue.main.async {
                    self.state = .captured(count: self.snapshots.count)
                }
            }
        }
    }

    // MARK: - Helpers

    private func makeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    func readyForNextCapture() {
        DispatchQueue.main.async {
            self.state = .running
        }
    }

}
