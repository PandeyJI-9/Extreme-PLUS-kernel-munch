#!/usr/bin/env python3
"""
PROJECT EXTREME++ | Maintainer: PandeyJI-9
Device: POCO F4 (munch) | Target: HyperOS ONLY
Safe PD / PPS Charger Unlock & Thermal DTS Stepping (Zero-Bootloop Architecture)

1. PD / PPS Charger Speed Unlock (Safe Variable Edit):
   - pd_policy_manager_munch.c:
     * min_adapter_volt_required -> 8500 (8.5V for third-party PPS support)
     * min_adapter_curr_required -> 1500 (1.5A for third-party PPS support)
   - smb5-lib-munch.c:
     * When pd_active is true, raise initial limits to 3.0A (3000000 uA)
       for PD_VOTER on usb_icl_votable and PD_VERIFED_VOTER on fcc_votable

2. 100% Stock Xiaomi 67W Cryptographic Handshake:
   - pd_get_bms_digest_verified and BMS authentic verification left 100% stock
   - mi_thermald & natural hardware authentication flows completely untampered

3. Thermal & Battery Health (Device Tree Only):
   - C-code (step-chg-jeita-munch.c) left 100% STOCK
   - jeita-step-cfg-munch.dtsi updated with OEM 6-tuple syntax:
     * (-10°C - 0°C): 1.0A (Freezing battery protection)
     * (0.1°C - 15°C): 4.0A (Cold step safety)
     * (15.1°C - 38°C): 12.4A (Full 67W Turbo Peak)
     * (38.1°C - 42°C): 6.6A (~33W Thermal step-down)
     * (42.1°C - 45°C): 4.5A (~22W Controlled throttle)
     * (45.1°C - 58°C): 2.2A (Extreme safety step-down)
"""

import os
import re

def patch_pd_policy_manager():
    paths = [
        "drivers/power/supply/ti/pd_policy_manager_munch.c",
        "drivers/power/supply/ti/pd_policy_manager.c"
    ]
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, "r") as f:
            content = f.read()

        # Lower min adapter volt and current for third-party PPS chargers (8.5V, 1.5A)
        # Note: Cryptographic handshake (pd_get_bms_digest_verified) is strictly UNTOUCHED!
        content, c1 = re.subn(
            r"(\.min_adapter_volt_required\s*=\s*)\d+,",
            r"\g<1>8500,",
            content
        )
        content, c2 = re.subn(
            r"(\.min_adapter_curr_required\s*=\s*)\d+,",
            r"\g<1>1500,",
            content
        )
        if c1 > 0 or c2 > 0:
            print(f"✅ [PPS Fast Charge] Patched min adapter requirements (8.5V, 1.5A) in {path}")

        with open(path, "w") as f:
            f.write(content)

def patch_smb5_lib():
    paths = [
        "drivers/power/supply/qcom/smb5-lib-munch.c",
        "drivers/power/supply/qcom/smb5-lib.c"
    ]
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, "r") as f:
            content = f.read()

        # Safe Initial PD Current Limit (3.0A instead of 100mA clamp):
        # 1. On usb_icl_votable: vote(chg->usb_icl_votable, PD_VOTER, true, 3000000)
        old_icl = r"(vote\(chg->usb_icl_votable,\s*PD_VOTER,\s*true,\s*)USBIN_100MA(\);)"
        content, c_icl = re.subn(old_icl, r"\g<1>3000000\2", content)

        # 2. On fcc_votable when unverified: vote(chg->fcc_votable, PD_VERIFED_VOTER, true, 3000000)
        old_fcc = r"(rc\s*=\s*vote\(chg->fcc_votable,\s*PD_VERIFED_VOTER,\s*true,\s*)PD_UNVERIFED_CURRENT(\);)"
        content, c_fcc = re.subn(old_fcc, r"\g<1>3000000\2", content)

        if c_icl > 0 or c_fcc > 0:
            print(f"✅ [PD Fast Charge] Safe initial PD limit raised to 3.0A (3000000 uA) in {path}")

        with open(path, "w") as f:
            f.write(content)

def patch_jeita_dtsi():
    paths = [
        "arch/arm64/boot/dts/vendor/qcom/jeita-step-cfg-munch.dtsi",
        "arch/arm64/boot/dts/vendor/qcom/jeita-step-cfg.dtsi"
    ]
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, "r") as f:
            content = f.read()

        # OEM Qualcomm format: Strictly 6 tuples matching MAX_STEP_CHG_ENTRIES == 6
        new_ranges = """\tqcom,jeita-fcc-ranges = <(-100)  0   1000000
\t\t\t\t1    150 4000000
\t\t\t\t151  380 12400000
\t\t\t\t381  420 6600000
\t\t\t\t421  450 4500000
\t\t\t\t451  580 2200000>;"""

        pattern = r"qcom,jeita-fcc-ranges\s*=\s*<[^>]+>;"
        if re.search(pattern, content):
            content = re.sub(pattern, lambda m: new_ranges.strip(), content)
            with open(path, "w") as f:
                f.write(content)
            print(f"✅ [Thermal Guard] Updated jeita-fcc-ranges 6-tuple curve (<38°C: 67W, 38-42°C: 33W, 42-45°C: 22W) in {path}")

if __name__ == "__main__":
    print("🚀 Running PROJECT EXTREME++ Safe Power & Charging Patcher...")
    patch_pd_policy_manager()
    patch_smb5_lib()
    patch_jeita_dtsi()
    print("✨ Safe charging patches complete.")
