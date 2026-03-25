import Foundation

enum MahjongRuleMode: String, CaseIterable, Identifiable {
    case auto
    case sichuan
    case guangdong

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自动"
        case .sichuan: return "四川"
        case .guangdong: return "广东"
        }
    }
}

enum Suit: String, CaseIterable, Identifiable {
    case m  // 万
    case p  // 筒
    case s  // 条

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .m: return "萬"
        case .p: return "茼"
        case .s: return "條"
        }
    }
}

struct MahjongEngine {

    // 0..26: 万筒条；27..33: 东南西北白发中
    static func tileName34(_ idx: Int) -> String {
        if idx < 0 || idx >= 34 { return "?" } // 防御式
        
        if idx >= 27 {
            let names = ["東", "南", "西", "北", "白", "發", "中"]
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
        return "\(num)\(suit.displayName)"
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
    
    private static func applyKongs(_ counts: [Int], kongedTiles: Set<Int>) -> (work: [Int], k: Int) {
        var work = counts
        var k = 0
        
        for idx in kongedTiles {
            if idx < 0 || idx >= work.count { continue }
            if work[idx] >= 4 {
                work[idx] -= 4      // 已杠：4 张固定，不参与拆解
                k += 1
            }
        }
        return (work, k)
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
    
    // MARK: - 胡牌判定
    
    static func isWinningWithKongs(counts: [Int],
                                   mode: MahjongRuleMode,
                                   dingque: Suit?,
                                   enableQiDui: Bool,
                                   enable13yao: Bool,
                                   kongedTiles: Set<Int>) -> Bool {
        
        let (work, k) = applyKongs(counts, kongedTiles: kongedTiles)
        
        // 杠会补牌：完整形态应为 14 + k
        if counts.reduce(0, +) != 14 + k { return false }
        
        // 四川定缺检查仍针对“全部牌”（含杠牌也属于你的牌）
        if mode == .sichuan, let dq = dingque {
            if countSuit27(counts, dq) != 0 { return false }
        }
        
        // 已杠后按常见规则：七对/十三幺不再成立（副露/固定面子）
        let allowSpecial = (k == 0)
        
        if allowSpecial, enableQiDui, isQiDui(work) { return true }
        if allowSpecial, mode == .guangdong, enable13yao, work.count == 34, isThirteenOrphans(work) { return true }
        
        // 剩余可拆解牌必须能组成 (4-k) 个面子 + 1 将
        let workTotal = work.reduce(0, +)
        if workTotal != 14 - 3 * k { return false } // 14+k 扣掉 4k => 14-3k
        
        for pair in 0..<work.count {
            if work[pair] >= 2 {
                var tmp = work
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
    
    
    // MARK: - 听牌计算（13 张）
    static func calcWaitsFrom13(counts13: [Int],
                                mode: MahjongRuleMode,
                                dingque: Suit?,
                                enableQiDui: Bool,
                                enable13yao: Bool) -> [Int] {
        return calcWaitsWithKongs(counts: counts13,
                                  mode: mode,
                                  dingque: dingque,
                                  enableQiDui: enableQiDui,
                                  enable13yao: enable13yao,
                                  kongedTiles: Set<Int>())
    }
    
    static func isWinning(counts: [Int],
                          mode: MahjongRuleMode,
                          dingque: Suit?,
                          enableQiDui: Bool,
                          enable13yao: Bool) -> Bool {
        return isWinningWithKongs(counts: counts,
                                  mode: mode,
                                  dingque: dingque,
                                  enableQiDui: enableQiDui,
                                  enable13yao: enable13yao,
                                  kongedTiles: Set<Int>())
    }
    
    static func calcWaitsWithKongs(counts: [Int],
                                   mode: MahjongRuleMode,
                                   dingque: Suit?,
                                   enableQiDui: Bool,
                                   enable13yao: Bool,
                                   kongedTiles: Set<Int>) -> [Int] {
        
        let (_, k) = applyKongs(counts, kongedTiles: kongedTiles)
        
        // 听牌态应为 13 + k
        if counts.reduce(0, +) != 13 + k { return [] }
        
        // 四川未清缺不听
        if mode == .sichuan, let dq = dingque {
            if countSuit27(counts, dq) != 0 { return [] }
        }
        
        var waits: [Int] = []
        
        for t in 0..<counts.count {
            if counts[t] >= 4 { continue } // 牌已经 4 张，不可能再胡这张
            
            // 四川：不听缺门
            if mode == .sichuan, let dq = dingque, counts.count == 27 {
                if suitOf27(t) == dq { continue }
            }
            
            var tmp = counts
            tmp[t] += 1
            
            if isWinningWithKongs(counts: tmp,
                                  mode: mode,
                                  dingque: dingque,
                                  enableQiDui: enableQiDui,
                                  enable13yao: enable13yao,
                                  kongedTiles: kongedTiles) {
                waits.append(t)
            }
        }
        
        return waits
    }
    
    // MARK: - 出牌建议（支持已杠锁定：杠牌不可打出）
    static func calcSuggestionsWithKongs(
        counts: [Int],
        mode: MahjongRuleMode,
        dingque: Suit?,
        enableQiDui: Bool,
        enable13yao: Bool,
        kongedTiles: Set<Int>,
        limit: Int = 12
    ) -> [(discard: Int, waits: [Int])] {
        
        var activeKonged: Set<Int> = []
        for idx in kongedTiles {
            if idx >= 0 && idx < counts.count && counts[idx] >= 4 {
                activeKonged.insert(idx)
            }
        }
        
        let (_, k) = applyKongs(counts, kongedTiles: activeKonged)
        if counts.reduce(0, +) != 14 + k { return [] }
        
        var discards: [Int] = []
        for i in 0..<counts.count {
            if counts[i] <= 0 { continue }
            if activeKonged.contains(i) { continue }   // 杠牌不可打出
            discards.append(i)
        }
        
        if mode == .sichuan, let dq = dingque {
            if countSuit27(counts, dq) != 0 {
                discards = discards.filter { suitOf27($0) == dq && !activeKonged.contains($0) }
            }
        }
        
        var res: [(discard: Int, waits: [Int])] = []
        
        for d in discards {
            var tmp = counts
            tmp[d] -= 1
            
            let waits = calcWaitsWithKongs(
                counts: tmp,
                mode: mode,
                dingque: dingque,
                enableQiDui: enableQiDui,
                enable13yao: enable13yao,
                kongedTiles: activeKonged
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
    
    static func calcSuggestionsFrom14(
        counts14: [Int],
        mode: MahjongRuleMode,
        dingque: Suit?,
        enableQiDui: Bool,
        enable13yao: Bool,
        limit: Int = 12
    ) -> [(discard: Int, waits: [Int])] {
        
        // 兼容旧逻辑：默认无杠
        return calcSuggestionsWithKongs(
            counts: counts14,
            mode: mode,
            dingque: dingque,
            enableQiDui: enableQiDui,
            enable13yao: enable13yao,
            kongedTiles: Set<Int>(),
            limit: limit
        )
    }
    // MARK: - 方案B：副露（碰/杠）剥离版接口

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
