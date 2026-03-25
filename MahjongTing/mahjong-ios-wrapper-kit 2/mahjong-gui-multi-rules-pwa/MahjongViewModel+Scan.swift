import Foundation

extension MahjongViewModel {

    /// 用摄像头识别结果“整手替换”当前手牌。
    /// - Parameter tiles: 0..33 的牌索引数组（允许 13..18 张；不写死 14）
    func replaceHandFromScan(tiles: [Int]) {
        // 1) 计数
        var newCounts: [Int] = Array(repeating: 0, count: 34)
        for t in tiles {
            if t < 0 || t >= 34 { continue }
            newCounts[t] += 1
        }

        // 2) 基本合法性：单牌最多 4 张
        for i in 0..<34 {
            if newCounts[i] > 4 {
                statusText = "识别结果异常：\(MahjongEngine.tileName34(i)) 超过 4 张，请重拍。"
                return
            }
        }

        // 3) 按你现有规则口径，四川不允许字牌：直接清掉
        //    （你原来的 addTile 也有这条约束，这里保持一致）
        if resolveMode() == .sichuan {
            for i in 27..<34 { newCounts[i] = 0 }
        }

        // 4) 根据“==4 的牌种”作为杠口径，自动标记为杠（与你现有逻辑一致）
        var newKonged: Set<Int> = []
        for i in 0..<34 {
            if newCounts[i] == 4 {
                newKonged.insert(i)
            }
        }

        // 5) 写入并触发计算（不写死张数，让你的 compute() 去给出听牌/已胡/建议等结果）
        counts34 = newCounts
        kongedTiles = newKonged
        statusText = ""

        if autoComputeEnabled {
            compute()
        }
    }
}
