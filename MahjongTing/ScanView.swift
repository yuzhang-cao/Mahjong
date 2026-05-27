import SwiftUI
import UIKit

struct ScanSheet: View {
    @ObservedObject var vm: MahjongViewModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager: CameraManager = CameraManager()

    private let recognizer = TileRecognizer(modelName: "TileModel")

    @State private var message: String = ""
    @State private var isBusy: Bool = false

    @State private var autoDetectedRowRect: CGRect? = nil
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    var body: some View {
        ZStack {
            CameraPreview(manager: manager)
                .ignoresSafeArea()

            GuideOverlay(normalizedRect: autoDetectedRowRect,
                         deviceOrientation: deviceOrientation)

            VStack(spacing: 10) {
                HStack {
                    Button(AppText.cancel(vm.language)) {
                        dismiss()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .appleClip(AppleCornerRadius.panel)

                    Spacer()

                    Button(isBusy ? AppText.processing(vm.language) : AppText.scan(vm.language)) {
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
            message = AppText.scanInstruction(vm.language)
            lockScanInterfaceOrientation()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updateDeviceOrientation(UIDevice.current.orientation)

            manager.requestCameraPermissionIfNeeded { ok in
                if ok {
                    manager.startSession()
                } else {
                    manager.stopSession()
                    message = AppText.cameraPermissionDenied(vm.language)
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
        .onChange(of: vm.language) { _, _ in
            if !isBusy {
                message = AppText.scanInstruction(vm.language)
            }
        }
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
            message = AppText.cameraNotReady(vm.language)
            return
        }

        isBusy = true
        autoDetectedRowRect = nil
        message = AppText.scanning(vm.language)

        manager.captureBurst(targetCount: 8, interval: 0.16)
    }

    private func handleStateChange(_ state: ScanState) {
        switch state {
        case .captured(let count):
            message = AppText.capturedFrames(count, language: vm.language)

            Task {
                do {
                    let result = try await recognizer.recognizeWithOverlay(snapshots: manager.snapshots)

                    await MainActor.run {
                        self.autoDetectedRowRect = result.normalizedRowRect

                        if result.ids.isEmpty {
                            self.message = AppText.recognizerReturnedEmpty(vm.language)
                            self.isBusy = false
                            manager.readyForNextCapture()
                            return
                        }

                        self.vm.replaceHandFromScan(tiles: result.ids)
                        self.message = AppText.recognitionDone(vm.language)
                        self.isBusy = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            dismiss()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.autoDetectedRowRect = nil
                        self.message = AppText.recognitionFailed(localizedRecognizerError(error),
                                                                 language: vm.language)
                        self.isBusy = false
                        manager.readyForNextCapture()
                    }
                }
            }

        case .failed(let msg):
            message = AppText.scanError(CameraFailureMessage.localized(msg, language: vm.language),
                                        language: vm.language)
            isBusy = false
            autoDetectedRowRect = nil

        default:
            break
        }
    }

    private func localizedRecognizerError(_ error: Error) -> String {
        if let recognizerError = error as? YOLOTileRecognizerError {
            return recognizerError.message(language: vm.language)
        }
        return error.localizedDescription
    }
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
