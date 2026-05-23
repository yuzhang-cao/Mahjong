//
//  MahjongDatasetStore.swift
//  MahjongTing
//
//  Created by caoyuzhang on 1/18/26.
//

import Foundation
import UIKit
import CoreImage

enum MahjongDatasetStoreError: LocalizedError {
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

final class MahjongDatasetStore {

    static let shared = MahjongDatasetStore()
    private init() {}

    private let ciContext: CIContext = CIContext()

    /// Documents/MahjongDataset
    func datasetRootURL() -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("MahjongDataset", isDirectory: true)
        }
        return docs.appendingPathComponent("MahjongDataset", isDirectory: true)
    }

    /// 确保 Training/0..33 目录存在（Testing 先不强制用，训练前再划分即可）
    func ensureTrainingFolders() throws {
        let root = datasetRootURL()
        let training = root.appendingPathComponent("Training", isDirectory: true)

        if !FileManager.default.fileExists(atPath: training.path) {
            try FileManager.default.createDirectory(at: training, withIntermediateDirectories: true)
        }

        var i = 0
        while i < 34 {
            let dir = training.appendingPathComponent("\(i)", isDirectory: true)
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            i += 1
        }
    }

    /// 保存单牌训练图（JPEG）
    func saveTrainingPatch(ciImage: CIImage, label: Int) throws -> URL {
        if label < 0 || label >= 34 {
            throw MahjongDatasetStoreError.invalidLabel(label)
        }
        try ensureTrainingFolders()

        let outDir = datasetRootURL()
            .appendingPathComponent("Training", isDirectory: true)
            .appendingPathComponent("\(label)", isDirectory: true)

        guard let cg = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw MahjongDatasetStoreError.imageRenderFailed
        }

        let ui = UIImage(cgImage: cg)
        guard let jpeg = ui.jpegData(compressionQuality: 0.92) else {
            throw MahjongDatasetStoreError.jpegEncodingFailed
        }

        let name = "\(ISO8601DateFormatter().string(from: Date()))_\(UUID().uuidString).jpg"
        let url = outDir.appendingPathComponent(name)
        try jpeg.write(to: url, options: [.atomic])
        return url
    }
}
