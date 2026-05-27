# Data Sources and Third-Party Notes

## Repository License

This repository is released under `CC BY 4.0`. See `LICENSE` in the project root.

## Data Sources

### 1. Camerash / mahjong-dataset
- Purpose: reference for single-tile images and category organization
- Usage here: one of the public data sources and a reference for class layout
- License: MIT
- Link: https://github.com/Camerash/mahjong-dataset

### 2. HSKPeter / mahjong-dataset-augmentation
- Purpose: reference for synthetic detection data generation and augmentation workflow
- Usage here: used as a workflow reference, not directly merged into this repository as-is
- License status: the repository page shows the README and source credits, but no standalone root LICENSE file was confirmed during this rewrite; verify again before direct reuse
- Link: https://github.com/HSKPeter/mahjong-dataset-augmentation

## Third-Party Project References

### 1. nikmomo / Mahjong-YOLO
- Purpose: Mahjong tile detection baseline and training reference
- Usage here: external baseline for the detection branch, not copied as the core implementation of this repository
- License: MIT
- Link: https://github.com/nikmomo/Mahjong-YOLO

## Model Weight Notes

- The repository includes `TileModel.mlpackage`
- The iOS side loads the CoreML recognition model through `Recognizer.swift`
- Any future weight file added to the repository should state the training data source, label version, training date, export method, and license

## Cleaning / Annotation / Refactoring Record

### Labels and Classes
- The current single-tile classifier uses 34 classes
- The honor-tile order is fixed as: East, South, West, North, White, Green, Red
- See `CATEGORY_MAPPING_EN.md` for the mapping table

### Data Organization
- Development dataset storage and export code has been moved to root `TestCode.swift`
- That file is outside the app target runtime logic

### Image Processing
- The scan page uses AVCapture burst capture
- The CoreML recognizer handles row detection, ordering, and class mapping

### Code Structure
- Scan, recognition, and rule engine code are separated
- The recognizer is abstracted through `TileRecognizerProtocol`
- The current main entry is the native iOS UI in `MainView.swift`
