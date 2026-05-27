import Foundation

enum MahjongRuleMode: String, CaseIterable, Identifiable {
    case auto
    case sichuan
    case guangdong

    var id: String { self.rawValue }

    var displayName: String {
        displayName(language: .zh)
    }

    func displayName(language: AppLanguage) -> String {
        AppText.ruleModeName(self, language: language)
    }
}

enum Suit: String, CaseIterable, Identifiable {
    case m  // 万
    case p  // 筒
    case s  // 条

    var id: String { self.rawValue }

    var displayName: String {
        displayName(language: .zh)
    }

    func displayName(language: AppLanguage) -> String {
        AppText.suitTileSuffix(self, language: language)
    }

    func choiceName(language: AppLanguage) -> String {
        AppText.suitChoiceName(self, language: language)
    }
}

struct MahjongEngine {

    // 0..26: 万筒条；27..33: 东南西北白发中
    static func tileName34(_ idx: Int, language: AppLanguage = .zh) -> String {
        if idx < 0 || idx >= 34 { return "?" } // 防御式
        
        if idx >= 27 {
            let names = AppText.honorTileNames(language)
            return names[idx - 27]
        }
        let suit: Suit
        let num: Int
        if idx < 9 {
            suit = .m
            num = idx + 1
        } else if idx < 18 {
            suit = .p
            num = (idx - 9) + 1
        } else {
            suit = .s
            num = (idx - 18) + 1
        }
        return "\(num)\(suit.displayName(language: language))"
    }
    
    static func suitOf27(_ idx: Int) -> Suit {
        if idx < 9 { return .m }
        if idx < 18 { return .p }
        return .s
    }
    
    static func countSuit27(_ counts: [Int], _ suit: Suit) -> Int {
        if counts.count < 27 { return 0 }  // 防越界

        let base: Int
        switch suit {
        case .m: base = 0
        case .p: base = 9
        case .s: base = 18
        }

        var sum = 0
        for i in 0..<9 {
            sum += counts[base + i]
        }
        return sum
    }

    
    // MARK: - 七对 / 十三幺
    
    static func isQiDui(_ counts: [Int]) -> Bool {
        if counts.reduce(0, +) != 14 { return false }
        var pairs = 0
        for c in counts {
            if c % 2 != 0 { return false }
            pairs += c / 2
        }
        return pairs == 7
    }
    
    static func isThirteenOrphans(_ counts34: [Int]) -> Bool {
        if counts34.count != 34 { return false }
        if counts34.reduce(0, +) != 14 { return false }
        
        let required: [Int] = [0,8,9,17,18,26,27,28,29,30,31,32,33]
        var hasPair = false
        
        for idx in required {
            if counts34[idx] == 0 { return false }
            if counts34[idx] >= 2 { hasPair = true }
        }
        
        // 其他牌必须为 0
        for i in 0..<34 {
            if required.contains(i) { continue }
            if counts34[i] != 0 { return false }
        }
        
        return hasPair
    }
    
    // MARK: - 面子拆解（万/筒/条）记忆化
    
    private final class SuitMemo {
        var memo: [Int: Bool] = [:]
    }
    
    private static func suitKey(_ a9: [Int]) -> Int {
        // 每位 0..4，用 5 进制压缩成一个整数 key
        var key = 0
        for v in a9 {
            key = key * 5 + v
        }
        return key
    }
    
    private static func canSuitFormMelds(_ a9: [Int], memo: SuitMemo) -> Bool {
        let key = suitKey(a9)
        if let cached = memo.memo[key] {
            return cached
        }
        
        var first = -1
        for i in 0..<9 {
            if a9[i] > 0 {
                first = i
                break
            }
        }
        if first == -1 {
            memo.memo[key] = true
            return true
        }
        
        // 尝试刻子
        if a9[first] >= 3 {
            var b = a9
            b[first] -= 3
            if canSuitFormMelds(b, memo: memo) {
                memo.memo[key] = true
                return true
            }
        }
        
        // 尝试顺子
        if first <= 6 {
            if a9[first] >= 1 && a9[first + 1] >= 1 && a9[first + 2] >= 1 {
                var b = a9
                b[first] -= 1
                b[first + 1] -= 1
                b[first + 2] -= 1
                if canSuitFormMelds(b, memo: memo) {
                    memo.memo[key] = true
                    return true
                }
            }
        }
        
        memo.memo[key] = false
        return false
    }
    
    private static func sliceSuit(_ counts: [Int], base: Int) -> [Int] {
        var a9: [Int] = Array(repeating: 0, count: 9)
        for i in 0..<9 {
            a9[i] = counts[base + i]
        }
        return a9
    }
    
    private static func canAllMelds27(_ counts27: [Int]) -> Bool {
        let memo = SuitMemo()
        if !canSuitFormMelds(sliceSuit(counts27, base: 0), memo: memo) { return false }
        if !canSuitFormMelds(sliceSuit(counts27, base: 9), memo: memo) { return false }
        if !canSuitFormMelds(sliceSuit(counts27, base: 18), memo: memo) { return false }
        return true
    }
    
    private static func canAllMelds34(_ counts34: [Int]) -> Bool {
        let memo = SuitMemo()
        if !canSuitFormMelds(sliceSuit(counts34, base: 0), memo: memo) { return false }
        if !canSuitFormMelds(sliceSuit(counts34, base: 9), memo: memo) { return false }
        if !canSuitFormMelds(sliceSuit(counts34, base: 18), memo: memo) { return false }
        
        // 字牌只能刻子
        for i in 27..<34 {
            if counts34[i] % 3 != 0 { return false }
        }
        return true
    }
    
    // MARK: - Meld-aware APIs

    private static func addExtrasToCounts(_ concealed: [Int], _ extras: [Int]) -> [Int] {
        var res = concealed
        let n = min(res.count, extras.count)

        var i = 0
        while i < n {
            res[i] += extras[i]
            i += 1
        }
        return res
    }

    static func isWinningWithMelds(
        concealed: [Int],
        mode: MahjongRuleMode,
        dingque: Suit?,
        enableQiDui: Bool,
        enable13yao: Bool,
        fixedMeldCount: Int,
        meldExtras: [Int]
    ) -> Bool {

        if fixedMeldCount < 0 || fixedMeldCount > 4 { return false }

        // 胡牌态：暗手必须等于 14 - 3*固定面子数
        let concealedTotal = concealed.reduce(0, +)
        if concealedTotal != 14 - 3 * fixedMeldCount { return false }

        // 四川定缺：检查“暗手 + 副露”
        if mode == .sichuan, let dq = dingque {
            let allCounts = addExtrasToCounts(concealed, meldExtras)
            if countSuit27(allCounts, dq) != 0 { return false }
        }

        // 有副露则不允许七对/十三幺
        let allowSpecial = (fixedMeldCount == 0)

        if allowSpecial, enableQiDui {
            if isQiDui(concealed) { return true }
        }

        if allowSpecial, mode == .guangdong, enable13yao, concealed.count == 34 {
            if isThirteenOrphans(concealed) { return true }
        }

        // 常规：暗手拆成 (4-fixedMeldCount) 面子 + 1 将
        for pair in 0..<concealed.count {
            if concealed[pair] >= 2 {
                var tmp = concealed
                tmp[pair] -= 2

                let ok: Bool
                if mode == .sichuan {
                    ok = canAllMelds27(tmp)
                } else {
                    ok = canAllMelds34(tmp)
                }

                if ok { return true }
            }
        }

        return false
    }

    static func calcWaitsWithMelds(
        concealed: [Int],
        mode: MahjongRuleMode,
        dingque: Suit?,
        enableQiDui: Bool,
        enable13yao: Bool,
        fixedMeldCount: Int,
        meldExtras: [Int]
    ) -> [Int] {

        if fixedMeldCount < 0 || fixedMeldCount > 4 { return [] }

        // 听牌态：暗手必须等于 13 - 3*固定面子数
        let concealedTotal = concealed.reduce(0, +)
        if concealedTotal != 13 - 3 * fixedMeldCount { return [] }

        // 四川未清缺不听：检查暗手+副露
        if mode == .sichuan, let dq = dingque {
            let allCounts = addExtrasToCounts(concealed, meldExtras)
            if countSuit27(allCounts, dq) != 0 { return [] }
        }

        let owned = addExtrasToCounts(concealed, meldExtras)

        var waits: [Int] = []
        var t = 0
        while t < concealed.count {
            if t < owned.count, owned[t] >= 4 {
                t += 1
                continue
            }

            if mode == .sichuan, let dq = dingque, concealed.count == 27 {
                if suitOf27(t) == dq {
                    t += 1
                    continue
                }
            }

            var tmp = concealed
            tmp[t] += 1

            if isWinningWithMelds(
                concealed: tmp,
                mode: mode,
                dingque: dingque,
                enableQiDui: enableQiDui,
                enable13yao: enable13yao,
                fixedMeldCount: fixedMeldCount,
                meldExtras: meldExtras
            ) {
                waits.append(t)
            }

            t += 1
        }

        return waits
    }

    static func calcSuggestionsWithMelds(
        concealed: [Int],
        mode: MahjongRuleMode,
        dingque: Suit?,
        enableQiDui: Bool,
        enable13yao: Bool,
        fixedMeldCount: Int,
        meldExtras: [Int],
        limit: Int = 12
    ) -> [(discard: Int, waits: [Int])] {

        if fixedMeldCount < 0 || fixedMeldCount > 4 { return [] }

        // 抓牌态：暗手必须等于 14 - 3*固定面子数
        let concealedTotal = concealed.reduce(0, +)
        if concealedTotal != 14 - 3 * fixedMeldCount { return [] }

        var discards: [Int] = []
        var i = 0
        while i < concealed.count {
            if concealed[i] > 0 { discards.append(i) }
            i += 1
        }

        // 四川定缺：若未清缺，只允许打缺门
        if mode == .sichuan, let dq = dingque, concealed.count == 27 {
            let allCounts = addExtrasToCounts(concealed, meldExtras)
            if countSuit27(allCounts, dq) != 0 {
                var filtered: [Int] = []
                for d in discards {
                    if suitOf27(d) == dq { filtered.append(d) }
                }
                discards = filtered
            }
        }

        var res: [(discard: Int, waits: [Int])] = []

        for d in discards {
            var tmp = concealed
            tmp[d] -= 1

            let waits = calcWaitsWithMelds(
                concealed: tmp,
                mode: mode,
                dingque: dingque,
                enableQiDui: enableQiDui,
                enable13yao: enable13yao,
                fixedMeldCount: fixedMeldCount,
                meldExtras: meldExtras
            )

            if !waits.isEmpty {
                res.append((discard: d, waits: waits))
            }
        }

        res.sort { a, b in
            if a.waits.count != b.waits.count { return a.waits.count > b.waits.count }
            return a.discard < b.discard
        }

        if res.count > limit { return Array(res.prefix(limit)) }
        return res
    }

}
