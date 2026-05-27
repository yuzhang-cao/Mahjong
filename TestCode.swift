// Test and developer utilities kept outside the app target.
// They are not part of the runtime MahjongTing app logic.

import Foundation
import CoreImage
import SwiftUI
import UIKit

#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

enum TestDatasetStoreError: LocalizedError {
    case invalidLabel(Int)
    case imageRenderFailed
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidLabel(let label):
            return "样本类别无效：\(label)"
        case .imageRenderFailed:
            return "样本图片渲染失败"
        case .jpegEncodingFailed:
            return "样本图片 JPEG 编码失败"
        }
    }
}

final class TestDatasetStore {
    static let shared = TestDatasetStore()
    private init() {}

    private let ciContext: CIContext = CIContext()

    func datasetRootURL() -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("MahjongDataset", isDirectory: true)
        }
        return docs.appendingPathComponent("MahjongDataset", isDirectory: true)
    }

    func ensureTrainingFolders() throws {
        let training = datasetRootURL().appendingPathComponent("Training", isDirectory: true)

        if !FileManager.default.fileExists(atPath: training.path) {
            try FileManager.default.createDirectory(at: training, withIntermediateDirectories: true)
        }

        for label in 0..<34 {
            let dir = training.appendingPathComponent("\(label)", isDirectory: true)
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    func saveTrainingPatch(ciImage: CIImage, label: Int) throws -> URL {
        if label < 0 || label >= 34 {
            throw TestDatasetStoreError.invalidLabel(label)
        }

        try ensureTrainingFolders()

        let outDir = datasetRootURL()
            .appendingPathComponent("Training", isDirectory: true)
            .appendingPathComponent("\(label)", isDirectory: true)

        guard let cg = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw TestDatasetStoreError.imageRenderFailed
        }

        let image = UIImage(cgImage: cg)
        guard let jpeg = image.jpegData(compressionQuality: 0.92) else {
            throw TestDatasetStoreError.jpegEncodingFailed
        }

        let name = "\(ISO8601DateFormatter().string(from: Date()))_\(UUID().uuidString).jpg"
        let url = outDir.appendingPathComponent(name)
        try jpeg.write(to: url, options: [.atomic])
        return url
    }
}

enum DeveloperExportError: LocalizedError {
    case datasetNotFound
    case datasetEmpty
    case exportCopyFailed(String)

    var errorDescription: String? {
        switch self {
        case .datasetNotFound:
            return "未找到 MahjongDataset（请先采集至少 1 张）"
        case .datasetEmpty:
            return "MahjongDataset/Training 下没有任何 jpg（请先采集至少 1 张）"
        case .exportCopyFailed(let msg):
            return "导出复制失败：\(msg)"
        }
    }
}

final class DeveloperDatasetExport {

    /// 导出整个数据集（不压缩），返回的 out 目录结构为：
    /// out/
    ///   Training/0..33/*.jpg
    ///   EXPORT_MANIFEST.txt
    ///   EXPORT_OK.txt
    static func exportMahjongDatasetFolder() throws -> URL {
        let fm = FileManager.default
        let src = TestDatasetStore.shared.datasetRootURL()

        guard fm.fileExists(atPath: src.path) else {
            throw DeveloperExportError.datasetNotFound
        }

        // 快速检查：必须有 jpg
        let totalJPG = countAllJPGs(under: src)
        if totalJPG <= 0 {
            throw DeveloperExportError.datasetEmpty
        }

        let tmp = fm.temporaryDirectory
        let out = tmp.appendingPathComponent("MahjongDataset_Export_\(Int(Date().timeIntervalSince1970))",
                                             isDirectory: true)

        if fm.fileExists(atPath: out.path) {
            try? fm.removeItem(at: out)
        }
        try fm.createDirectory(at: out, withIntermediateDirectories: true)

        // 逐项复制：更可控，也便于后续写 manifest 校验
        do {
            let enumerator = fm.enumerator(at: src, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])!
            for case let item as URL in enumerator {
                let rel = item.path.replacingOccurrences(of: src.path + "/", with: "")
                let target = out.appendingPathComponent(rel)

                var isDir: ObjCBool = false
                _ = fm.fileExists(atPath: item.path, isDirectory: &isDir)

                if isDir.boolValue {
                    if !fm.fileExists(atPath: target.path) {
                        try fm.createDirectory(at: target, withIntermediateDirectories: true)
                    }
                } else {
                    let parent = target.deletingLastPathComponent()
                    if !fm.fileExists(atPath: parent.path) {
                        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                    }
                    if fm.fileExists(atPath: target.path) {
                        try fm.removeItem(at: target)
                    }
                    try fm.copyItem(at: item, to: target)
                }
            }
        } catch {
            throw DeveloperExportError.exportCopyFailed(error.localizedDescription)
        }

        // 写 manifest：导出副本里每类数量+示例文件名（Mac 上打开这个就能确认是否真的导出成功）
        let manifestURL = out.appendingPathComponent("EXPORT_MANIFEST.txt")
        let manifestText = buildManifest(exportRoot: out, sourceRoot: src, totalJPG: totalJPG)
        try manifestText.data(using: .utf8)!.write(to: manifestURL, options: [.atomic])

        // 写一个哨兵文件（用于你在 Mac 上确认拿到的是“最新导出”）
        let okURL = out.appendingPathComponent("EXPORT_OK.txt")
        let okText = "OK \(ISO8601DateFormatter().string(from: Date()))\nTOTAL_JPG=\(totalJPG)\n"
        try okText.data(using: .utf8)!.write(to: okURL, options: [.atomic])

        return out
    }
    
    /// 导出数据集为 zip（使用 ZIPFoundation，不依赖 iOS 16 的 FileManager.zipItem）
    /// - Parameter shouldKeepParent: true 表示 zip 里保留外层目录名（解压后是 MahjongDataset_Export_xxx/...）
    static func exportMahjongDatasetZip(shouldKeepParent: Bool = true) throws -> URL {
        #if canImport(ZIPFoundation)
        let fm = FileManager.default

        // 1) 复用你现有的“导出文件夹”逻辑：包含复制、校验、manifest、ok 文件
        let folderURL = try exportMahjongDatasetFolder()

        // 2) 创建 zip 文件路径
        let zipURL = fm.temporaryDirectory
            .appendingPathComponent(folderURL.lastPathComponent)
            .appendingPathExtension("zip")

        if fm.fileExists(atPath: zipURL.path) {
            try? fm.removeItem(at: zipURL)
        }

        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .create)
        } catch {
            throw DeveloperExportError.exportCopyFailed("无法创建 ZIP 文件：\(zipURL.lastPathComponent)")
        }

        // 3) 把 folderURL 下所有文件写进 zip
        let basePath = folderURL.path
        let parentName = folderURL.lastPathComponent

        if let en = fm.enumerator(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in en {
                var isDir: ObjCBool = false
                _ = fm.fileExists(atPath: fileURL.path, isDirectory: &isDir)

                // ZIPFoundation 对目录可以不显式写 entry，只写文件即可（路径会自动带目录层级）
                if isDir.boolValue {
                    continue
                }

                let rel = fileURL.path.replacingOccurrences(of: basePath + "/", with: "")

                let entryPath: String
                if shouldKeepParent {
                    entryPath = parentName + "/" + rel
                } else {
                    entryPath = rel
                }

                do {
                    try archive.addEntry(
                        with: entryPath,
                        fileURL: fileURL,
                        compressionMethod: .deflate
                    )
                } catch {
                    throw DeveloperExportError.exportCopyFailed("写入 ZIP 失败：\(entryPath)，\(error.localizedDescription)")
                }
            }
        }

        return zipURL
        #else
        throw DeveloperExportError.exportCopyFailed("当前环境没有 ZIPFoundation，无法导出 ZIP。")
        #endif
    }


    /// 导出某个 label 最新的一张 jpg（用于验证“导出/分享链路是否能带文件”）
    static func exportLatestSample(label: Int) throws -> URL {
        let fm = FileManager.default
        let root = TestDatasetStore.shared.datasetRootURL()

        let dir = root
            .appendingPathComponent("Training", isDirectory: true)
            .appendingPathComponent("\(label)", isDirectory: true)

        guard fm.fileExists(atPath: dir.path) else {
            throw DeveloperExportError.datasetNotFound
        }

        let urls = try fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let jpgs = urls.filter { $0.pathExtension.lowercased() == "jpg" }
        if jpgs.isEmpty {
            throw DeveloperExportError.datasetEmpty
        }

        guard let newest = jpgs.sorted(by: { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }).first else {
            throw DeveloperExportError.datasetEmpty
        }

        let tmp = fm.temporaryDirectory
        let out = tmp.appendingPathComponent("Sample_label\(label)_\(newest.lastPathComponent)")

        if fm.fileExists(atPath: out.path) {
            try? fm.removeItem(at: out)
        }
        try fm.copyItem(at: newest, to: out)
        return out
    }

    // MARK: - Helpers

    private static func countAllJPGs(under root: URL) -> Int {
        let fm = FileManager.default
        var cnt = 0
        if let en = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let u as URL in en {
                if u.pathExtension.lowercased() == "jpg" { cnt += 1 }
            }
        }
        return cnt
    }

    private static func buildManifest(exportRoot: URL, sourceRoot: URL, totalJPG: Int) -> String {
        let fm = FileManager.default
        var lines: [String] = []
        lines.append("ExportRoot: \(exportRoot.path)")
        lines.append("SourceRoot: \(sourceRoot.path)")
        lines.append("TOTAL_JPG_SOURCE=\(totalJPG)")
        lines.append("---- Training counts in export ----")

        for label in 0..<34 {
            let d = exportRoot
                .appendingPathComponent("Training", isDirectory: true)
                .appendingPathComponent("\(label)", isDirectory: true)

            let files = (try? fm.contentsOfDirectory(at: d, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            let jpgs = files.filter { $0.pathExtension.lowercased() == "jpg" }

            lines.append("label \(label): \(jpgs.count)")
            for u in jpgs.prefix(3) {
                lines.append("  - \(u.lastPathComponent)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct TestActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
