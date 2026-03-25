# MahjongTing

An iOS Mahjong hand-assistance app.

It supports Guangdong and Sichuan rules, manual tile input, ready-hand and winning-hand calculation, meld management, camera scan entry, and on-device single-tile dataset collection/export.

## Current Scope

- Rule engine: Guangdong, Sichuan, Seven Pairs, Thirteen Orphans for Guangdong, Dingque for Sichuan
- Hand operations: tile input, tile removal, clear, pong, kong, concealed kong, exposed kong
- Scan entry: ARKit-based scan page with a recognizer interface
- Dataset tools: single-tile patch extraction, local storage, class-based export, manifest check

## Project Structure

- `NativeMahjongView.swift`: main UI
- `MahjongEngine.swift`: hand evaluation and wait calculation
- `TileScanView.swift`: scan and collection page
- `TileScanManager.swift`: ARKit frame capture
- `SingleTilePatchExtractor.swift`: single-tile crop and perspective correction
- `MahjongDatasetStore.swift`: local dataset storage
- `DeveloperDatasetExport.swift`: dataset export
- `VisionCoreMLTileRecognizer.swift`: CoreML recognizer interface

## Model and Recognition

No pretrained weights are bundled in this repository.

The scan page already exposes the recognizer interface. The default implementation is `StubTileRecognizer`. After adding your own `.mlmodel` / `.mlmodelc`, it can be switched to `VisionCoreMLTileRecognizer`.

The current single-tile classifier uses a 34-class mapping. See `CATEGORY_MAPPING_EN.md`.

## Data and References

See `THIRD_PARTY_NOTICES_EN.md` for data sources, third-party references, weight notes, and the data cleaning / annotation / refactoring record.

## Next

- Integrate a stable CoreML single-tile classifier
- Add multi-frame voting and ordering correction
- Add full-row detection under complex backgrounds
- Add test cases and screenshots

## License

This repository is released under `CC BY 4.0`. See `LICENSE` in the project root.
