# MahjongTing

iOS 麻将听牌与扫描辅助应用。
ps：为什么不上架呢，因为要交年费。

支持广东 / 四川规则，支持手动录入、听牌与胡牌计算、碰 / 杠管理、相机扫描入口，以及本地单牌数据集采集与导出。

## 当前内容

- 规则计算：广东、四川；支持七对；广东支持十三幺；四川支持定缺
- 手牌操作：图形化点牌、删牌、清空、碰、杠、暗杠、明杠
- 扫描入口：ARKit 相机扫描页面，预留识别器接口
- 数据集工具：单牌 patch 提取、本地保存、按类别导出、manifest 校验

## 项目结构

- `NativeMahjongView.swift`：主界面与交互
- `MahjongEngine.swift`：听牌 / 胡牌 / 副露计算
- `TileScanView.swift`：扫描页与采集页
- `TileScanManager.swift`：ARKit 帧采集
- `SingleTilePatchExtractor.swift`：单牌裁剪与透视矫正
- `MahjongDatasetStore.swift`：本地数据集保存
- `DeveloperDatasetExport.swift`：数据集导出
- `VisionCoreMLTileRecognizer.swift`：CoreML 识别接口

## 模型与识别

当前仓库不附带训练权重。（后续可能上传，模型还在训练）

扫描页已经接好识别接口，默认实现是 `StubTileRecognizer`。接入自己的 `.mlmodel` / `.mlmodelc` 后，可切换为 `VisionCoreMLTileRecognizer`。

当前单牌分类映射为 34 类，见 `CATEGORY_MAPPING.md`。

## 数据与引用

数据来源、第三方项目、模型权重说明、清洗 / 标注 / 重构记录见 `THIRD_PARTY_NOTICES.md`。

## 后续改进

- 接入稳定的 CoreML 单牌分类模型
- 增加多帧投票与排序校正
- 补充整排检测与复杂背景识别
- 补充测试样例与截图

## License

本仓库使用 `CC BY 4.0`，见根目录 `LICENSE`。
