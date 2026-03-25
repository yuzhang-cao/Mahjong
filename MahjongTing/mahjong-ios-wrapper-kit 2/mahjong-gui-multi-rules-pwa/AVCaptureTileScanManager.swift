//
//  AVCaptureTileScanManager.swift
//  MahjongTing
//
//  Created by caoyuzhang on 3/19/26.
//

import Foundation
import Combine
import AVFoundation
import UIKit

final class AVCaptureTileScanManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published private(set) var state: TileScanState = .idle
    @Published private(set) var lastPreviewImage: UIImage? = nil
    @Published private(set) var snapshots: [ARFrameSnapshot] = []

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "mahjong.capture.session")
    private let videoOutputQueue = DispatchQueue(label: "mahjong.capture.video")

    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?

    private let ciContext = CIContext()

    // burst 参数
    private var isCapturing: Bool = false
    private var captureTargetCount: Int = 0
    private var captureInterval: TimeInterval = 0.25
    private var lastCaptureTime: TimeInterval = 0

    // 预览刷新节流
    private var lastPreviewTime: TimeInterval = 0
    private let previewInterval: TimeInterval = 0.12

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
                    self.state = .failed(message: "未找到后置摄像头。")
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
                    self.state = .failed(message: "相机输入创建失败：\(error.localizedDescription)")
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
                output.setSampleBufferDelegate(self, queue: self.videoOutputQueue)

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
                print("相机配置失败: \(error.localizedDescription)")
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

        self.snapshots.removeAll(keepingCapacity: true)
        self.captureTargetCount = max(1, targetCount)
        self.captureInterval = max(0.05, interval)
        self.lastCaptureTime = 0
        self.isCapturing = true
    }

    func readyForNextCapture() {
        DispatchQueue.main.async {
            self.state = .running
        }
    }

    func setFocusPoint(_ point: CGPoint) {
        guard let device = currentDevice else { return }

        sessionQueue.async {
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
                print("设置对焦点失败: \(error.localizedDescription)")
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let now = CACurrentMediaTime()

        // 预览图节流
        if now - lastPreviewTime >= previewInterval {
            lastPreviewTime = now

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self.lastPreviewImage = uiImage
                }
            }
        }

        // burst 抓帧
        guard isCapturing else { return }

        if lastCaptureTime == 0 || (now - lastCaptureTime) >= captureInterval {
            lastCaptureTime = now

            let snapshot = ARFrameSnapshot(
                rgb: pixelBuffer,
                depth: nil,
                depthConfidence: nil,
                intrinsics: matrix_identity_float3x3,
                cameraTransform: matrix_identity_float4x4,
                timestamp: now
            )

            snapshots.append(snapshot)

            if snapshots.count >= captureTargetCount {
                isCapturing = false
                DispatchQueue.main.async {
                    self.state = .captured(count: self.snapshots.count)
                }
            }
        }
    }
}
