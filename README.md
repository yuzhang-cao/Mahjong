# MahjongTing

iOS 麻将听牌与扫描辅助应用。
ps：为什么不上架呢，因为要交年费。

支持广东 / 四川规则，支持手动录入、听牌与胡牌计算、碰 / 杠管理，以及相机扫描识别。

## 当前内容

- 规则计算：广东、四川；支持七对；广东支持十三幺；四川支持定缺
- 手牌操作：图形化点牌、删牌、清空、碰、杠、暗杠、明杠
- 扫描入口：AVCapture 相机扫描页面，接入 CoreML 整排识别
- 测试工具：开发期数据集导出代码已移到根目录 `TestCode.swift`

## 项目结构

- `App.swift`：应用入口与方向控制
- `MainView.swift`：主界面与交互
- `ViewModel.swift`：手牌状态与计算调度
- `Engine.swift`：听牌 / 胡牌 / 副露计算
- `ScanView.swift`、`Camera.swift`、`CameraPreview.swift`：扫描界面与相机采集
- `Recognizer.swift`：CoreML 识别
- `TestCode.swift`：开发 / 测试期工具，不参与 App 运行逻辑

## 模型与识别

当前仓库包含 `TileModel.mlpackage`，扫描页默认通过 `Recognizer.swift` 加载 `TileModel.mlmodelc`。

当前单牌分类映射为 34 类，见 `CATEGORY_MAPPING.md`。

## 数据与引用

数据来源、第三方项目、模型权重说明、清洗 / 标注 / 重构记录见 `THIRD_PARTY_NOTICES.md`。

## 后续改进

- 增加多帧投票与排序校正
- 继续优化复杂背景识别
- 补充测试样例与截图

## License

本仓库使用 `CC BY 4.0`，见根目录 `LICENSE`。
