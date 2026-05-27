#!/usr/bin/env python3
import argparse
import ast
import csv
import os
from pathlib import Path

import coremltools as ct
from PIL import Image, ImageDraw, ImageFont


DEFAULT_LABELS = {
    0: "1m", 1: "1p", 2: "1s", 3: "1z",
    4: "2m", 5: "2p", 6: "2s", 7: "2z",
    8: "3m", 9: "3p", 10: "3s", 11: "3z",
    12: "4m", 13: "4p", 14: "4s", 15: "4z",
    16: "5m", 17: "5p", 18: "5s", 19: "5z",
    20: "6m", 21: "6p", 22: "6s", 23: "6z",
    24: "7m", 25: "7p", 26: "7s", 27: "7z",
    28: "8m", 29: "8p", 30: "8s",
    31: "9m", 32: "9p", 33: "9s",
    34: "UNKNOWN", 35: "0m", 36: "0p", 37: "0s",
}


def parse_args():
    parser = argparse.ArgumentParser(description="Run TileModel on desktop images and draw detections.")
    parser.add_argument("--model", default="MahjongTing/TileModel.mlpackage")
    parser.add_argument("--images", required=True, help="Image file or directory.")
    parser.add_argument("--out", default="model_test_out")
    parser.add_argument("--conf", type=float, default=0.25)
    parser.add_argument("--iou", type=float, default=0.70)
    parser.add_argument("--limit", type=int, default=200, help="Max images to process.")
    return parser.parse_args()


def find_images(path: Path, limit: int):
    exts = {".jpg", ".jpeg", ".png", ".heic", ".bmp", ".webp"}
    if path.is_file():
        return [path]
    files = [p for p in sorted(path.rglob("*")) if p.suffix.lower() in exts]
    return files[:limit]


def load_labels(model):
    user_defined = model.get_spec().description.metadata.userDefined
    raw = user_defined.get("names")
    if not raw:
        return DEFAULT_LABELS
    try:
        parsed = ast.literal_eval(raw)
        return {int(k): str(v) for k, v in parsed.items()}
    except Exception:
        return DEFAULT_LABELS


def box_to_pixels(box, width, height):
    x, y, w, h = [float(v) for v in box]

    if max(abs(x), abs(y), abs(w), abs(h)) <= 1.5:
        cx = x * width
        cy = y * height
        bw = w * width
        bh = h * height
    else:
        scale_x = width / 896.0
        scale_y = height / 896.0
        cx = x * scale_x
        cy = y * scale_y
        bw = w * scale_x
        bh = h * scale_y

    left = max(0, cx - bw / 2)
    top = max(0, cy - bh / 2)
    right = min(width, cx + bw / 2)
    bottom = min(height, cy + bh / 2)
    return left, top, right, bottom


def draw_label(draw, xy, text):
    x1, y1, x2, y2 = xy
    try:
        font = ImageFont.truetype("Arial.ttf", 16)
    except Exception:
        font = ImageFont.load_default()
    bbox = draw.textbbox((x1, y1), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    y = max(0, y1 - text_h - 4)
    draw.rectangle([x1, y, x1 + text_w + 6, y + text_h + 4], fill="red")
    draw.text((x1 + 3, y + 2), text, fill="white", font=font)


def main():
    args = parse_args()
    os.environ.setdefault("TMPDIR", "/private/tmp")

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    model = ct.models.MLModel(args.model)
    labels = load_labels(model)
    images = find_images(Path(args.images), args.limit)

    csv_path = out_dir / "detections.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["image", "label", "class_id", "score", "left", "top", "right", "bottom"])

        for image_path in images:
            image = Image.open(image_path).convert("RGB")
            pred = model.predict({
                "image": image,
                "iouThreshold": args.iou,
                "confidenceThreshold": args.conf,
            })

            confidence = pred["confidence"]
            coordinates = pred["coordinates"]

            annotated = image.copy()
            draw = ImageDraw.Draw(annotated)
            width, height = annotated.size

            detections = 0
            for box_idx in range(coordinates.shape[0]):
                scores = confidence[box_idx]
                class_id = int(scores.argmax())
                score = float(scores[class_id])
                if score < args.conf:
                    continue

                label = labels.get(class_id, f"class_{class_id}")
                xy = box_to_pixels(coordinates[box_idx], width, height)
                draw.rectangle(xy, outline="red", width=3)
                draw_label(draw, xy, f"{label} {score:.2f}")
                writer.writerow([image_path.name, label, class_id, f"{score:.4f}", *[f"{v:.1f}" for v in xy]])
                detections += 1

            out_path = out_dir / f"{image_path.stem}_detected.jpg"
            annotated.save(out_path, quality=92)
            print(f"{image_path.name}: {detections} detections -> {out_path}")

    print(f"CSV written to {csv_path}")


if __name__ == "__main__":
    main()
