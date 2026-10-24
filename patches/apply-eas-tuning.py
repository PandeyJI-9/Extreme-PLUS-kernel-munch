#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
 PROJECT EXTREME++ | Maintainer: PandeyJI-9
 SM8250-AC (Snapdragon 870) | POCO F4 (munch) | HyperOS ONLY
 EAS & Capacity Margin Optimization Suite
═══════════════════════════════════════════════════════════════
"""
import sys
import os

def patch(path, target_freq=3187200):
    if not os.path.exists(path):
        print(f"⚠️ {path} not found, skipping EAS tuning.")
        return True

    text = open(path).read()

    # Find CPU7 block
    cpu7_idx = text.find('CPU7: cpu@700')
    if cpu7_idx == -1:
        print("ℹ️ CPU7 block not found in " + path)
        return True

    # In BMW Edition (3.19 GHz Peak), stock 598 is Qualcomm's calibrated hardware measurement.
    # Lowering to 510 is only appropriate if hardware is permanently clamped to <= 2.84 GHz.
    # When 3.19 GHz is unlocked, 598 ensures EAS accurately computes energy cost and prevents
    # over-saturating the Prime core.
    if target_freq >= 3187200:
        if '/* EXTREME++ EAS' in text:
            # Revert back to calibrated 598
            text = text.replace('/* EXTREME++ EAS: Lower energy cost due to 2.84GHz clamp */\n\t\t\tdynamic-power-coefficient = <510>;', 'dynamic-power-coefficient = <598>;')
            open(path, 'w').write(text)
            print("✅ Preserved Qualcomm factory calibrated dynamic-power-coefficient (598) for 3.19 GHz Peak.")
        else:
            print("✅ EAS model validated: Factory 598 coefficient preserved for 3.19 GHz Peak.")
        return True

    # For clamped targets <= 2.84 GHz:
    old_power = 'dynamic-power-coefficient = <598>;'
    new_power = (
        '/* EXTREME++ EAS: Lower energy cost due to 2.84GHz clamp */\n'
        '\t\t\tdynamic-power-coefficient = <510>;'
    )
    if old_power in text[cpu7_idx:cpu7_idx+1000]:
        text = text[:cpu7_idx] + text[cpu7_idx:].replace(old_power, new_power, 1)
        open(path, 'w').write(text)
        print("✅ CPU7 EAS dynamic-power-coefficient reduced: 598 → 510 for clamped profile.")
    return True

if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else "arch/arm64/boot/dts/vendor/qcom/kona.dtsi"
    target = int(sys.argv[2]) if len(sys.argv) > 2 else 3187200
    patch(path, target)
