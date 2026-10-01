#!/usr/bin/env python3
import sys

def patch(path):
    try:
        with open(path, 'r') as f:
            text = f.read()
    except FileNotFoundError:
        print(f"⚠️ ERROR: File not found -> {path}")
        return True # Return True to not break the build loop

    if 'qcom,freq-domain-max-freq' in text:
        import re
        text = re.sub(r"qcom,freq-domain-max-freq\s*=\s*<[^>]+>;", "qcom,freq-domain-max-freq = <2841600>;", text)
        with open(path, 'w') as f:
            f.write(text)
        print("✅ CPU Prime Core cap updated to 2841600")
        return True

    # Added multiple fallback markers in case the dev's kernel tree is slightly different
    markers = [
        '\t\t\t#freq-domain-cells = <2>;',
        '\t\t\tqcom,skip-enable-check;',
        '\t\t\tqcom,cpufreq-hw-freq-domain;',
    ]

    for marker in markers:
        if marker in text:
            insert = (
                '\n\t\t\t/* EXTREME++GAMING: Cap Prime Core (CPU7) to 2.84 GHz     */\n'
                '\t\t\t/* Domain 2 = Kryo 585 Gold Plus — reduces peak heat      */\n'
                '\t\t\t/* Stock: 3187 MHz → Patched: 2841 MHz                    */\n'
                '\t\t\tqcom,freq-domain-max-freq = <2841600>;\n'
            )
            text = text.replace(marker, marker + insert, 1)
            with open(path, 'w') as f:
                f.write(text)
            print(f"✅ CPU Prime Core (CPU7) capped: 3187 → 2841 MHz (Using marker: {marker.strip()})")
            return True

    print("⚠️ WARNING: No suitable marker found in cpufreq_hw node. CPU Cap NOT applied.")
    return True # We return True so the build doesn't crash completely

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) >= 2 else "arch/arm64/boot/dts/vendor/qcom/kona.dtsi"
    sys.exit(0 if patch(target) else 1)
