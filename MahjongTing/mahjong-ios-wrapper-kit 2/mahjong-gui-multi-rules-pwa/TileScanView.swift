import SwiftUI
import RealityKit
import ARKit
import CoreImage
import ImageIO
import UIKit

protocol TileRecognizerProtocol {
    func recognize(snapshots: [ARFrameSnapshot]) async throws -> [Int]
}

struct StubTileRecognizer: TileRecognizerProtocol {
    func recognize(snapshots: [ARFrameSnapshot]) async throws -> [Int] {
        return []
    }
}

struct TileScanSheet: View {
    @ObservedObject var vm: MahjongViewModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager: AVCaptureTileScanManager = AVCaptureTileScanManager()

    private let recognizer = VisionCoreMLYOLODetectorRecognizer(modelName: "best")

    @State private var message: String = "将手牌放入画面中，点击“扫描”。系统会自动识别牌区域。"
    @State private var isBusy: Bool = false

    /// 自动识别出的整排手牌区域（归一化坐标，原点在左下）
    @State private var autoDetectedRowRect: CGRect? = nil
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    var body: some View {
        ZStack {
            AVCapturePreviewContainer(manager: manager)
                .ignoresSafeArea()

            GuideOverlay(normalizedRect: autoDetectedRowRect,
                         deviceOrientation: deviceOrientation)

            VStack(spacing: 10) {
                HStack {
                    Button("取消") {
                        dismiss()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .appleClip(AppleCornerRadius.panel)

                    Spacer()

                    Button(isBusy ? "处理中…" : "扫描") {
                        startScan()
                    }
                    .disabled(isBusy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .appleClip(AppleCornerRadius.panel)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                Text(message)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .appleClip(AppleCornerRadius.panel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .onAppear {
            lockScanInterfaceOrientation()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updateDeviceOrientation(UIDevice.current.orientation)

            manager.requestCameraPermissionIfNeeded { ok in
                if ok {
                    manager.startSession()
                } else {
                    manager.stopSession()
                    message = "相机权限未开启。请在系统设置中允许本 App 使用相机。"
                }
            }
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            unlockInterfaceOrientation()
            manager.stopSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateDeviceOrientation(UIDevice.current.orientation)
        }
        .onReceive(manager.$state, perform: handleStateChange)
    }

    private func lockScanInterfaceOrientation() {
        AppOrientationState.updateSupportedOrientations(.portrait)
    }

    private func unlockInterfaceOrientation() {
        AppOrientationState.updateSupportedOrientations(.allButUpsideDown)
    }

    private func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
        if orientation == .portrait ||
            orientation == .portraitUpsideDown ||
            orientation == .landscapeLeft ||
            orientation == .landscapeRight {
            deviceOrientation = orientation
            manager.updateDeviceOrientation(orientation)
        }
    }

    private func startScan() {
        guard case .running = manager.state else {
            message = "相机尚未就绪，请稍等。"
            return
        }

        isBusy = true
        autoDetectedRowRect = nil
        message = "扫描中…"

        manager.captureBurst(targetCount: 8, interval: 0.16)
    }

    private func handleStateChange(_ state: TileScanState) {
        switch state {
        case .captured(let count):
            message = "已捕获 \(count) 帧，处理中…"

            Task {
                do {
                    let result = try await recognizer.recognizeWithOverlay(snapshots: manager.snapshots)

                    await MainActor.run {
                        self.autoDetectedRowRect = result.normalizedRowRect

                        if result.ids.isEmpty {
                            self.message = "识别模型尚未接入（当前返回空结果）。"
                            self.isBusy = false
                            manager.readyForNextCapture()
                            return
                        }

                        self.vm.replaceHandFromScan(tiles: result.ids)
                        self.message = "识别完成"
                        self.isBusy = false

                        // 给用户一个很短的可见时间，能看到自动识别框
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            dismiss()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.autoDetectedRowRect = nil
                        self.message = "识别失败：\(error.localizedDescription)（请重拍）"
                        self.isBusy = false
                        manager.readyForNextCapture()
                    }
                }
            }

        case .failed(let msg):
            message = "错误：\(msg)"
            isBusy = false
            autoDetectedRowRect = nil

        default:
            break
        }
    }
}

private struct ARPreviewContainer: UIViewRepresentable {
    @ObservedObject var manager: TileScanManager

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        manager.attach(session: view.session)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

private struct GuideOverlay: View {
    let normalizedRect: CGRect?
    let deviceOrientation: UIDeviceOrientation

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let screenHeight = geo.size.height

            if let rect = normalizedRect,
               rect.width > 0,
               rect.height > 0 {

                // Vision / CoreImage 归一化坐标原点在左下
                let x = rect.minX * screenWidth
                let y = (1.0 - rect.maxY) * screenHeight
                let w = rect.width * screenWidth
                let h = rect.height * screenHeight

                AppleCornerShape.continuous(AppleCornerRadius.overlayGuide)
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: w, height: h)
                    .position(x: x + w / 2.0, y: y + h / 2.0)
                    .shadow(radius: 6)
            } else {
                // 未识别到时，保留一个较弱的默认提示框
                let scanFrame = defaultScanFrame(screenWidth: screenWidth,
                                                 screenHeight: screenHeight)

                AppleCornerShape.continuous(AppleCornerRadius.overlayGuide)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .frame(width: scanFrame.width, height: scanFrame.height)
                    .position(x: screenWidth * 0.5, y: scanFrame.centerY)
                    .foregroundColor(.white.opacity(0.75))
                    .shadow(radius: 6)
            }
        }
        .allowsHitTesting(false)
    }

    private func defaultScanFrame(screenWidth: CGFloat,
                                  screenHeight: CGFloat) -> (width: CGFloat, height: CGFloat, centerY: CGFloat) {
        let isLandscapeDevice = deviceOrientation == .landscapeLeft ||
            deviceOrientation == .landscapeRight
        let phoneShortSide = min(screenWidth, screenHeight)
        let phoneLongSide = max(screenWidth, screenHeight)
        let phoneAspect = phoneLongSide / phoneShortSide

        if isLandscapeDevice {
            let height = screenHeight * 0.62
            return (width: height / phoneAspect,
                    height: height,
                    centerY: screenHeight * 0.54)
        }

        let width = screenWidth * 0.92
        return (width: width,
                height: width / phoneAspect,
                centerY: screenHeight * 0.70)
    }
}
