# 数据来源与第三方说明

## 仓库 License

本仓库使用 `CC BY 4.0`，见根目录 `LICENSE`。

## 数据来源

### 1. Camerash / mahjong-dataset
- 用途：单牌图像与类别整理参考
- 使用方式：作为公开数据来源之一和类别组织参考
- 许可证：MIT
- 链接：https://github.com/Camerash/mahjong-dataset

### 2. HSKPeter / mahjong-dataset-augmentation
- 用途：检测数据合成与增强思路参考
- 使用方式：目前作为生成思路与流程参考，不直接并入本仓库数据
- 许可证状态：仓库页面可查看 README 和来源致谢，但仓库根目录未确认到单独 LICENSE 文件；正式复用前需要再次核对
- 链接：https://github.com/HSKPeter/mahjong-dataset-augmentation

## 第三方项目引用

### 1. nikmomo / Mahjong-YOLO
- 用途：麻将牌目标检测基线与训练参考
- 使用方式：作为检测方向的外部基线，不直接把对方代码写成本仓库核心实现
- 许可证：MIT
- 链接：https://github.com/nikmomo/Mahjong-YOLO

## 模型权重来源说明

- 当前仓库包含 `TileModel.mlpackage`
- iOS 端通过 `Recognizer.swift` 加载 CoreML 识别模型
- 后续放入仓库的权重文件，需要单独写清楚训练数据来源、标签版本、训练日期、导出方式和许可证

## 清洗 / 标注 / 重构记录

### 标签与类别
- 当前单牌分类统一为 34 类
- 字牌顺序统一为：东、南、西、北、白、发、中
- 类别映射见 `CATEGORY_MAPPING.md`

### 数据整理
- 开发期数据集保存与导出代码已移到根目录 `TestCode.swift`
- 该文件不参与 App target 的运行逻辑

### 图像处理
- 扫描页使用 AVCapture burst 抓帧
- CoreML 识别器负责整排检测、排序和类别映射

### 代码结构
- 扫描、识别、规则计算分开实现
- 识别器通过 `TileRecognizerProtocol` 抽象，便于替换模型实现
- 当前主入口为原生 iOS 界面 `MainView.swift`
