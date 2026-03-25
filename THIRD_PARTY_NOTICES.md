# Third-Party Notices

本文件用于记录当前项目已经使用过、参考过、或计划采用的外部仓库、数据与训练参考来源。

---

## 1. Camerash / mahjong-dataset

- Repository: `https://github.com/Camerash/mahjong-dataset`
- Role in this project:
  - 作为麻将牌图像数据来源之一的参考
  - 可用于单牌分类或基础视觉识别实验的数据准备
- Current recorded license status:
  - MIT
- What to keep locally:
  - 原始仓库链接
  - LICENSE 副本
  - README 中关于数据来源的描述
  - 你自己做过的数据清洗、筛选、重命名与标注记录

---

## 2. nikmomo / Mahjong-YOLO

- Repository: `https://github.com/nikmomo/Mahjong-YOLO`
- Role in this project:
  - 作为目标检测基线与训练流程参考
  - 作为 YOLO -> ONNX / CoreML 导出流程参考
  - 可用于后续复杂场景整图识别路线设计
- Current recorded license status:
  - MIT
- Usage note:
  - 如果复用其中的训练脚本、转换脚本、配置或推理流程，应保留明确引用说明
  - 如果后续直接发布由其流程派生出来的模型权重，应额外记录训练数据来源与类别映射关系

---

## 3. HSKPeter / mahjong-dataset-augmentation

- Repository: `https://github.com/HSKPeter/mahjong-dataset-augmentation`
- Role in this project:
  - 作为数据增强 / 合成数据生成思路参考
  - 可用于研究真实数据不足时的合成训练样本方案
- Current recorded status:
  - 仓库公开可见，但当前未在仓库首页明确确认到许可证信息
- Conservative usage recommendation:
  - 当前仅作为思路参考
  - 在未再次人工确认许可证前，不要默认复制其代码、素材、图像或导出结果

---

## 4. Self-collected on-device dataset

- Source:
  - 本项目 iOS 端扫描与 patch 导出流程直接生成
- Recommended records:
  - 采集设备
  - 采集日期
  - 采集场景（光照、桌面、背景、角度）
  - 数据清洗规则
  - 标注与重命名规则
  - 删除错误样本的记录

---

## 5. Weight / model release note

如果后续发布模型文件，建议单独附加以下信息：

- 模型名称
- 训练日期
- 训练代码来源
- 数据来源组合
- 类别映射表版本
- 导出链路（PyTorch / ONNX / CoreML）
- 与第三方仓库之间的关系（直接训练 / 改写训练 / 仅参考思路）

---

## 6. Repository maintainer checklist

在公开仓库前，建议至少完成以下检查：

- [ ] 每个第三方来源都能找到原始链接
- [ ] 每个第三方来源都保存对应 LICENSE 或页面说明
- [ ] README 已说明哪些内容来自外部参考
- [ ] 已区分“直接复用 / 改写 / 仅参考思路”
- [ ] 已记录自己的数据清洗与重构工作
- [ ] 准备公开的模型权重具有明确来源与说明

