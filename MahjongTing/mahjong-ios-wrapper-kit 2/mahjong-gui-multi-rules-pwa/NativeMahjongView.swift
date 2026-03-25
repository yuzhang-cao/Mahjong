import SwiftUI
import UIKit
import ARKit

private enum SessionOnce {
    static var didShowBrandBanner: Bool = false
}

private struct BrandBanner: View {
    var body: some View {
        Text("麻将听牌助手")
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 6)
            .padding(.top, 10)
    }
}

private struct SettingsSheet: View {
    @ObservedObject var vm: MahjongViewModel
    @Binding var isPresented: Bool

    private var supportsSceneDepth: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) ||
        ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
    }

    private var modeResolved: MahjongRuleMode { vm.resolveMode() }

    private var canToggleAuto: Bool {
        let k = vm.activeKongCountEffective()
        let cnt = vm.handCountEffective()
        return cnt >= 13 + k
    }

    var body: some View {
        let form = Form {
            Section("规则") {
                Picker("规则", selection: $vm.ruleMode) {
                    ForEach(MahjongRuleMode.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .onChange(of: vm.ruleMode) { _ in
                    vm.normalizeForRuleMode()
                    if vm.autoComputeEnabled {
                        vm.compute()
                    }
                }
            }

            if modeResolved == .sichuan {
                Section("四川定缺") {
                    Picker("定缺", selection: $vm.dingque) {
                        Text("不设置").tag(nil as Suit?)
                        Text("万").tag(Suit.m as Suit?)
                        Text("筒").tag(Suit.p as Suit?)
                        Text("条").tag(Suit.s as Suit?)
                    }
                }
            }

            Section("胡牌选项") {
                Toggle("七对", isOn: $vm.enableQiDui)

                Toggle("十三幺（仅广东）", isOn: $vm.enable13yao)
                    .disabled(modeResolved != .guangdong)
                    .opacity(modeResolved != .guangdong ? 0.35 : 1.0)
            }

            Section("反馈") {
                Toggle("震动反馈", isOn: $vm.hapticsEnabled)
            }

            Section("扫描") {
                Toggle("深度增强（LiDAR/深度）", isOn: $vm.scanDepthEnabled)
                    .disabled(!supportsSceneDepth)
                    .opacity(!supportsSceneDepth ? 0.35 : 1.0)

                Toggle("保存识别样本（本地）", isOn: $vm.scanCollectSamplesEnabled)

                if !supportsSceneDepth {
                    Text("本设备不支持深度语义，将自动使用纯相机识别。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section("计算") {
                Button(vm.autoComputeEnabled ? "停止计算" : "开始计算") {
                    vm.toggleAutoCompute()
                }
                .disabled(!canToggleAuto)
                .opacity(!canToggleAuto ? 0.35 : 1.0)
            }

            Section("数据") {
                Button(role: .destructive) {
                    vm.clearAll()
                    isPresented = false
                } label: {
                    Text("清空手牌")
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
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeMahjongView: View {
    @State private var showScan: Bool = false
    @State private var showSettings: Bool = false
    @State private var showBrand: Bool = !SessionOnce.didShowBrandBanner
    @StateObject private var vm: MahjongViewModel = MahjongViewModel()

    private let columns9: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let columns7: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    // === 手牌区布局参数：为“极端情况”预留，避免页面跳动 ===
    private let reservedRows: Int = 6
    private let handChipMinWidth: CGFloat = 150
    private let handChipRowHeight: CGFloat = 44
    private let handChipSpacing: CGFloat = 10

    // 手牌右侧“功能槽位”固定宽度
    private let handAccessoryWidth: CGFloat = 56
    private let handAccessoryHeight: CGFloat = 28

    private var handColumns: [GridItem] {
        [GridItem(.adaptive(minimum: handChipMinWidth), spacing: handChipSpacing)]
    }

    private var handAreaMinHeight: CGFloat {
        let rows = CGFloat(reservedRows)
        return rows * handChipRowHeight + (rows - 1) * handChipSpacing + 8
    }

    private var hasTilesInHand: Bool {
        vm.counts34.contains { $0 > 0 }
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

                    // 关键状态条
                    HStack(spacing: 10) {
                        Text(mode == .sichuan ? "四川" : "广东")
                            .font(.headline.weight(.semibold))

                        Text("张数 \(cnt)")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Text("杠 \(k)")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(vm.autoComputeEnabled ? "自动" : "暂停")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }

                    // ✅ 关键：把“副露 + 手牌”合并成一个大框
                    handPanel()

                    Divider()

                    // 点牌区
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("点牌")
                                .font(.footnote.weight(.semibold))
                            Spacer()
                        }

                        Picker("类别", selection: $vm.selectedTab) {
                            Text("萬").tag("m")
                            Text("茼").tag("p")
                            Text("條").tag("s")
                            Text("字").tag("z")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: vm.selectedTab) { _ in
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

                    // 结果区
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("结果")
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Button("复制") {
                                UIPasteboard.general.string = vm.outputText
                            }
                            .font(.footnote)
                        }

                        Text(vm.outputText)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .onChange(of: vm.clearAllNonce) { _ in
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
                                    Button { showScan = true } label: {
                                        Image(systemName: "camera.viewfinder")
                                    }
                                    Button { showSettings = true } label: {
                                        Image(systemName: "gearshape")
                                    }
                                }
                            }
                        }
                        .sheet(isPresented: $showScan) {
                            TileScanSheet(vm: vm)
                        }
                }
            } else {
                NavigationView {
                    content
                        .navigationBarTitle("", displayMode: .inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                HStack(spacing: 14) {
                                    Button { showScan = true } label: {
                                        Image(systemName: "camera.viewfinder")
                                    }
                                    Button { showSettings = true } label: {
                                        Image(systemName: "gearshape")
                                    }
                                }
                            }
                        }
                        .sheet(isPresented: $showScan) {
                            TileScanSheet(vm: vm)
                        }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(vm: vm, isPresented: $showSettings)
        }
        .overlay(alignment: .top) {
            if showBrand {
                BrandBanner()
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

    // ✅ 新增：统一的“手牌大框面板”（副露 + 手牌在同一个外框里）
    private func handPanel() -> some View {
        VStack(alignment: .leading, spacing: 10) {

            // 标题行
            HStack(spacing: 10) {
                Text("手牌")
                    .font(.headline.weight(.semibold))
                Spacer()
                if !vm.melds.isEmpty {
                    Text("副露 \(vm.melds.count)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemBackground))
                        .clipShape(Capsule())
                }
            }

            // 副露区：永远占位，不再“消失”
            VStack(alignment: .leading, spacing: 8) {
                Text("副露")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)

                if vm.melds.isEmpty {
                    Text("暂无副露（碰/杠后会显示在这里）")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: handChipRowHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 1))
                        .clipShape(Capsule())
                } else {
                    LazyVGrid(columns: handColumns, alignment: .leading, spacing: handChipSpacing) {
                        ForEach(vm.melds) { m in
                            Button {
                                vm.removeMeld(id: m.id)
                            } label: {
                                let name = MahjongEngine.tileName34(m.tileIndex)
                                HStack(spacing: 10) {
                                    Text("\(m.displayName) \(name)")
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
                                .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()

            // 手牌区（你原逻辑保留）
            VStack(alignment: .leading, spacing: 8) {
                Text("暗手")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: handColumns, alignment: .leading, spacing: handChipSpacing) {
                    if hasTilesInHand {
                        ForEach(0..<34, id: \.self) { i in
                            if vm.counts34[i] > 0 {
                                handChip(idx: i)
                            }
                        }
                    } else {
                        Text("点下方牌面录入")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: handChipRowHeight)
                            .padding(.horizontal, 10)
                            .background(Color(.systemBackground))
                            .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: handAreaMinHeight, alignment: .topLeading)

                if !vm.statusText.isEmpty {
                    Text(vm.statusText)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private func tileButton(idx: Int) -> some View {
        let count = vm.counts34[idx]

        return Button {
            vm.addTile(idx: idx)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Text(MahjongEngine.tileName34(idx))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(count > 0 ? Color.accentColor : Color(.systemGray4),
                                lineWidth: count > 0 ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .buttonStyle(.plain)
    }

    private func handChip(idx: Int) -> some View {
        let count = vm.counts34[idx]
        let name = MahjongEngine.tileName34(idx)

        let canAdd = vm.canAddKong(idx: idx)
        let canAn = vm.canAnKong(idx: idx)
        let canMing = vm.canMingKong(idx: idx)
        let canPong = vm.canPong(idx: idx)

        return ZStack(alignment: .trailing) {

            // 整条大胶囊：点击默认执行“减一张”
            Button {
                vm.removeTile(idx: idx)
            } label: {
                HStack(spacing: 10) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 8)

                    Text("×\(count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 12)
                // 关键：给右侧动作预留空间，让动作“嵌在同一个胶囊里”
                .padding(.trailing, handAccessoryWidth + 12)
                .frame(height: handChipRowHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // 右侧动作：叠在同一个胶囊里（不是另起一个框）
            Group {
                if canAdd {
                    Button { vm.addKong(idx: idx) } label: { actionPill("加杠") }
                } else if canAn {
                    Button { vm.anKong(idx: idx) } label: { actionPill("暗杠") }
                } else if canMing {
                    Button { vm.mingKong(idx: idx) } label: { actionPill("杠") }
                } else if canPong {
                    Button { vm.pong(idx: idx) } label: { actionPill("碰") }
                } else {
                    EmptyView()
                }
            }
            .padding(.trailing, 8)
        }
    }

    private func actionPill(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .frame(width: handAccessoryWidth, height: handAccessoryHeight, alignment: .center)
            // 这里故意不做“独立大背景”，只做边框胶囊，让它看起来像嵌在大胶囊内部
            .background(Color(.systemBackground))
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.9), lineWidth: 1))
            .clipShape(Capsule())
    }
}
