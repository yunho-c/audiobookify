#!/usr/bin/env python3
"""Convert Kokoro voices-v1.0.bin into the JSON shape expected by kokoro_flutter.

Usage:
  python3 tool/convert_kokoro_voices.py \
    /path/to/voices-v1.0.bin \
    assets/kokoro/voices.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np


def _format_row(row: np.ndarray) -> str:
    return "[" + ",".join(format(float(value), ".7g") for value in row) + "]"


def _normalize_voice(voice: np.ndarray) -> np.ndarray:
    if voice.ndim == 3 and voice.shape[1] == 1:
        return voice[:, 0, :]
    if voice.ndim == 2:
        return voice
    raise ValueError(f"Unsupported voice tensor shape: {voice.shape}")


def convert(input_path: Path, output_path: Path) -> None:
    archive = np.load(input_path, allow_pickle=False)
    voice_ids = sorted(archive.files)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        handle.write("{")
        for voice_index, voice_id in enumerate(voice_ids):
            if voice_index:
                handle.write(",")
            handle.write(json.dumps(voice_id, ensure_ascii=True))
            handle.write(":")
            voice = _normalize_voice(archive[voice_id])
            handle.write("[")
            for row_index, row in enumerate(voice):
                if row_index:
                    handle.write(",")
                handle.write(_format_row(row))
            handle.write("]")
        handle.write("}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    convert(args.input, args.output)


if __name__ == "__main__":
    main()
