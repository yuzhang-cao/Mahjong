import SwiftUI
import UIKit

private enum SessionOnce {
    static var didShowBrandBanner: Bool = false
}

private struct BrandBanner: View {
    let language: AppLanguage

    var body: some View {
        Text(AppText.appTitle(language))
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .appleClip(AppleCornerRadius.panel)
            .shadow(radius: 6)
            .padding(.top, 10)
    }
}

enum ConcealedHandActionKind: String {
    case addKong
    case anKong
    case mingKong
    case pong
}

private struct ConcealedHandAction: Identifiable {
    let tileIndex: Int
    let kind: ConcealedHandActionKind

    var id: String {
        "\(tileIndex)-\(kind.rawValue)"
    }
}

private struct SettingsSheet: View {
    @ObservedObject var vm: MahjongViewModel
    @Binding var isPresented: Bool

    private var modeResolved: MahjongRuleMode { vm.resolveMode() }

    private var canToggleAuto: Bool {
        let k = vm.activeKongCountEffective()
        let cnt = vm.handCountEffective()
        return cnt >= 13 + k
    }

    var body: some View {
        let form = Form {
            Section(AppText.languageTitle(vm.language)) {
                Picker(AppText.languageTitle(vm.language), selection: $vm.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }

            Section(AppText.rulesTitle(vm.language)) {
                Picker(AppText.rulesTitle(vm.language), selection: $vm.ruleMode) {
                    ForEach(MahjongRuleMode.allCases) { m in
                        Text(m.displayName(language: vm.language)).tag(m)
                    }
                }
                .onChange(of: vm.ruleMode) { _, _ in
                    vm.normalizeForRuleMode()
                    if vm.autoComputeEnabled {
                        vm.compute()
                    }
                }
            }

            if modeResolved == .sichuan {
                Section(AppText.dingqueTitle(vm.language)) {
                    Picker(AppText.dingquePickerTitle(vm.language), selection: $vm.dingque) {
                        Text(AppText.notSet(vm.language)).tag(nil as Suit?)
                        Text(Suit.m.choiceName(language: vm.language)).tag(Suit.m as Suit?)
                        Text(Suit.p.choiceName(language: vm.language)).tag(Suit.p as Suit?)
                        Text(Suit.s.choiceName(language: vm.language)).tag(Suit.s as Suit?)
                    }
                }
            }

            Section(AppText.winningOptionsTitle(vm.language)) {
                Toggle(AppText.sevenPairs(vm.language), isOn: $vm.enableQiDui)

                Toggle(AppText.thirteenOrphansGuangdongOnly(vm.language), isOn: $vm.enable13yao)
                    .disabled(modeResolved != .guangdong)
                    .opacity(modeResolved != .guangdong ? 0.35 : 1.0)
            }

            Section(AppText.feedbackTitle(vm.language)) {
                Toggle(AppText.haptics(vm.language), isOn: $vm.hapticsEnabled)
            }

            Section(AppText.computeTitle(vm.language)) {
                Button(vm.autoComputeEnabled ? AppText.stopCompute(vm.language) : AppText.startCompute(vm.language)) {
                    vm.toggleAutoCompute()
                }
                .disabled(!canToggleAuto)
                .opacity(!canToggleAuto ? 0.35 : 1.0)
            }

            Section(AppText.dataTitle(vm.language)) {
                Button(role: .destructive) {
                    vm.clearAll()
                    isPresented = false
                } label: {
                    Text(AppText.clearHand(vm.language))
                }
            }
        }

        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { form }
            } else {
                NavigationView { form }
            }
        }
        .navigationTitle(AppText.settingsTitle(vm.language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MainView: View {
    @State private var showScan: Bool = false
    @State private var showSettings: Bool = false
    @State private var showBrand: Bool = !SessionOnce.didShowBrandBanner
    @StateObject private var vm: MahjongViewModel = MahjongViewModel()

    private let columns9: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let columns7: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private let handChipMinWidth: CGFloat = 150
    private let handChipRowHeight: CGFloat = 44
    private let handChipSpacing: CGFloat = 10
    private let concealedTileAspectRatio: CGFloat = 0.72
    private let concealedTileMinWidth: CGFloat = 28
    private let concealedTileMaxWidth: CGFloat = 42
    private let concealedTileSpacing: CGFloat = 4

    private let handAccessoryHeight: CGFloat = 28

    private var handColumns: [GridItem] {
        [GridItem(.adaptive(minimum: handChipMinWidth), spacing: handChipSpacing)]
    }

    private var concealedHandRowHeight: CGFloat {
        concealedTileMaxWidth / concealedTileAspectRatio + 8
    }

    private var hasTilesInHand: Bool {
        vm.counts34.contains { $0 > 0 }
    }

    private var concealedHandTiles: [Int] {
        var tiles: [Int] = []
        let limit = min(vm.counts34.count, 34)
        for idx in 0..<limit {
            let count = vm.counts34[idx]
            if count > 0 {
                tiles.append(contentsOf: Array(repeating: idx, count: count))
            }
        }
        return tiles
    }

    private func startIndex(for tab: String) -> Int {
        if tab == "m" { return 0 }
        if tab == "p" { return 9 }
        return 18
    }

    var body: some View {
        let mode = vm.resolveMode()
        let k = vm.activeKongCountEffective()
        let cnt = vm.handCountEffective()

        let topID = "TOP_ANCHOR"

        let content = ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    Color.clear
                        .frame(height: 0)
                        .id(topID)
                        .allowsHitTesting(false)

                    HStack(spacing: 10) {
                        statusChip(mode.displayName(language: vm.language), isPrimary: true)
                        statusChip(AppText.tileCount(cnt, language: vm.language))
                        statusChip(AppText.kongCount(k, language: vm.language))

                        Spacer()

                        statusChip(AppText.autoStatus(vm.autoComputeEnabled, language: vm.language))
                    }

                    handPanel()

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(AppText.tileEntryTitle(vm.language))
                                .font(.footnote.weight(.semibold))
                            Spacer()
                        }

                        Picker(AppText.categoryTitle(vm.language), selection: $vm.selectedTab) {
                            Text(AppText.suitTabName(.m, language: vm.language)).tag("m")
                            Text(AppText.suitTabName(.p, language: vm.language)).tag("p")
                            Text(AppText.suitTabName(.s, language: vm.language)).tag("s")
                            Text(AppText.honorsTabName(vm.language)).tag("z")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: vm.selectedTab) { _, _ in
                            if vm.ruleMode == .sichuan && vm.selectedTab == "z" {
                                vm.selectedTab = "m"
                            }
                        }

                        if vm.selectedTab == "z" {
                            LazyVGrid(columns: columns7, spacing: 10) {
                                ForEach(27..<34, id: \.self) { i in
                                    tileButton(idx: i)
                                }
                            }
                        } else {
                            LazyVGrid(columns: columns9, spacing: 10) {
                                ForEach(0..<9, id: \.self) { t in
                                    tileButton(idx: startIndex(for: vm.selectedTab) + t)
                                }
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(AppText.resultTitle(vm.language))
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Button {
                                UIPasteboard.general.string = vm.outputText
                            } label: {
                                Text(AppText.copy(vm.language))
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .background(Color(.systemGray6))
                                    .appleClip(AppleCornerRadius.badge)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(vm.outputText)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color(.systemGray6))
                            .appleClip(AppleCornerRadius.control)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .refreshable {
                vm.clearAll()
                if vm.hapticsEnabled {
                    Haptics.warning()
                }
            }
            .onChange(of: vm.clearAllNonce) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(topID, anchor: .top)
                    }
                }
            }
        }

        return Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    content
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                HStack(spacing: 14) {
                                    toolbarIconButton(systemName: "camera.viewfinder") { showScan = true }
                                    toolbarIconButton(systemName: "gearshape") { showSettings = true }
                                }
                            }
                        }
                        .sheet(isPresented: $showScan) {
                            ScanSheet(vm: vm)
                        }
                }
            } else {
                NavigationView {
                    content
                        .navigationBarTitle("", displayMode: .inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                HStack(spacing: 14) {
                                    toolbarIconButton(systemName: "camera.viewfinder") { showScan = true }
                                    toolbarIconButton(systemName: "gearshape") { showSettings = true }
                                }
                            }
                        }
                        .sheet(isPresented: $showScan) {
                            ScanSheet(vm: vm)
                        }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(vm: vm, isPresented: $showSettings)
        }
        .overlay(alignment: .top) {
            if showBrand {
                BrandBanner(language: vm.language)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            if showBrand {
                SessionOnce.didShowBrandBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showBrand = false
                    }
                }
            }
        }
    }

    private func handPanel() -> some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {
                Text(AppText.handTitle(vm.language))
                    .font(.headline.weight(.semibold))
                Spacer()
                if !vm.melds.isEmpty {
                    Text(AppText.meldCount(vm.melds.count, language: vm.language))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemBackground))
                        .appleClip(AppleCornerRadius.badge)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(AppText.meldsTitle(vm.language))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)

                if vm.melds.isEmpty {
                    Text(AppText.noMelds(vm.language))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: handChipRowHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .appleClip(AppleCornerRadius.control)
                        .appleStroke(Color(.systemGray4), radius: AppleCornerRadius.control)
                } else {
                    LazyVGrid(columns: handColumns, alignment: .leading, spacing: handChipSpacing) {
                        ForEach(vm.melds) { m in
                            Button {
                                vm.removeMeld(id: m.id)
                            } label: {
                                let name = MahjongEngine.tileName34(m.tileIndex, language: vm.language)
                                HStack(spacing: 10) {
                                    Text("\(m.displayName(language: vm.language)) \(name)")
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)

                                    Spacer(minLength: 8)

                                    Text("×\(m.displayTileCount)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: handChipRowHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .appleClip(AppleCornerRadius.control)
                                .appleStroke(Color(.systemGray4), radius: AppleCornerRadius.control)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(AppText.concealedTitle(vm.language))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)

                if hasTilesInHand {
                    let tiles = concealedHandTiles
                    let actions = concealedHandActions()

                    concealedHandRow(tiles: tiles)

                    if !actions.isEmpty {
                        concealedActionBar(actions: actions)
                    }
                } else {
                    Text(AppText.tapTilesHint(vm.language))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: handChipRowHeight)
                        .padding(.horizontal, 10)
                        .background(Color(.systemBackground))
                        .appleClip(AppleCornerRadius.control)
                        .appleStroke(Color(.systemGray4), radius: AppleCornerRadius.control)
                }

                if !vm.statusText.isEmpty {
                    Text(vm.statusText)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .appleClip(AppleCornerRadius.panel)
        .appleStroke(Color(.systemGray5), radius: AppleCornerRadius.panel)
    }

    private func concealedHandRow(tiles: [Int]) -> some View {
        GeometryReader { proxy in
            let tileWidth = concealedTileWidth(containerWidth: proxy.size.width, tileCount: tiles.count)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: concealedTileSpacing) {
                    ForEach(tiles.indices, id: \.self) { position in
                        concealedHandTile(idx: tiles[position], width: tileWidth)
                    }
                }
                .frame(minWidth: proxy.size.width, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
        .frame(height: concealedHandRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func concealedTileWidth(containerWidth: CGFloat, tileCount: Int) -> CGFloat {
        guard tileCount > 0 else { return concealedTileMaxWidth }

        let spacing = concealedTileSpacing * CGFloat(max(tileCount - 1, 0))
        let available = max(containerWidth - spacing, 0)
        let fittingWidth = floor(available / CGFloat(tileCount))

        return min(concealedTileMaxWidth, max(concealedTileMinWidth, fittingWidth))
    }

    private func concealedHandTile(idx: Int, width: CGFloat) -> some View {
        let height = width / concealedTileAspectRatio
        let cornerRadius = max(4, width * 0.14)
        let fontSize = min(16, max(10, width * 0.38))

        return Button {
            vm.removeTile(idx: idx)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)

                Text(MahjongEngine.tileName34(idx, language: vm.language))
                    .font(.system(size: fontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .padding(.horizontal, 2)
            }
            .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
    }

    private func concealedHandActions() -> [ConcealedHandAction] {
        var actions: [ConcealedHandAction] = []

        for idx in 0..<34 {
            if vm.canAddKong(idx: idx) {
                actions.append(ConcealedHandAction(tileIndex: idx, kind: .addKong))
            } else if vm.canAnKong(idx: idx) {
                actions.append(ConcealedHandAction(tileIndex: idx, kind: .anKong))
            } else if vm.canMingKong(idx: idx) {
                actions.append(ConcealedHandAction(tileIndex: idx, kind: .mingKong))
            } else if vm.canPong(idx: idx) {
                actions.append(ConcealedHandAction(tileIndex: idx, kind: .pong))
            }
        }

        return actions
    }

    private func concealedActionBar(actions: [ConcealedHandAction]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    Button {
                        performConcealedHandAction(action)
                    } label: {
                        Text("\(MahjongEngine.tileName34(action.tileIndex, language: vm.language)) \(AppText.concealedActionName(action.kind, language: vm.language))")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(height: handAccessoryHeight)
                            .background(Color(.systemBackground))
                            .appleClip(AppleCornerRadius.badge)
                            .appleStroke(Color.accentColor.opacity(0.9),
                                         radius: AppleCornerRadius.badge)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performConcealedHandAction(_ action: ConcealedHandAction) {
        switch action.kind {
        case .addKong:
            vm.addKong(idx: action.tileIndex)
        case .anKong:
            vm.anKong(idx: action.tileIndex)
        case .mingKong:
            vm.mingKong(idx: action.tileIndex)
        case .pong:
            vm.pong(idx: action.tileIndex)
        }
    }

    private func statusChip(_ title: String, isPrimary: Bool = false) -> some View {
        Text(title)
            .font(isPrimary ? .headline.weight(.semibold) : .footnote.weight(.medium))
            .foregroundColor(isPrimary ? .primary : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, isPrimary ? 10 : 8)
            .frame(height: isPrimary ? 34 : 28)
            .background(Color(.systemGray6))
            .appleClip(AppleCornerRadius.badge)
    }

    private func toolbarIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color(.systemGray6))
                .appleClip(AppleCornerRadius.control)
        }
        .buttonStyle(.plain)
    }

    private func tileButton(idx: Int) -> some View {
        let count = vm.counts34[idx]

        return Button {
            vm.addTile(idx: idx)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Text(MahjongEngine.tileName34(idx, language: vm.language))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .overlay(
                    AppleCornerShape.continuous(AppleCornerRadius.control)
                        .stroke(count > 0 ? Color.accentColor : Color(.systemGray4),
                                lineWidth: count > 0 ? 2 : 1)
                )
                .appleClip(AppleCornerRadius.control)
            }
        }
        .buttonStyle(.plain)
    }

}
