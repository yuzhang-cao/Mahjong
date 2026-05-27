# MahjongTing

An iOS Mahjong hand-assistance app.

It supports Guangdong and Sichuan rules, manual tile input, ready-hand and winning-hand calculation, meld management, and camera recognition.

## Current Scope

- Rule engine: Guangdong, Sichuan, Seven Pairs, Thirteen Orphans for Guangdong, Dingque for Sichuan
- Hand operations: tile input, tile removal, clear, pong, kong, concealed kong, exposed kong
- Scan entry: AVCapture scan page with CoreML row recognition
- Test tools: development dataset export code has been moved to root `TestCode.swift`

## Project Structure

- `App.swift`: app entry and orientation control
- `MainView.swift`: main UI
- `ViewModel.swift`: hand state and calculation flow
- `Engine.swift`: hand evaluation and wait calculation
- `ScanView.swift`, `Camera.swift`, `CameraPreview.swift`: scan UI and camera capture
- `Recognizer.swift`: CoreML recognition
- `TestCode.swift`: development / test utilities, outside app runtime logic

## Model and Recognition

The repository includes `TileModel.mlpackage`. The scan page loads `TileModel.mlmodelc` through `Recognizer.swift`.

The current single-tile classifier uses a 34-class mapping. See `CATEGORY_MAPPING_EN.md`.

## Data and References

See `THIRD_PARTY_NOTICES_EN.md` for data sources, third-party references, weight notes, and the data cleaning / annotation / refactoring record.

## Next

- Add multi-frame voting and ordering correction
- Improve recognition under complex backgrounds
- Add test cases and screenshots

## License

This repository is released under `CC BY 4.0`. See `LICENSE` in the project root.
