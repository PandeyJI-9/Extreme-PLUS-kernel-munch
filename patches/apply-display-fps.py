#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Target: HyperOS ONLY
# Display Driver: Neutralize Smart-FPS Throttling (E404 Commit c42d15e5)
# Prevents Joyose and Xiaomi PowerHAL from forcing 90Hz / 60Hz mode switches in 120Hz games
# ==============================================================================
import os
import sys
import re

def patch_display(kernel_root="."):
    target_files = [
        "techpack/display/msm/dsi/dsi_panel_mi.c",
        "drivers/gpu/drm/msm/dsi-staging/dsi_panel_mi.c"
    ]
    patched_any = False

    for rel_path in target_files:
        full_path = os.path.join(kernel_root, rel_path)
        if not os.path.exists(full_path):
            continue

        with open(full_path, "r") as f:
            content = f.read()

        if "/* EXTREME++: Disable smart_fps to protect 120Hz */" in content:
            print(f"ℹ️ [Display FPS] {rel_path} already patched.")
            patched_any = True
            continue

        # Look for mi_cfg->smart_fps_support = ...
        pattern = r"(mi_cfg->smart_fps_support\s*=\s*)[^;]+;"
        if re.search(pattern, content):
            replacement = r"/* EXTREME++: Disable smart_fps to protect 120Hz */\n\tmi_cfg->smart_fps_support = 0;"
            new_content = re.sub(pattern, replacement, content, count=1)
            with open(full_path, "w") as f:
                f.write(new_content)
            print(f"✅ [Display FPS] Disabled smart_fps_support in {rel_path} to lock genuine 120Hz!")
            patched_any = True

    if not patched_any:
        print("ℹ️ [Display FPS] Display driver file not found or already clean; skipping.")
    return True

if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    patch_display(root)
    sys.exit(0)
