import Foundation
import Combine

final class MahjongViewModel: ObservableObject {

    private static let hapticsKey: String = "hapticsEnabled"

    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Self.hapticsKey) }
    }

    @Published var language: AppLanguage {
        didSet {
            if language == oldValue { return }
            AppLanguage.save(language)
            refreshTextForLanguageChange()
        }
    }

    init() {
        let initialLanguage = AppLanguage.savedOrPreferred()
        self.hapticsEnabled = UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool ?? true
        self.language = initialLanguage
        self.outputText = AppText.initialOutput(initialLanguage)
    }

    @Published var clearAllNonce: Int = 0
    @Published var autoComputeEnabled: Bool = true

    @Published var ruleMode: MahjongRuleMode = .auto
    @Published var enableQiDui: Bool = true
    @Published var enable13yao: Bool = false

    // 四川定缺：万/筒/条
    @Published var dingque: Suit? = nil

    @Published var selectedTab: String = "m" // m/p/s/z
    @Published var counts34: [Int] = Array(repeating: 0, count: 34)

    @Published var melds: [Meld] = []

    @Published var outputText: String
    @Published var statusText: String = ""

    // MARK: - Mode

    /// 输入层限制：只有当用户明确选择“四川”时才禁止字牌
    private func inputTileLimit() -> Int {
        return (ruleMode == .sichuan) ? 27 : 34
    }

    private func resolvedMode(concealed: [Int], melds: [Meld]) -> MahjongRuleMode {
        switch ruleMode {
        case .sichuan:
            return .sichuan
        case .guangdong:
            return .guangdong
        case .auto:
            var hasHonor = false

            if concealed.count >= 34 {
                for i in 27..<34 {
                    if concealed[i] > 0 { hasHonor = true; break }
                }
            }

            if hasHonor == false {
                for m in melds {
                    if m.tileIndex >= 27 { hasHonor = true; break }
                }
            }

            return hasHonor ? .guangdong : .sichuan
        }
    }

    func resolveMode() -> MahjongRuleMode {
        return resolvedMode(concealed: counts34, melds: melds)
    }

    private func effectiveTileLimit(mode: MahjongRuleMode) -> Int {
        return (mode == .sichuan) ? 27 : 34
    }

    private func effectiveTileLimit() -> Int {
        return effectiveTileLimit(mode: resolveMode())
    }

    // MARK: - Helpers

    private func ownedCount(tile idx: Int, concealed: [Int], melds: [Meld], limit: Int) -> Int {
        if idx < 0 || idx >= limit { return 0 }

        var total = concealed[idx]
        for m in melds {
            if m.tileIndex == idx {
                total += m.displayTileCount
            }
        }
        return total
    }

    private func meldExtrasArray(limit: Int) -> [Int] {
        var extras = Array(repeating: 0, count: limit)
        for m in melds {
            let t = m.tileIndex
            if t >= 0 && t < limit {
                extras[t] += m.displayTileCount
            }
        }
        return extras
    }

    /// 纯校验：返回 nil 表示通过；返回 String 表示错误原因（不写 statusText）
    private func handCapsError(concealed: [Int], melds: [Meld]) -> String? {
        let mode = resolvedMode(concealed: concealed, melds: melds)
        let limit = effectiveTileLimit(mode: mode)

        if melds.count > 4 {
            return AppText.maxMeldsError(language)
        }

        var total = 0
        for i in 0..<limit { total += concealed[i] }

        var kongCount = 0
        for m in melds {
            if m.tileIndex < 0 || m.tileIndex >= limit { continue }
            total += m.displayTileCount
            if m.kind == .kong { kongCount += 1 }
        }

        if kongCount > 4 {
            return AppText.maxKongsError(language)
        }

        let maxTotal = 14 + kongCount
        if total > maxTotal {
            return AppText.maxTilesError(kongCount: kongCount, maxTotal: maxTotal, language: language)
        }

        for i in 0..<limit {
            let oc = ownedCount(tile: i, concealed: concealed, melds: melds, limit: limit)
            if oc > 4 {
                return AppText.tileExceededError(tile: MahjongEngine.tileName34(i, language: language), language: language)
            }
        }

        return nil
    }
    
    /// 带副作用校验：只用于“用户动作触发”的路径
    private func validateHandCaps(concealed: [Int], melds: [Meld]) -> Bool {
        if let msg = handCapsError(concealed: concealed, melds: melds) {
            statusText = msg
            return false
        }
        return true
    }

    private func refreshTextForLanguageChange() {
        statusText = ""
        if counts34.allSatisfy({ $0 == 0 }) && melds.isEmpty {
            outputText = AppText.initialOutput(language)
            return
        }
        compute()
    }


    // MARK: - Effective counts

    func handCountEffective() -> Int {
        let limit = effectiveTileLimit()
        var sum = 0

        for i in 0..<limit {
            sum += counts34[i]
        }
        for m in melds {
            if m.tileIndex >= 0 && m.tileIndex < limit {
                sum += m.displayTileCount
            }
        }
        return sum
    }

    func activeKongCountEffective() -> Int {
        let limit = effectiveTileLimit()
        var c = 0
        for m in melds {
            if m.kind == .kong && m.tileIndex >= 0 && m.tileIndex < limit {
                c += 1
            }
        }
        return c
    }

    func fixedMeldCountEffective() -> Int {
        return melds.count
    }

    // MARK: - Actions：加牌/减牌（暗手）

    func addTile(idx: Int) {
        if idx < 0 || idx >= counts34.count {
            if hapticsEnabled { Haptics.error() }
            return
        }

        // 只有明确四川才禁字牌
        if ruleMode == .sichuan, idx >= 27 {
            statusText = AppText.sichuanNoHonors(language)
            if hapticsEnabled { Haptics.error() }
            return
        }

        // 输入层限制（四川=27，其他=34）
        if idx >= inputTileLimit() {
            if hapticsEnabled { Haptics.error() }
            return
        }

        // 暗手+副露合计不得超过 4
        let checkLimit = (ruleMode == .sichuan) ? 27 : 34
        let oc = ownedCount(tile: idx, concealed: counts34, melds: melds, limit: checkLimit)
        if oc >= 4 {
            if hapticsEnabled { Haptics.error() }
            return
        }

        var tmp = counts34
        tmp[idx] += 1

        if !validateHandCaps(concealed: tmp, melds: melds) {
            if hapticsEnabled { Haptics.error() }
            return
        }

        counts34 = tmp
        statusText = ""
        if hapticsEnabled { Haptics.light() }
        autoComputeIfNeeded()
    }

    func removeTile(idx: Int) {
        if idx < 0 || idx >= counts34.count {
            if hapticsEnabled { Haptics.soft() }
            return
        }
        if counts34[idx] <= 0 {
            if hapticsEnabled { Haptics.soft() }
            return
        }

        counts34[idx] -= 1
        statusText = ""
        if hapticsEnabled { Haptics.soft() }
        autoComputeIfNeeded()
    }
    /// 供扫描结果写入：只覆盖“暗手 counts34”，不自动生成副露（碰/杠）。
    /// - newCounts34: 必须长度 >= 34；每张会 clamp 到 0..4
    /// - clearMelds: true 表示扫描即“重来”（清空副露）；false 表示保留你手动录入的副露
    func applyScannedConcealedCounts(_ newCounts34: [Int], clearMelds: Bool = false) {
        if newCounts34.count < 34 {
            statusText = AppText.scanCountsIncomplete(language)
            if hapticsEnabled { Haptics.error() }
            return
        }

        var tmp = Array(repeating: 0, count: 34)
        var i = 0
        while i < 34 {
            let v = newCounts34[i]
            if v <= 0 {
                tmp[i] = 0
            } else if v >= 4 {
                tmp[i] = 4
            } else {
                tmp[i] = v
            }
            i += 1
        }

        // 若用户明确选择四川：暗手不允许字牌
        if ruleMode == .sichuan {
            var j = 27
            while j < 34 {
                tmp[j] = 0
                j += 1
            }
        }

        // 副露：可选清空；若四川模式，顺便过滤掉字牌副露，避免残留脏状态
        var tmpMelds = melds
        if clearMelds {
            tmpMelds.removeAll()
        } else if ruleMode == .sichuan {
            var filtered: [Meld] = []
            for m in tmpMelds {
                if m.tileIndex < 27 { filtered.append(m) }
            }
            tmpMelds = filtered
        }

        // 用你现有校验（暗手+副露合计、每张<=4、总张数<=14+杠）
        if !validateHandCaps(concealed: tmp, melds: tmpMelds) {
            if hapticsEnabled { Haptics.error() }
            return
        }

        counts34 = tmp
        if clearMelds || ruleMode == .sichuan {
            melds = tmpMelds
        }

        statusText = ""
        if hapticsEnabled { Haptics.light() }
        autoComputeIfNeeded()
    }

    // MARK: - Actions：碰/杠

    func canPong(idx: Int) -> Bool {
        if idx < 0 || idx >= inputTileLimit() { return false }
        if counts34[idx] < 2 { return false }
        if melds.count >= 4 { return false }

        var tmpCounts = counts34
        tmpCounts[idx] -= 2

        var tmpMelds = melds
        tmpMelds.append(Meld(pong: idx))

        return handCapsError(concealed: tmpCounts, melds: tmpMelds) == nil
    }

    func pong(idx: Int) {
        if !canPong(idx: idx) {
            if hapticsEnabled { Haptics.error() }
            return
        }

        counts34[idx] -= 2
        melds.append(Meld(pong: idx))

        statusText = ""
        if hapticsEnabled { Haptics.medium() }
        autoComputeIfNeeded()
    }

    func canMingKong(idx: Int) -> Bool {
        if idx < 0 || idx >= inputTileLimit() { return false }
        if counts34[idx] < 3 { return false }
        if melds.count >= 4 { return false }

        var tmpCounts = counts34
        tmpCounts[idx] -= 3

        var tmpMelds = melds
        tmpMelds.append(Meld(kong: idx, type: .ming))

        return handCapsError(concealed: tmpCounts, melds: tmpMelds) == nil
    }

    func mingKong(idx: Int) {
        if !canMingKong(idx: idx) {
            if hapticsEnabled { Haptics.error() }
            return
        }

        counts34[idx] -= 3
        melds.append(Meld(kong: idx, type: .ming))

        statusText = ""
        if hapticsEnabled { Haptics.medium() }
        autoComputeIfNeeded()
    }

    func canAnKong(idx: Int) -> Bool {
        if idx < 0 || idx >= inputTileLimit() { return false }
        if counts34[idx] < 4 { return false }
        if melds.count >= 4 { return false }

        var tmpCounts = counts34
        tmpCounts[idx] -= 4

        var tmpMelds = melds
        tmpMelds.append(Meld(kong: idx, type: .an))

        return handCapsError(concealed: tmpCounts, melds: tmpMelds) == nil
    }

    func anKong(idx: Int) {
        if !canAnKong(idx: idx) {
            if hapticsEnabled { Haptics.error() }
            return
        }

        counts34[idx] -= 4
        melds.append(Meld(kong: idx, type: .an))

        statusText = ""
        if hapticsEnabled { Haptics.medium() }
        autoComputeIfNeeded()
    }

    func canAddKong(idx: Int) -> Bool {
        if idx < 0 || idx >= inputTileLimit() { return false }
        if counts34[idx] < 1 { return false }

        var pongPos: Int? = nil
        for i in 0..<melds.count {
            if melds[i].kind == .pong && melds[i].tileIndex == idx {
                pongPos = i
                break
            }
        }
        if pongPos == nil { return false }

        var tmpCounts = counts34
        tmpCounts[idx] -= 1

        var tmpMelds = melds
        if let p = pongPos {
            tmpMelds[p] = Meld(kong: idx, type: .add)
        }

        return handCapsError(concealed: tmpCounts, melds: tmpMelds) == nil
    }

    func addKong(idx: Int) {
        if !canAddKong(idx: idx) {
            if hapticsEnabled { Haptics.error() }
            return
        }

        counts34[idx] -= 1

        for i in 0..<melds.count {
            if melds[i].kind == .pong && melds[i].tileIndex == idx {
                melds[i] = Meld(kong: idx, type: .add)
                break
            }
        }

        statusText = ""
        if hapticsEnabled { Haptics.medium() }
        autoComputeIfNeeded()
    }

    /// 点击副露区删除：
    /// - 加杠：退回“碰”，并返还 1 张暗手
    /// - 其他：直接撤销，并返还消耗的暗手张数
    func removeMeld(id: UUID) {
        var pos: Int? = nil
        for i in 0..<melds.count {
            if melds[i].id == id { pos = i; break }
        }
        if pos == nil { return }

        let i = pos!
        let m = melds[i]
        let limit = inputTileLimit()

        if m.kind == .kong, m.kongType == .add {
            // 加杠 -> 退回碰，返还 1 张
            let t = m.tileIndex
            if t >= 0 && t < limit {
                counts34[t] += 1
            }
            melds[i] = Meld(pong: m.tileIndex)
        } else {
            // 直接撤销
            let t = m.tileIndex
            let back = m.consumedFromHand
            if t >= 0 && t < limit {
                counts34[t] += back
            }
            melds.remove(at: i)
        }

        statusText = ""
        if hapticsEnabled { Haptics.soft() }
        autoComputeIfNeeded()
    }

    // MARK: - Clear / Normalize

    func clearAll() {
        counts34 = Array(repeating: 0, count: 34)
        melds.removeAll()

        statusText = ""
        outputText = AppText.clearedOutput(language)

        clearAllNonce += 1
        autoComputeIfNeeded()
    }

    func normalizeForRuleMode() {
        if ruleMode == .sichuan {
            // 清字牌（暗手）
            for i in 27..<34 { counts34[i] = 0 }

            // 清字牌（副露）
            var filtered: [Meld] = []
            for m in melds {
                if m.tileIndex < 27 { filtered.append(m) }
            }
            melds = filtered

            if selectedTab == "z" { selectedTab = "m" }
        }
    }

    // MARK: - Auto compute

    func toggleAutoCompute() {
        let k = activeKongCountEffective()
        let cnt = handCountEffective()
        if cnt < 13 + k { return }

        autoComputeEnabled.toggle()
        if autoComputeEnabled { autoComputeIfNeeded() }
    }

    private func autoComputeIfNeeded() {
        if autoComputeEnabled == false { return }

        let k = activeKongCountEffective()
        let cnt = handCountEffective()

        if cnt == 13 + k || cnt == 14 + k {
            compute()
        }
    }

    // MARK: - Compute

    func compute() {
        let mode = resolveMode()

        let enable13 = (mode == .guangdong) ? enable13yao : false
        let enableQD = enableQiDui
        let dq: Suit? = (mode == .sichuan) ? dingque : nil

        let limit = effectiveTileLimit(mode: mode)

        let concealed: [Int] = Array(counts34[0..<limit])

        let meldExtras = meldExtrasArray(limit: limit)
        let fixedMeldCount = fixedMeldCountEffective()

        let k = activeKongCountEffective()
        let cnt = handCountEffective()

        var lines: [String] = []

        if mode == .sichuan {
            let dqText: String
            if let dq = dq {
                dqText = dq.choiceName(language: language)
            } else {
                dqText = AppText.notSet(language)
            }
            lines.append(AppText.summarySichuan(dingque: dqText,
                                                tileCount: cnt,
                                                kongCount: k,
                                                meldCount: fixedMeldCount,
                                                language: language))
        } else {
            lines.append(AppText.summaryGuangdong(tileCount: cnt,
                                                  kongCount: k,
                                                  meldCount: fixedMeldCount,
                                                  language: language))
        }

        if cnt == 13 + k {
            let waits = MahjongEngine.calcWaitsWithMelds(
                concealed: concealed,
                mode: mode,
                dingque: dq,
                enableQiDui: enableQD,
                enable13yao: enable13,
                fixedMeldCount: fixedMeldCount,
                meldExtras: meldExtras
            )

            lines.append("")
            lines.append(AppText.waitListTitle(tileCount: 13 + k, language: language))

            if waits.isEmpty {
                lines.append(AppText.noWaits(language))
            } else {
                let names = waits.map { MahjongEngine.tileName34($0, language: language) }.joined(separator: AppText.listSeparator(language))
                lines.append(AppText.waits(count: waits.count, names: names, language: language))
            }

        } else if cnt == 14 + k {

            let alreadyWin = MahjongEngine.isWinningWithMelds(
                concealed: concealed,
                mode: mode,
                dingque: dq,
                enableQiDui: enableQD,
                enable13yao: enable13,
                fixedMeldCount: fixedMeldCount,
                meldExtras: meldExtras
            )

            if alreadyWin {
                lines.append(AppText.alreadyWinning(tileCount: 14 + k, language: language))
                outputText = lines.joined(separator: "\n")
                return
            }

            lines.append(AppText.discardToSeeWaits(tileCount: 14 + k, language: language))

            let suggestions = MahjongEngine.calcSuggestionsWithMelds(
                concealed: concealed,
                mode: mode,
                dingque: dq,
                enableQiDui: enableQD,
                enable13yao: enable13,
                fixedMeldCount: fixedMeldCount,
                meldExtras: meldExtras,
                limit: 12
            )

            if suggestions.isEmpty {
                lines.append(AppText.noSuggestions(language))
            } else {
                for s in suggestions {
                    let dname = MahjongEngine.tileName34(s.discard, language: language)
                    let waits = s.waits.map { MahjongEngine.tileName34($0, language: language) }.joined(separator: " ")
                    lines.append(AppText.discardSuggestion(discard: dname, waits: waits, language: language))
                }
            }

            outputText = lines.joined(separator: "\n")
            return

        } else {
            lines.append("")
            lines.append(AppText.invalidCount(current: cnt, kongCount: k, language: language))
            lines.append(AppText.requiredCounts(waitCount: 13 + k, drawCount: 14 + k, language: language))
        }

        outputText = lines.joined(separator: "\n")
    }
}
