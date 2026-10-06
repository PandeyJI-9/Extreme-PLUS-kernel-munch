#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch / SM8250-AC Kona) | Target: HyperOS ONLY
# Prime Core (CPU 7) Hardware Frequency Clamping Architecture
# ==============================================================================
# Supported Target Frequencies (Validated Qualcomm Kona EPSS LUT steps):
# 1. 2419200 kHz (~2.42 GHz) -> Battery Variant (Matched to Gold Core Peak)
# 2. 2841600 kHz (2.84 GHz)  -> Bal-Gaming Variant (Balanced Kryo 585 Prime)
# 3. 3187200 kHz (3.19 GHz)  -> Gaming Variant (Max Stock Prime Core Boost)
# ==============================================================================
import sys
import os
import re

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

    with open(path, "r") as f:
        content = f.read()

    # Match existing clamp block regardless of comment style
    p = re.compile(r"(cpumask_test_cpu\(7, &c->related_cpus\) && c->table\[i\]\.frequency >= )\d+(\) \{\s*c->table\[i\]\.frequency = )\d+(;)")
    if p.search(content):
        content = p.sub(rf"\g<1>{cap_freq}\g<2>{cap_freq}\g<3>", content)
        with open(path, "w") as f:
            f.write(content)
        print(f"✅ [CPU Cap] Updated drivers/cpufreq/qcom-cpufreq-hw.c Prime Core clamp to {cap_freq} kHz")
        return True

    # If not yet patched, insert the clamp logic into stock qcom_cpufreq_hw_read_lut
    target = """\t\tfor_each_cpu(cpu, &c->related_cpus) {
\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\tif (!cpu_dev)
\t\t\t\tcontinue;
\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000,
\t\t\t\t\t\t\tvolt);
\t\t}"""

    replacement = f"""\t\t/* EXTREME+: Prime Core Hardware Frequency Clamp */
\t\tif (cpumask_test_cpu(7, &c->related_cpus) && c->table[i].frequency >= {cap_freq}) {{
\t\t\tc->table[i].frequency = {cap_freq};
\t\t\tfor_each_cpu(cpu, &c->related_cpus) {{
\t\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\t\tif (!cpu_dev)
\t\t\t\t\tcontinue;
\t\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000, volt);
\t\t\t}}
\t\t\tc->table[i + 1].frequency = CPUFREQ_TABLE_END;
\t\t\tc->table[i + 1].flags = 0;
\t\t\tbreak;
\t\t}}

\t\tfor_each_cpu(cpu, &c->related_cpus) {{
\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\tif (!cpu_dev)
\t\t\t\tcontinue;
\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000,
\t\t\t\t\t\t\tvolt);
\t\t}}"""

    if target in content:
        content = content.replace(target, replacement, 1)
        with open(path, "w") as f:
            f.write(content)
        print(f"✅ [CPU Cap] Successfully patched drivers/cpufreq/qcom-cpufreq-hw.c to {cap_freq} kHz")
        return True
    else:
        print("⚠️ [CPU Cap] Target pattern not found in qcom-cpufreq-hw.c")
        return False

def patch_dts(path="arch/arm64/boot/dts/vendor/qcom/kona.dtsi", cap_freq=2841600):
    if not os.path.exists(path):
        return True

    with open(path, "r") as f:
        text = f.read()

    if "qcom,freq-domain-max-freq" in text:
        text = re.sub(r"qcom,freq-domain-max-freq\s*=\s*<[^>]+>;", f"qcom,freq-domain-max-freq = <{cap_freq}>;", text)
        with open(path, "w") as f:
            f.write(text)
        print(f"✅ [CPU Cap] CPU Prime Core cap updated in kona.dtsi to {cap_freq} kHz")
        return True

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
