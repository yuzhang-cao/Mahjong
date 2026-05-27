import Foundation
import Combine
import AVFoundation
import UIKit
import ImageIO
import OSLog

nonisolated final class CameraFrameOutput: NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable {

    private var snapshotBuffer: [FrameSnapshot] = []
    private let snapshotLock = NSLock()
    private var deviceOrientation: UIDeviceOrientation = .portrait
    private let orientationLock = NSLock()
    private let onPreviewImage: (UIImage) -> Void
    private let onCaptured: (Int) -> Void

    private let ciContext = CIContext()

    private var isCapturing: Bool = false
    private var captureTargetCount: Int = 0
    private var captureInterval: TimeInterval = 0.25
    private var lastCaptureTime: TimeInterval = 0

    private var lastPreviewTime: TimeInterval = 0
    private let previewInterval: TimeInterval = 0.12

    init(onPreviewImage: @escaping (UIImage) -> Void,
         onCaptured: @escaping (Int) -> Void) {
        self.onPreviewImage = onPreviewImage
        self.onCaptured = onCaptured
        super.init()
    }

    var snapshots: [FrameSnapshot] {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return snapshotBuffer
    }

    private var currentExifOrientation: CGImagePropertyOrientation {
        orientationLock.lock()
        let orientation = deviceOrientation
        orientationLock.unlock()
        return Self.exifOrientationForBackCamera(orientation)
    }

    func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
        guard orientation == .portrait ||
            orientation == .portraitUpsideDown ||
            orientation == .landscapeLeft ||
            orientation == .landscapeRight else {
            return
        }

        orientationLock.lock()
        deviceOrientation = orientation
        orientationLock.unlock()
    }

    func captureBurst(targetCount: Int, interval: TimeInterval) {
        snapshotLock.lock()
        snapshotBuffer.removeAll(keepingCapacity: true)
        snapshotLock.unlock()

        captureTargetCount = max(1, targetCount)
        captureInterval = max(0.05, interval)
        lastCaptureTime = 0
        isCapturing = true
    }

    private static func exifOrientationForBackCamera(
        _ deviceOrientation: UIDeviceOrientation
    ) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        default:
            return .right
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let now = CACurrentMediaTime()

        if now - lastPreviewTime >= previewInterval {
            lastPreviewTime = now

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                onPreviewImage(uiImage)
            }
        }

        guard isCapturing else { return }

        if lastCaptureTime == 0 || (now - lastCaptureTime) >= captureInterval {
            lastCaptureTime = now

            let snapshot = FrameSnapshot(
                image: pixelBuffer,
                timestamp: now,
                exifOrientation: currentExifOrientation
            )

            snapshotLock.lock()
            snapshotBuffer.append(snapshot)
            let snapshotCount = snapshotBuffer.count
            snapshotLock.unlock()

            if snapshotCount >= captureTargetCount {
                isCapturing = false
                onCaptured(snapshotCount)
            }
        }
    }
}

final class CameraManager: NSObject, ObservableObject {

    @Published private(set) var state: ScanState = .idle
    @Published private(set) var lastPreviewImage: UIImage? = nil

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "mahjong.capture.session")
    private let videoOutputQueue = DispatchQueue(label: "mahjong.capture.video")

    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MahjongTing",
                                category: "Capture")

    private lazy var frameOutput = CameraFrameOutput(
        onPreviewImage: { [weak self] image in
            Task { @MainActor in
                self?.lastPreviewImage = image
            }
        },
        onCaptured: { [weak self] count in
            Task { @MainActor in
                self?.state = .captured(count: count)
            }
        }
    )

    var snapshots: [FrameSnapshot] {
        frameOutput.snapshots
    }

    func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
        frameOutput.updateDeviceOrientation(orientation)
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
        let frameOutput = frameOutput

        sessionQueue.async {
            if self.session.isRunning {
                DispatchQueue.main.async {
                    self.state = .running
                }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720

            // 输入
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async {
                    self.state = .failed(message: CameraFailureMessage.noBackCamera)
                }
                self.session.commitConfiguration()
                return
            }

            self.currentDevice = device

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.inputs.isEmpty, self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .failed(message: CameraFailureMessage.inputFailed(error.localizedDescription))
                }
                self.session.commitConfiguration()
                return
            }

            // 输出
            if self.videoOutput == nil {
                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(frameOutput, queue: self.videoOutputQueue)

                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                    self.videoOutput = output
                }
            }

            // 连续自动对焦
            do {
                try device.lockForConfiguration()

                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }

                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }

                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }

                device.unlockForConfiguration()
            } catch {
                self.logger.error("相机配置失败: \(error.localizedDescription, privacy: .public)")
            }

            self.session.commitConfiguration()
            self.session.startRunning()

            DispatchQueue.main.async {
                self.state = .running
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.state = .idle
            }
        }
    }

    func captureBurst(targetCount: Int = 5, interval: TimeInterval = 0.25) {
        guard case .running = state else { return }

        let frameOutput = frameOutput
        videoOutputQueue.async {
            frameOutput.captureBurst(targetCount: targetCount, interval: interval)
        }
    }

    func readyForNextCapture() {
        DispatchQueue.main.async {
            self.state = .running
        }
    }

    func setFocusPoint(_ point: CGPoint) {
        sessionQueue.async {
            guard let device = self.currentDevice else { return }

            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                }
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }

                device.unlockForConfiguration()
            } catch {
                self.logger.error("设置对焦点失败: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
