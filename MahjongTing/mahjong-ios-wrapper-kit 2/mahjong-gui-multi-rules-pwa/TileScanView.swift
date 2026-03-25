import SwiftUI
import RealityKit
import ARKit
import CoreImage
import ImageIO


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
    //@StateObject private var manager: TileScanManager = TileScanManager()
    @StateObject private var manager: AVCaptureTileScanManager = AVCaptureTileScanManager()

    @State private var showExportSheet: Bool = false
    @State private var exportURL: URL?

    private let recognizer: TileRecognizerProtocol = VisionCoreMLYOLODetectorRecognizer(modelName: "best")
    // private let recognizer: TileRecognizerProtocol = StubTileRecognizer()
    // private let recognizer: TileRecognizerProtocol = VisionCoreMLTileRecognizer(classifierModelName: "TileClassifierV1")

    @State private var message: String = "将手牌一排摆放在框内，点击“扫描”。"
    @State private var isBusy: Bool = false

    @State private var collectMode: Bool = false
    @State private var collectLabel: Int = 0
    @State private var collectSaved: Int = 0

    

    var body: some View {
        ZStack {
            //ARPreviewContainer(manager: manager)
            AVCapturePreviewContainer(manager: manager)
                .ignoresSafeArea()

            GuideOverlay()

            VStack(spacing: 10) {
                HStack {
                    Button("导出数据集") {
                        isBusy = true
                        message = "导出中（生成目录副本）…"

                        Task.detached(priority: .userInitiated) {
                            do {
                                let folderURL = try DeveloperDatasetExport.exportMahjongDatasetFolder()

                                // 自检：Training/0 的 jpg 数
                                let t0 = folderURL
                                    .appendingPathComponent("Training", isDirectory: true)
                                    .appendingPathComponent("0", isDirectory: true)

                                let files = (try? FileManager.default.contentsOfDirectory(
                                    at: t0,
                                    includingPropertiesForKeys: nil,
                                    options: [.skipsHiddenFiles]
                                )) ?? []
                                let jpgs = files.filter { $0.pathExtension.lowercased() == "jpg" }

                                // 自检：读 manifest（这里一定读得到才算“manifest 已写入”）
                                let manifestURL = folderURL.appendingPathComponent("EXPORT_MANIFEST.txt")
                                let manifestText = (try? String(contentsOf: manifestURL, encoding: .utf8)) ?? "(manifest missing)"

                                print("[ExportFolder] root:", folderURL.path)
                                print("[ExportFolder] Training/0 jpg:", jpgs.count)
                                print("[ExportFolder] manifest:\n\(manifestText)")

                                await MainActor.run {
                                    self.exportURL = folderURL
                                    self.showExportSheet = true
                                    self.message = "目录副本已准备：Training/0=\(jpgs.count)"
                                    self.isBusy = false
                                }
                            } catch {
                                await MainActor.run {
                                    self.message = "导出失败：\(error.localizedDescription)"
                                    self.isBusy = false
                                }
                            }
                        }
                    }
                    .disabled(isBusy)

                    .disabled(isBusy)

                    HStack {
                        Button("导出数据集(分享)") {
                            isBusy = true
                            message = "导出中（生成 ZIP）…"

                            Task.detached(priority: .userInitiated) {
                                do {
                                    let zipURL = try DeveloperDatasetExport.exportMahjongDatasetZip()

                                    // ✅ zip 文件级自检：大小（最可靠）
                                    let attrs = try? FileManager.default.attributesOfItem(atPath: zipURL.path)
                                    let size = (attrs?[.size] as? NSNumber)?.intValue ?? -1
                                    print("[ExportZip] file:", zipURL.path, "size:", size)

                                    await MainActor.run {
                                        self.exportURL = zipURL
                                        self.showExportSheet = true
                                        self.message = "ZIP 已生成：\(zipURL.lastPathComponent)（\(size) bytes）"
                                        self.isBusy = false
                                    }
                                } catch {
                                    await MainActor.run {
                                        self.message = "导出失败：\(error.localizedDescription)"
                                        self.isBusy = false
                                    }
                                }
                            }
                        }
                        .disabled(isBusy)

                        .disabled(isBusy)

                        Button("导出样本(分享)") {
                            do {
                                let url = try DeveloperDatasetExport.exportLatestSample(label: collectLabel)

                                // 打印文件大小，确认不是“空壳”
                                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                                let size = (attrs?[.size] as? NSNumber)?.intValue ?? -1
                                print("[ExportSample] file:", url.path, "size:", size)

                                exportURL = url
                                showExportSheet = true
                                message = "样本已准备：\(url.lastPathComponent)（\(size) bytes）"
                            } catch {
                                message = "导出样本失败：\(error.localizedDescription)"
                            }
                        }
                        .disabled(isBusy)
                    }

                    .disabled(isBusy)

                    Button("取消") { dismiss() }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    Spacer()

                    Button(isBusy ? "处理中…" : "扫描") {
                        startScan()
                    }
                    .disabled(isBusy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                VStack(spacing: 8) {
                    Toggle("采集模式（单牌训练用）", isOn: $collectMode)
                        .padding(.horizontal, 16)

                    if collectMode {
                        HStack {
                            Text("类别：\(collectLabel)  \(tileNameForLabel(collectLabel))")
                                .font(.footnote)

                            Spacer()

                            Stepper("", value: $collectLabel, in: 0...33)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)

                        Text("已采集：\(collectSaved) 张（保存到 Documents/MahjongDataset/Training/\(collectLabel)/）")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                Text(message)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ActivityView(activityItems: [url])
            } else {
                Text("无导出文件")
            }
        }
        .onAppear {
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
            manager.stopSession()
        }
        .onReceive(manager.$state, perform: handleStateChange)
    }

    private func startScan() {
        guard case .running = manager.state else {
            message = "相机尚未就绪，请稍等。"
            return
        }

        isBusy = true
        message = collectMode ? "采集中（单牌）…" : "扫描中…"

        if collectMode {
            manager.captureBurst(targetCount: 2, interval: 0.10)
        } else {
            manager.captureBurst(targetCount: 5, interval: 0.25)
        }
    }

    private func handleStateChange(_ state: TileScanState) {
        switch state {
        case .captured(let count):
            message = "已捕获 \(count) 帧，处理中…"
            Task {
                if collectMode {
                    do {
                        let snap = manager.snapshots[manager.snapshots.count / 2]

                        // 优先裁剪单牌 patch；失败则回退保存整帧（保证永远能产出训练图）
                        let patch = CIImage(cvPixelBuffer: snap.rgb)
                            .oriented(forExifOrientation: Int32(CGImagePropertyOrientation.right.rawValue))

                        _ = try MahjongDatasetStore.shared.saveTrainingPatch(ciImage: patch, label: collectLabel)

                        let root = MahjongDatasetStore.shared.datasetRootURL()
                        let dir = root.appendingPathComponent("Training").appendingPathComponent("\(collectLabel)")
                        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []

                        print("[Dataset] root:", root.path)
                        print("[Dataset] label \(collectLabel) count:", files.count)

                        await MainActor.run {
                            collectSaved += 1
                            message = "已保存：Training/\(collectLabel)（累计 \(collectSaved) 张）"
                            isBusy = false
                            manager.readyForNextCapture()
                        }
                    } catch {
                        await MainActor.run {
                            message = "采集失败：\(error.localizedDescription)"
                            isBusy = false
                            manager.readyForNextCapture()
                        }
                    }
                    return
                }

                // 识别模式
                do {
                    let tiles = try await recognizer.recognize(snapshots: manager.snapshots)
                    await MainActor.run {
                        if tiles.isEmpty {
                            self.message = "识别模型尚未接入（当前返回空结果）。"
                            self.isBusy = false
                            manager.readyForNextCapture()
                            return
                        }
                        self.vm.replaceHandFromScan(tiles: tiles)
                        self.isBusy = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        self.message = "识别失败：\(error.localizedDescription)（请重拍）"
                        self.isBusy = false
                        manager.readyForNextCapture()
                    }
                }

            }

        case .failed(let msg):
            message = "错误：\(msg)"
            isBusy = false

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
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let boxWidth = w * 0.92
            let boxHeight = h * 0.22

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                .frame(width: boxWidth, height: boxHeight)
                .position(x: w * 0.5, y: h * 0.70)
                .foregroundColor(.white.opacity(0.9))
                .shadow(radius: 6)
        }
        .allowsHitTesting(false)
    }
}

private func tileNameForLabel(_ idx: Int) -> String {
    if idx >= 0 && idx <= 8 { return "\(idx + 1)万" }
    if idx >= 9 && idx <= 17 { return "\(idx - 9 + 1)筒" }
    if idx >= 18 && idx <= 26 { return "\(idx - 18 + 1)索" }
    let honors = ["东", "南", "西", "北", "白", "發", "中"]
    let p = idx - 27
    if p >= 0 && p < honors.count { return honors[p] }
    return ""
}
