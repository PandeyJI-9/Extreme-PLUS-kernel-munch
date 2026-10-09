#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch / SM8250-AC Kona) | Target: HyperOS ONLY
# Prime Core (CPU 7) Hardware Frequency Clamping Architecture
# ==============================================================================
# Supported Target Frequencies (Validated Qualcomm Kona EPSS LUT steps):
# 1. 2419200 kHz (~2.42 GHz) -> Battery Variant (Matched to Gold Core Peak)
# 2. 2841600 kHz (2.84 GHz)  -> Bal-Gaming Variant (Balanced Kryo 585 Prime)
# 3. 3187200 kHz (3.19 GHz)  -> Gaming Variant (100% Stock Factory Max Boost)
# ==============================================================================
import sys
import os
import shutil

def parse_target_freq(arg):
    s = str(arg).strip().lower()
    if s in ("battery", "bat", "2.5", "2.5ghz", "2.4", "2.4ghz", "2419200"):
        return 2419200
    elif s in ("bal-gaming", "bal_gaming", "bal", "balanced", "2.8", "2.8ghz", "2841600"):
        return 2841600
    elif s in ("gaming", "game", "perf", "performance", "3.2", "3.2ghz", "3.19", "3.19ghz", "3187200", "stock"):
        return 3187200
    try:
        val = int(s)
        if val >= 1000000:
            return val
    except ValueError:
        pass
    return None

def patch_driver(path="drivers/cpufreq/qcom-cpufreq-hw.c", cap_freq=2841600):
    if not os.path.exists(path):
        print(f"⚠️ [CPU Cap] Driver file not found at: {path}")
        return False

    orig_path = path + ".orig"
    # Ensure a pristine backup of the stock driver exists
    if not os.path.exists(orig_path):
        shutil.copyfile(path, orig_path)
        print(f"📦 [CPU Cap] Saved pristine backup: {orig_path}")

    # Always restore from pristine stock first to prevent cross-variant contamination
    with open(orig_path, "r") as f:
        stock_content = f.read()

    # Case 1: Gaming Variant (3.19 GHz / 3187200 kHz)
    # The Gaming variant runs 100% stock hardware driver! No clamp, no table truncation.
    # Qualcomm hardware naturally reads all steps up to 3.19 GHz with OEM factory voltages.
    if cap_freq >= 3187200:
        with open(path, "w") as f:
            f.write(stock_content)
        print("✅ [CPU Cap] Gaming Variant: Restored 100% stock drivers/cpufreq/qcom-cpufreq-hw.c (Peak: 3.19 GHz / 3187200 kHz)")
        return True

    # Case 2: Clamped Variants (Bal-Gaming: 2841600 kHz, Battery: 2419200 kHz)
    target = """\t\tfor_each_cpu(cpu, &c->related_cpus) {
\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\tif (!cpu_dev)
\t\t\t\tcontinue;
\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000,
\t\t\t\t\t\t\tvolt);
\t\t}"""

    # Fix off-by-one truncation bug:
    # We populate slot i with cap_freq, register OPP, increment i++, and break.
    # Outside the loop, slot i (which is now i+1) receives CPUFREQ_TABLE_END.
    # This guarantees slot i-1 (cap_freq = 2841600) is preserved as the maximum frequency!
    replacement = f"""\t\t/* EXTREME+: Prime Core Hardware Frequency Clamp */
\t\tif (cpumask_test_cpu(7, &c->related_cpus) && c->table[i].frequency >= {cap_freq}) {{
\t\t\tc->table[i].frequency = {cap_freq};
\t\t\tfor_each_cpu(cpu, &c->related_cpus) {{
\t\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\t\tif (!cpu_dev)
\t\t\t\t\tcontinue;
\t\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000, volt);
\t\t\t}}
\t\t\ti++;
\t\t\tbreak;
\t\t}}

\t\tfor_each_cpu(cpu, &c->related_cpus) {{
\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\tif (!cpu_dev)
\t\t\t\tcontinue;
\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000,
\t\t\t\t\t\t\tvolt);
\t\t}}"""

    if target in stock_content:
        patched = stock_content.replace(target, replacement, 1)
        with open(path, "w") as f:
            f.write(patched)
        print(f"✅ [CPU Cap] Successfully clamped Prime Core to exactly {cap_freq} kHz in drivers/cpufreq/qcom-cpufreq-hw.c")
        return True
    else:
        print("⚠️ [CPU Cap] Target pattern not found in stock qcom-cpufreq-hw.c")
        return False

def patch_dts(path="arch/arm64/boot/dts/vendor/qcom/kona.dtsi", cap_freq=2841600):
    if not os.path.exists(path):
        return True

    orig_path = path + ".orig"
    if not os.path.exists(orig_path):
        shutil.copyfile(path, orig_path)

    with open(orig_path, "r") as f:
        stock_text = f.read()

    # For Gaming (>= 3187200), keep stock kona.dtsi without cap
    if cap_freq >= 3187200:
        with open(path, "w") as f:
            f.write(stock_text)
        print("✅ [CPU Cap] Gaming Variant: Preserved stock kona.dtsi (Peak: 3.19 GHz)")
        return True

    text = stock_text
    markers = [
        '\t\t\t#freq-domain-cells = <2>;',
        '\t\t\tqcom,skip-enable-check;',
        '\t\t\tqcom,cpufreq-hw-freq-domain;',
    ]

    for marker in markers:
        if marker in text:
            insert = f'\n\t\t\t/* EXTREME+: Cap Prime Core (CPU7) to {cap_freq} kHz */\n\t\t\tqcom,freq-domain-max-freq = <{cap_freq}>;\n'
            text = text.replace(marker, marker + insert, 1)
            with open(path, "w") as f:
                f.write(text)
            print(f"✅ [CPU Cap] CPU Prime Core capped in kona.dtsi to {cap_freq} kHz via {marker.strip()}")
            return True
    return True

if __name__ == "__main__":
    target_freq = 2841600 # Default to 2.84 GHz balanced
    dts_path = "arch/arm64/boot/dts/vendor/qcom/kona.dtsi"
    driver_path = "drivers/cpufreq/qcom-cpufreq-hw.c"

    for arg in sys.argv[1:]:
        if arg.endswith(".dtsi"):
            dts_path = arg
        elif arg.endswith(".c"):
            driver_path = arg
        else:
            freq = parse_target_freq(arg)
            if freq:
                target_freq = freq

    print(f"🚀 [CPU Cap] Configuring Prime Core clamp at {target_freq} kHz...")
    patch_dts(dts_path, target_freq)
    patch_driver(driver_path, target_freq)
    sys.exit(0)
