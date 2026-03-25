import Foundation

enum MeldKind: String, Codable {
    case pong
    case kong
}

enum KongType: String, Codable {
    case an      // 暗杠：4 张都来自自己
    case ming    // 明杠：3 张来自自己 + 1 张来自别人弃牌
    case add     // 加杠：先碰，后补第 4 张
}

struct Meld: Identifiable, Equatable, Codable {
    let id: UUID
    var kind: MeldKind
    var tileIndex: Int
    var kongType: KongType? = nil

    init(pong tile: Int) {
        self.id = UUID()
        self.kind = .pong
        self.tileIndex = tile
        self.kongType = nil
    }

    init(kong tile: Int, type: KongType) {
        self.id = UUID()
        self.kind = .kong
        self.tileIndex = tile
        self.kongType = type
    }

    // UI 展示：碰=3，杠=4
    var displayTileCount: Int {
        return (kind == .kong) ? 4 : 3
    }

    // 撤销时需要加回暗手的数量
    // 碰：消耗暗手 2
    // 明杠：消耗暗手 3
    // 暗杠：消耗暗手 4
    // 加杠：消耗暗手 1（把碰升级为杠）
    var consumedFromHand: Int {
        if kind == .pong { return 2 }

        if kongType == .an { return 4 }
        if kongType == .ming { return 3 }
        if kongType == .add { return 1 }

        return 4
    }

    var displayName: String {
        if kind == .pong { return "碰" }
        if kind == .kong {
            if kongType == .an { return "暗杠" }
            if kongType == .ming { return "明杠" }
            if kongType == .add { return "加杠" }
            return "杠"
        }
        return "副露"
    }
}
