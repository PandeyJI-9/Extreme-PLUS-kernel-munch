#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 / Redmi K40S (munch) | FocalTech FT3658U touch panel
#
# Double-tap-to-wake on munch is implemented by the touch IC driver:
#   gesture_mode -> fts_gesture_suspend() writes FTS_REG_GESTURE_EN=1 and
#   enable_irq_wake(), so a double tap in sleep reports KEY_WAKEUP.
#
# gesture_mode is initialised from FTS_GESTURE_EN in focaltech_config.h, which
# is 0 in the AstideLabs base.  That makes double tap work only when the
# ROM/HAL (MIUI/HyperOS touchfeature daemon via /dev/xiaomi-touch) turns it on,
# so AOSP ROMs and stock ROMs with a missing/renamed HAL report
# "double tap to wake not working".
#
# Flipping the default to 1 makes the panel enter gesture mode on suspend out
# of the box.  The ROM can still switch it off at runtime through the usual
# Touch_Doubletap_Mode path; this only changes the power-on default.
# ==============================================================================
import os
import re
import sys

MARK = "EXTREME++ DT2W"
CONFIG_NAME = "focaltech_config.h"
DEFINE_RE = re.compile(r"^#define\s+FTS_GESTURE_EN\s+(\S+)(.*)$", re.MULTILINE)


def find_config(kernel_src: str) -> str | None:
    direct = [
        os.path.join(kernel_src, "drivers/input/touchscreen/focaltech_3658u", CONFIG_NAME),
        os.path.join(kernel_src, "drivers/input/touchscreen/focaltech_touch", CONFIG_NAME),
    ]
    for path in direct:
        if os.path.exists(path):
            return path

    touch_root = os.path.join(kernel_src, "drivers/input/touchscreen")
    for root, _dirs, files in os.walk(touch_root):
        if CONFIG_NAME in files and "focaltech" in root:
            return os.path.join(root, CONFIG_NAME)
    return None


def main() -> int:
    kernel_src = sys.argv[1] if len(sys.argv) > 1 else "."
    path = find_config(kernel_src)
    if not path:
        print(f"❌ [DT2W] {CONFIG_NAME} not found under {kernel_src}")
        return 1

    with open(path) as f:
        text = f.read()

    if MARK in text:
        print(f"ℹ️ [DT2W] {path} already enables double tap by default")
        return 0

    match = DEFINE_RE.search(text)
    if not match:
        print(f"❌ [DT2W] FTS_GESTURE_EN define not found in {path}")
        return 1

    if match.group(1) == "1":
        print(f"ℹ️ [DT2W] {path} already has FTS_GESTURE_EN 1")
        return 0

    replacement = f"#define FTS_GESTURE_EN                          1 /* {MARK}: double tap wakes the device by default */"
    text = DEFINE_RE.sub(lambda m: replacement, text, count=1)

    with open(path, "w") as f:
        f.write(text)

    print(f"✅ [DT2W] FTS_GESTURE_EN=1 (double tap to wake on by default) in {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
