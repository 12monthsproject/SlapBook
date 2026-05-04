#!/usr/bin/env python3
from pathlib import Path

print(f"__file__: {__file__}")
print(f"Path(__file__): {Path(__file__)}")
print(f"Path(__file__).parent: {Path(__file__).parent}")
print(f"Path(__file__).parent.parent: {Path(__file__).parent.parent}")
print(f"Path(__file__).resolve(): {Path(__file__).resolve()}")
print(f"Path(__file__).resolve().parent.parent: {Path(__file__).resolve().parent.parent}")

APP_DIR = Path(__file__).parent.parent
SOUNDS_DIR = APP_DIR / "Resources"
print(f"\nAPP_DIR: {APP_DIR}")
print(f"SOUNDS_DIR: {SOUNDS_DIR}")
print(f"SOUNDS_DIR exists: {SOUNDS_DIR.exists()}")
