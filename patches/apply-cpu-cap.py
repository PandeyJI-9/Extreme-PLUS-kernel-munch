#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
 EXTREME++GAMING — CPU Prime Core Cap Patch
 SM8250-AC (Snapdragon 870) | POCO F4 (munch)
═══════════════════════════════════════════════════════════════

 The SM8250-AC uses EPSS (Embedded Power State System) for
 CPU frequency scaling. The frequency LUT is programmed by
 the bootloader into hardware — it is NOT in the device tree.

 To cap the Prime Core max frequency, we add the
 qcom,freq-domain-max-freq property to the cpufreq_hw node.

 CPU Topology (SM8250-AC):
   CPU0-3  Kryo 585 Silver (LITTLE)  freq-domain0  → stock
   CPU4-6  Kryo 585 Gold             freq-domain1  → stock
   CPU7    Kryo 585 Gold+ (PRIME)    freq-domain2  → CAP 3000MHz

 Prime Core stock max: 3187 MHz (3.187 GHz)
 Prime Core patched:   3000 MHz (3.0 GHz)

 Silver and Gold clusters are left completely untouched.
═══════════════════════════════════════════════════════════════
"""
import sys


def patch(path):
    text = open(path).read()

    if 'qcom,freq-domain-max-freq' in text:
        print("✅ CPU Prime Core cap already applied — skipping")
        return True

    # Look for known markers in the cpufreq_hw node
    markers = [
        '\t\t\t#freq-domain-cells = <2>;',
        '\t\t\tqcom,skip-enable-check;',
    ]

    for marker in markers:
        if marker in text:
            insert = (
                '\t\t\t/* EXTREME++GAMING: Cap Prime Core (CPU7) to 3.0 GHz     */\n'
                '\t\t\t/* Domain 2 = Kryo 585 Gold Plus — reduces peak heat      */\n'
                '\t\t\t/* Stock: 3187 MHz → Patched: 3000 MHz                    */\n'
                '\t\t\tqcom,freq-domain-max-freq = <0 0 3000000>;\n\n'
            )
            text = text.replace(marker, insert + marker, 1)
            open(path, 'w').write(text)
            print("✅ CPU Prime Core (CPU7) capped: 3187 → 3000 MHz")
            return True

    print("ERROR: No suitable marker found in cpufreq_hw node", file=sys.stderr)
    return False


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: apply-cpu-cap.py <path-to-kona.dtsi>")
        sys.exit(1)
    sys.exit(0 if patch(sys.argv[1]) else 1)
