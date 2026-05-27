import Foundation

extension MahjongViewModel {

    func replaceHandFromScan(tiles: [Int]) {
        var newCounts: [Int] = Array(repeating: 0, count: 34)
        for t in tiles {
            if t < 0 || t >= 34 { continue }
            newCounts[t] += 1
        }

        for i in 0..<34 {
            if newCounts[i] > 4 {
                statusText = AppText.scanTooManyTile(tile: MahjongEngine.tileName34(i, language: language),
                                                     language: language)
                return
            }
        }

        applyScannedConcealedCounts(newCounts)
    }
}
