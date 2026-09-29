#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
 EXTREME++GAMING — EAS & Capacity Margin Patch
 SM8250-AC (Snapdragon 870) | POCO F4 (munch)
═══════════════════════════════════════════════════════════════
 Adjusts the EAS (Energy Aware Scheduling) energy model
 capacity margins to reflect the new 2841 MHz ceiling on Core 7.
"""
import sys

def patch(path):
    text = open(path).read()

    # Core 7 (Prime) block typically has:
    # capacity-dmips-mhz = <1894>;
    # dynamic-power-coefficient = <598>;
    
    if '/* EXTREME++ EAS' in text:
        print("✅ EAS Capacity Margins already patched.")
        return True

    # Find CPU7 block
    cpu7_idx = text.find('CPU7: cpu@700')
    if cpu7_idx == -1:
        print("ERROR: CPU7 block not found.")
        return False

    # Replace dynamic-power-coefficient = <598> with <530>
    # Since 2.84GHz uses significantly less voltage than 3.187GHz,
    # the energy cost is lower. This tells the EAS scheduler to
    # utilize the Prime core more efficiently instead of avoiding it.
    
    old_power = 'dynamic-power-coefficient = <598>;'
    new_power = (
        '/* EXTREME++ EAS: Lower energy cost due to 2.84GHz cap */\n'
        '\t\t\tdynamic-power-coefficient = <530>;'
    )
    
    if old_power in text[cpu7_idx:cpu7_idx+1000]:
        text = text[:cpu7_idx] + text[cpu7_idx:].replace(old_power, new_power, 1)
        open(path, 'w').write(text)
        print("✅ CPU7 EAS dynamic-power-coefficient reduced: 598 → 530")
        return True
    else:
        print("⚠️ Could not find exact dynamic-power-coefficient for CPU7. Skipping.")
        return True # Soft fail

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(1)
    sys.exit(0 if patch(sys.argv[1]) else 1)
