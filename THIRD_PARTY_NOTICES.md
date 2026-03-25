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

- 当前仓库不附带训练权重
- iOS 端已经预留 `VisionCoreMLTileRecognizer` 接口，接入权重后即可切换到 CoreML 识别流程
- 后续放入仓库的权重文件，需要单独写清楚训练数据来源、标签版本、训练日期、导出方式和许可证

## 清洗 / 标注 / 重构记录

### 标签与类别
- 当前单牌分类统一为 34 类
- 字牌顺序统一为：东、南、西、北、白、发、中
- 类别映射见 `CATEGORY_MAPPING.md`

### 数据整理
- 本地采集目录统一为 `Documents/MahjongDataset/Training/0..33`
- 导出时按类别目录原样复制，并生成 `EXPORT_MANIFEST.txt`
- 采集图像统一保存为 JPEG

### 图像处理
- 单牌 patch 通过矩形检测 + 透视矫正生成
- 扫描页支持 burst 抓帧，为后续多帧投票预留接口

### 代码结构
- 扫描、分类、规则计算、数据集保存、导出分开实现
- 识别器通过 `TileRecognizerProtocol` 抽象，便于替换模型实现
- 当前主入口为原生 iOS 界面 `NativeMahjongView.swift`
