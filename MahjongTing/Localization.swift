import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh
    case en
    case ja

    private static let storageKey: String = "appLanguage"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }

    static func savedOrPreferred() -> AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let saved = AppLanguage(rawValue: raw) {
            return saved
        }
        return preferred()
    }

    static func save(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
    }

    private static func preferred() -> AppLanguage {
        for identifier in Locale.preferredLanguages {
            let code = identifier.lowercased()
            if code.hasPrefix("zh") { return .zh }
            if code.hasPrefix("ja") { return .ja }
            if code.hasPrefix("en") { return .en }
        }
        return .zh
    }
}

enum CameraFailureMessage {
    static let noBackCamera = "camera.noBackCamera"
    private static let inputFailedPrefix = "camera.inputFailed|"

    static func inputFailed(_ detail: String) -> String {
        return inputFailedPrefix + detail
    }

    static func localized(_ raw: String, language: AppLanguage) -> String {
        if raw == noBackCamera {
            switch language {
            case .zh: return "未找到后置摄像头。"
            case .en: return "No rear camera was found."
            case .ja: return "背面カメラが見つかりません。"
            }
        }

        if raw.hasPrefix(inputFailedPrefix) {
            let detail = String(raw.dropFirst(inputFailedPrefix.count))
            switch language {
            case .zh: return "相机输入创建失败：\(detail)"
            case .en: return "Failed to create camera input: \(detail)"
            case .ja: return "カメラ入力の作成に失敗しました：\(detail)"
            }
        }

        return raw
    }
}

enum AppText {
    static func appTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "麻将听牌助手"
        case .en: return "Mahjong Ting Helper"
        case .ja: return "麻雀テンパイ助手"
        }
    }

    static func settingsTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "设置"
        case .en: return "Settings"
        case .ja: return "設定"
        }
    }

    static func languageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "语言"
        case .en: return "Language"
        case .ja: return "言語"
        }
    }

    static func rulesTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "规则"
        case .en: return "Rules"
        case .ja: return "ルール"
        }
    }

    static func ruleModeName(_ mode: MahjongRuleMode, language: AppLanguage) -> String {
        switch mode {
        case .auto:
            switch language {
            case .zh: return "自动"
            case .en: return "Auto"
            case .ja: return "自動"
            }
        case .sichuan:
            switch language {
            case .zh: return "四川"
            case .en: return "Sichuan"
            case .ja: return "四川"
            }
        case .guangdong:
            switch language {
            case .zh: return "广东"
            case .en: return "Guangdong"
            case .ja: return "広東"
            }
        }
    }

    static func dingqueTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "四川定缺"
        case .en: return "Sichuan Missing Suit"
        case .ja: return "四川の欠色設定"
        }
    }

    static func dingquePickerTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "定缺"
        case .en: return "Missing Suit"
        case .ja: return "欠色"
        }
    }

    static func notSet(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "不设置"
        case .en: return "Not Set"
        case .ja: return "未設定"
        }
    }

    static func winningOptionsTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "胡牌选项"
        case .en: return "Winning Options"
        case .ja: return "和了オプション"
        }
    }

    static func sevenPairs(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "七对"
        case .en: return "Seven Pairs"
        case .ja: return "七対子"
        }
    }

    static func thirteenOrphansGuangdongOnly(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "十三幺（仅广东）"
        case .en: return "Thirteen Orphans (Guangdong only)"
        case .ja: return "十三么九（広東のみ）"
        }
    }

    static func feedbackTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "反馈"
        case .en: return "Feedback"
        case .ja: return "フィードバック"
        }
    }

    static func haptics(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "震动反馈"
        case .en: return "Haptic Feedback"
        case .ja: return "振動フィードバック"
        }
    }

    static func computeTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "计算"
        case .en: return "Calculation"
        case .ja: return "計算"
        }
    }

    static func startCompute(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "开始计算"
        case .en: return "Start Calculation"
        case .ja: return "計算を開始"
        }
    }

    static func stopCompute(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "停止计算"
        case .en: return "Stop Calculation"
        case .ja: return "計算を停止"
        }
    }

    static func dataTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "数据"
        case .en: return "Data"
        case .ja: return "データ"
        }
    }

    static func clearHand(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "清空手牌"
        case .en: return "Clear Hand"
        case .ja: return "手牌をクリア"
        }
    }

    static func tileCount(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "张数 \(count)"
        case .en: return "Tiles \(count)"
        case .ja: return "枚数 \(count)"
        }
    }

    static func kongCount(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "杠 \(count)"
        case .en: return "Kongs \(count)"
        case .ja: return "槓 \(count)"
        }
    }

    static func autoStatus(_ enabled: Bool, language: AppLanguage) -> String {
        switch language {
        case .zh: return enabled ? "自动" : "暂停"
        case .en: return enabled ? "Auto" : "Paused"
        case .ja: return enabled ? "自動" : "一時停止"
        }
    }

    static func tileEntryTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "点牌"
        case .en: return "Tile Entry"
        case .ja: return "牌入力"
        }
    }

    static func categoryTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "类别"
        case .en: return "Category"
        case .ja: return "種類"
        }
    }

    static func resultTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "结果"
        case .en: return "Result"
        case .ja: return "結果"
        }
    }

    static func copy(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "复制"
        case .en: return "Copy"
        case .ja: return "コピー"
        }
    }

    static func handTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "手牌"
        case .en: return "Hand"
        case .ja: return "手牌"
        }
    }

    static func meldCount(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "副露 \(count)"
        case .en: return "Melds \(count)"
        case .ja: return "副露 \(count)"
        }
    }

    static func meldsTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "副露"
        case .en: return "Melds"
        case .ja: return "副露"
        }
    }

    static func noMelds(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "暂无副露（碰/杠后会显示在这里）"
        case .en: return "No melds yet. Pongs and kongs appear here."
        case .ja: return "副露はありません。ポン/カン後にここに表示されます。"
        }
    }

    static func concealedTitle(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "暗手"
        case .en: return "Concealed Tiles"
        case .ja: return "手の内"
        }
    }

    static func tapTilesHint(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "点下方牌面录入"
        case .en: return "Tap tiles below to enter your hand"
        case .ja: return "下の牌をタップして入力"
        }
    }

    static func suitTabName(_ suit: Suit, language: AppLanguage) -> String {
        switch suit {
        case .m:
            switch language {
            case .zh: return "萬"
            case .en: return "Man"
            case .ja: return "萬"
            }
        case .p:
            switch language {
            case .zh: return "筒"
            case .en: return "Pin"
            case .ja: return "筒"
            }
        case .s:
            switch language {
            case .zh: return "條"
            case .en: return "Sou"
            case .ja: return "索"
            }
        }
    }

    static func honorsTabName(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "字"
        case .en: return "Hon"
        case .ja: return "字"
        }
    }

    static func suitChoiceName(_ suit: Suit, language: AppLanguage) -> String {
        switch suit {
        case .m:
            switch language {
            case .zh: return "万"
            case .en: return "Characters"
            case .ja: return "萬子"
            }
        case .p:
            switch language {
            case .zh: return "筒"
            case .en: return "Dots"
            case .ja: return "筒子"
            }
        case .s:
            switch language {
            case .zh: return "条"
            case .en: return "Bamboo"
            case .ja: return "索子"
            }
        }
    }

    static func suitTileSuffix(_ suit: Suit, language: AppLanguage) -> String {
        switch suit {
        case .m:
            switch language {
            case .zh: return "萬"
            case .en: return "m"
            case .ja: return "萬"
            }
        case .p:
            switch language {
            case .zh: return "筒"
            case .en: return "p"
            case .ja: return "筒"
            }
        case .s:
            switch language {
            case .zh: return "條"
            case .en: return "s"
            case .ja: return "索"
            }
        }
    }

    static func honorTileNames(_ language: AppLanguage) -> [String] {
        switch language {
        case .zh:
            return ["東", "南", "西", "北", "白", "發", "中"]
        case .en:
            return ["East", "South", "West", "North", "White", "Green", "Red"]
        case .ja:
            return ["東", "南", "西", "北", "白", "發", "中"]
        }
    }

    static func concealedActionName(_ kind: ConcealedHandActionKind, language: AppLanguage) -> String {
        switch kind {
        case .addKong:
            switch language {
            case .zh: return "加杠"
            case .en: return "Add Kong"
            case .ja: return "加槓"
            }
        case .anKong:
            switch language {
            case .zh: return "暗杠"
            case .en: return "Concealed Kong"
            case .ja: return "暗槓"
            }
        case .mingKong:
            switch language {
            case .zh: return "杠"
            case .en: return "Kong"
            case .ja: return "槓"
            }
        case .pong:
            switch language {
            case .zh: return "碰"
            case .en: return "Pong"
            case .ja: return "ポン"
            }
        }
    }

    static func meldDisplayName(kind: MeldKind, kongType: KongType?, language: AppLanguage) -> String {
        if kind == .pong {
            switch language {
            case .zh: return "碰"
            case .en: return "Pong"
            case .ja: return "ポン"
            }
        }

        if kind == .kong {
            if kongType == .an {
                switch language {
                case .zh: return "暗杠"
                case .en: return "Concealed Kong"
                case .ja: return "暗槓"
                }
            }
            if kongType == .ming {
                switch language {
                case .zh: return "明杠"
                case .en: return "Open Kong"
                case .ja: return "明槓"
                }
            }
            if kongType == .add {
                switch language {
                case .zh: return "加杠"
                case .en: return "Added Kong"
                case .ja: return "加槓"
                }
            }
            switch language {
            case .zh: return "杠"
            case .en: return "Kong"
            case .ja: return "槓"
            }
        }

        return meldsTitle(language)
    }

    static func initialOutput(_ language: AppLanguage) -> String {
        switch language {
        case .zh:
            return "请点牌录入 13/14 张（不含花）。满足张数后会自动计算；可用“停止计算”暂停。"
        case .en:
            return "Tap tiles to enter 13/14 tiles, excluding flowers. The app calculates automatically when the count is valid; use Stop Calculation to pause."
        case .ja:
            return "牌をタップして 13/14 枚（花牌を除く）を入力してください。必要枚数になると自動計算します。「計算を停止」で一時停止できます。"
        }
    }

    static func clearedOutput(_ language: AppLanguage) -> String {
        switch language {
        case .zh:
            return "已清空。请点牌录入 13/14 张（不含花）。满足张数后会自动计算。"
        case .en:
            return "Cleared. Tap tiles to enter 13/14 tiles, excluding flowers. The app calculates automatically when the count is valid."
        case .ja:
            return "クリアしました。牌をタップして 13/14 枚（花牌を除く）を入力してください。必要枚数になると自動計算します。"
        }
    }

    static func maxMeldsError(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "副露面子最多 4 组（碰/杠合计）。"
        case .en: return "You can have at most 4 melds total, including pongs and kongs."
        case .ja: return "副露面子は最大 4 組です（ポン/カン合計）。"
        }
    }

    static func maxKongsError(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "最多只能有 4 个杠。"
        case .en: return "You can have at most 4 kongs."
        case .ja: return "槓は最大 4 つまでです。"
        }
    }

    static func maxTilesError(kongCount: Int, maxTotal: Int, language: AppLanguage) -> String {
        switch language {
        case .zh:
            return "当前杠数为 \(kongCount)，最多只能输入 \(maxTotal) 张（14+\(kongCount)）。"
        case .en:
            return "With \(kongCount) kongs, you can enter at most \(maxTotal) tiles (14+\(kongCount))."
        case .ja:
            return "現在の槓数は \(kongCount) です。入力できる牌は最大 \(maxTotal) 枚（14+\(kongCount)）です。"
        }
    }

    static func tileExceededError(tile: String, language: AppLanguage) -> String {
        switch language {
        case .zh:
            return "\(tile) 超过 4 张（暗手+副露合计）。"
        case .en:
            return "\(tile) exceeds 4 copies across concealed tiles and melds."
        case .ja:
            return "\(tile) が 4 枚を超えています（手の内+副露合計）。"
        }
    }

    static func sichuanNoHonors(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "四川麻将通常不使用字牌。请切换为广东或自动。"
        case .en: return "Sichuan Mahjong usually does not use honor tiles. Switch to Guangdong or Auto."
        case .ja: return "四川麻雀では通常、字牌を使用しません。広東または自動に切り替えてください。"
        }
    }

    static func scanCountsIncomplete(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "扫描结果不完整（counts34 长度不足 34）。"
        case .en: return "The scan result is incomplete. counts34 has fewer than 34 entries."
        case .ja: return "スキャン結果が不完全です（counts34 が 34 件未満です）。"
        }
    }

    static func scanTooManyTile(tile: String, language: AppLanguage) -> String {
        switch language {
        case .zh: return "识别结果异常：\(tile) 超过 4 张，请重拍。"
        case .en: return "Scan result looks invalid: \(tile) appears more than 4 times. Please scan again."
        case .ja: return "認識結果が不正です：\(tile) が 4 枚を超えています。撮り直してください。"
        }
    }

    static func summarySichuan(dingque: String, tileCount: Int, kongCount: Int, meldCount: Int, language: AppLanguage) -> String {
        switch language {
        case .zh:
            return "规则：四川  定缺：\(dingque)  有效张数：\(tileCount)  杠：\(kongCount)  副露：\(meldCount)"
        case .en:
            return "Rules: Sichuan  Missing suit: \(dingque)  Effective tiles: \(tileCount)  Kongs: \(kongCount)  Melds: \(meldCount)"
        case .ja:
            return "ルール：四川  欠色：\(dingque)  有効枚数：\(tileCount)  槓：\(kongCount)  副露：\(meldCount)"
        }
    }

    static func summaryGuangdong(tileCount: Int, kongCount: Int, meldCount: Int, language: AppLanguage) -> String {
        switch language {
        case .zh:
            return "规则：广东  有效张数：\(tileCount)  杠：\(kongCount)  副露：\(meldCount)"
        case .en:
            return "Rules: Guangdong  Effective tiles: \(tileCount)  Kongs: \(kongCount)  Melds: \(meldCount)"
        case .ja:
            return "ルール：広東  有効枚数：\(tileCount)  槓：\(kongCount)  副露：\(meldCount)"
        }
    }

    static func waitListTitle(tileCount: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "【\(tileCount) 张】听牌列表："
        case .en: return "[\(tileCount) tiles] Ready hand waits:"
        case .ja: return "【\(tileCount) 枚】テンパイ一覧："
        }
    }

    static func noWaits(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "未找到可胡牌（当前不听牌）。"
        case .en: return "No winning waits found. The hand is not ready."
        case .ja: return "和了牌は見つかりません（現在テンパイしていません）。"
        }
    }

    static func waits(count: Int, names: String, language: AppLanguage) -> String {
        switch language {
        case .zh: return "听 \(count) 种：\(names)"
        case .en: return "\(count) wait(s): \(names)"
        case .ja: return "待ち \(count) 種：\(names)"
        }
    }

    static func alreadyWinning(tileCount: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "【\(tileCount) 张】当前牌型：已胡牌。"
        case .en: return "[\(tileCount) tiles] Current hand: already winning."
        case .ja: return "【\(tileCount) 枚】現在の牌姿：和了済み。"
        }
    }

    static func discardToSeeWaits(tileCount: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "【\(tileCount) 张】当前未胡牌：请先打出 1 张查看听牌。"
        case .en: return "[\(tileCount) tiles] Not winning yet. Discard 1 tile to check waits."
        case .ja: return "【\(tileCount) 枚】現在は和了していません。1 枚打ってテンパイを確認してください。"
        }
    }

    static func noSuggestions(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "当前排列不能胡牌（打出任意一张也无法进入听牌）。"
        case .en: return "No discard can move this hand into ready state."
        case .ja: return "どの牌を打ってもテンパイに入れません。"
        }
    }

    static func discardSuggestion(discard: String, waits: String, language: AppLanguage) -> String {
        switch language {
        case .zh: return "打 \(discard) -> 听 \(waits)"
        case .en: return "Discard \(discard) -> wait \(waits)"
        case .ja: return "\(discard) を打つ -> 待ち \(waits)"
        }
    }

    static func invalidCount(current: Int, kongCount: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "张数不满足：当前有效 \(current) 张，杠 \(kongCount) 次。"
        case .en: return "Invalid tile count: \(current) effective tiles, \(kongCount) kongs."
        case .ja: return "枚数が合いません：現在有効 \(current) 枚、槓 \(kongCount) 回。"
        }
    }

    static func requiredCounts(waitCount: Int, drawCount: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "需要 \(waitCount)（听牌态）或 \(drawCount)（抓牌态）。"
        case .en: return "Needs \(waitCount) for ready state or \(drawCount) after drawing."
        case .ja: return "\(waitCount)（テンパイ状態）または \(drawCount)（ツモ後状態）が必要です。"
        }
    }

    static func listSeparator(_ language: AppLanguage) -> String {
        switch language {
        case .zh, .ja: return "、"
        case .en: return ", "
        }
    }

    static func scanInstruction(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "将手牌放入画面中，点击“扫描”。系统会自动识别牌区域。"
        case .en: return "Place your hand in the frame and tap Scan. The app will detect the tile row automatically."
        case .ja: return "手牌を画面内に置いて「スキャン」をタップしてください。牌の列を自動認識します。"
        }
    }

    static func cancel(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "取消"
        case .en: return "Cancel"
        case .ja: return "キャンセル"
        }
    }

    static func scan(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "扫描"
        case .en: return "Scan"
        case .ja: return "スキャン"
        }
    }

    static func processing(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "处理中…"
        case .en: return "Processing..."
        case .ja: return "処理中…"
        }
    }

    static func cameraPermissionDenied(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "相机权限未开启。请在系统设置中允许本 App 使用相机。"
        case .en: return "Camera permission is off. Allow this app to use the camera in System Settings."
        case .ja: return "カメラ権限がオフです。システム設定でこの App のカメラ使用を許可してください。"
        }
    }

    static func cameraNotReady(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "相机尚未就绪，请稍等。"
        case .en: return "The camera is not ready yet. Please wait."
        case .ja: return "カメラはまだ準備中です。しばらくお待ちください。"
        }
    }

    static func scanning(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "扫描中…"
        case .en: return "Scanning..."
        case .ja: return "スキャン中…"
        }
    }

    static func capturedFrames(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .zh: return "已捕获 \(count) 帧，处理中…"
        case .en: return "Captured \(count) frames. Processing..."
        case .ja: return "\(count) フレームを取得しました。処理中…"
        }
    }

    static func recognizerReturnedEmpty(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "识别模型尚未接入（当前返回空结果）。"
        case .en: return "The recognition model is not wired up yet and returned no tiles."
        case .ja: return "認識モデルがまだ接続されていません（空の結果が返りました）。"
        }
    }

    static func recognitionDone(_ language: AppLanguage) -> String {
        switch language {
        case .zh: return "识别完成"
        case .en: return "Recognition complete"
        case .ja: return "認識完了"
        }
    }

    static func recognitionFailed(_ detail: String, language: AppLanguage) -> String {
        switch language {
        case .zh: return "识别失败：\(detail)（请重拍）"
        case .en: return "Recognition failed: \(detail). Please scan again."
        case .ja: return "認識に失敗しました：\(detail)。撮り直してください。"
        }
    }

    static func scanError(_ detail: String, language: AppLanguage) -> String {
        switch language {
        case .zh: return "错误：\(detail)"
        case .en: return "Error: \(detail)"
        case .ja: return "エラー：\(detail)"
        }
    }
}
