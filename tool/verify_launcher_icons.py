#!/usr/bin/env python3
"""Validate source launcher PNG dimensions, alpha modes and Android adaptive XML."""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets/branding"
SIZES = {
    "savour_icon.png": (1024, 2),
    "savour_icon_background.png": (432, 2),
    "savour_icon_foreground.png": (432, 6),
    "savour_icon_monochrome.png": (432, 6),
}
for name, (size, kind) in SIZES.items():
    raw = (ASSETS / name).read_bytes()
    assert raw.startswith(b"\x89PNG\r\n\x1a\n"), f"{name}: invalid PNG"
    width, height, depth, colour = struct.unpack(">IIBB", raw[16:26])
    assert (width, height, depth, colour) == (size, size, 8, kind), (
        f"{name}: wrong dimensions or colour type"
    )
    print(f"OK {name}: {size}x{size}, PNG colour type {kind}")
xml = ROOT / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
if xml.exists():
    source = xml.read_text()
    for element in ("<adaptive-icon", "<background", "<foreground", "<monochrome"):
        assert element in source, f"Android launcher XML missing {element}"
    print("OK adaptive icon XML: background, foreground and themed monochrome")
print("Savour launcher icons verified.")
