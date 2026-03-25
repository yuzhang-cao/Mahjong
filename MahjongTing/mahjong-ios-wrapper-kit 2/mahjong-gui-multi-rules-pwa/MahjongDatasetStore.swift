//
//  MahjongDatasetStore.swift
//  MahjongTing
//
//  Created by caoyuzhang on 1/18/26.
//

import Foundation
import UIKit
import CoreImage

final class MahjongDatasetStore {

    static let shared = MahjongDatasetStore()
    private init() {}

    private let ciContext: CIContext = CIContext()

    /// Documents/MahjongDataset
    func datasetRootURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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
            throw NSError(domain: "MahjongDatasetStore", code: 1)
        }
        try ensureTrainingFolders()

        let outDir = datasetRootURL()
            .appendingPathComponent("Training", isDirectory: true)
            .appendingPathComponent("\(label)", isDirectory: true)

        guard let cg = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw NSError(domain: "MahjongDatasetStore", code: 2)
        }

        let ui = UIImage(cgImage: cg)
        guard let jpeg = ui.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "MahjongDatasetStore", code: 3)
        }

        let name = "\(ISO8601DateFormatter().string(from: Date()))_\(UUID().uuidString).jpg"
        let url = outDir.appendingPathComponent(name)
        try jpeg.write(to: url, options: [.atomic])
        return url
    }
}
