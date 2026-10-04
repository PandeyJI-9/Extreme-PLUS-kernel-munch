#!/usr/bin/env python3
"""
PROJECT EXTREME+ V2: Native C-Level 2.84 GHz Prime Core Hard Clamp
C-level clamp in drivers/cpufreq/qcom-cpufreq-hw.c:
- Hides the 3.187 GHz step from the cpufreq OPP table for CPU 7 (Prime Core)
- Sets CPUFREQ_TABLE_END right at 2841600 kHz
- Qualcomm hardware registers are read with 100% stock voltages (ZERO PMIC crash)
- Thermal-engine, Joyose, and Schedutil see 2.841 GHz as the physical hardware max
"""

import sys
import os
import re

def patch_driver(path="drivers/cpufreq/qcom-cpufreq-hw.c"):
    if not os.path.exists(path):
        print(f"⚠️ [2.8GHz C-Clamp] File not found: {path}")
        return False
    with open(path, "r") as f:
        content = f.read()

    if "/* EXTREME+ V2: Native 2.84 GHz Prime Core Clamp */" in content:
        print("ℹ️ [2.8GHz C-Clamp] Driver already patched.")
        return True

    target = """\t\tfor_each_cpu(cpu, &c->related_cpus) {
\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\tif (!cpu_dev)
\t\t\t\tcontinue;
\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000,
\t\t\t\t\t\t\tvolt);
\t\t}"""

    replacement = """\t\t/* EXTREME+ V2: Native 2.84 GHz Prime Core Clamp */
\t\tif (cpumask_test_cpu(7, &c->related_cpus) && c->table[i].frequency >= 2841600) {
\t\t\tc->table[i].frequency = 2841600;
\t\t\tfor_each_cpu(cpu, &c->related_cpus) {
\t\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\t\tif (!cpu_dev)
\t\t\t\t\tcontinue;
\t\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000, volt);
\t\t\t}
\t\t\tc->table[i + 1].frequency = CPUFREQ_TABLE_END;
\t\t\tc->table[i + 1].flags = 0;
\t\t\tbreak;
\t\t}

\t\tfor_each_cpu(cpu, &c->related_cpus) {
\t\t\tcpu_dev = get_cpu_device(cpu);
\t\t\tif (!cpu_dev)
\t\t\t\tcontinue;
\t\t\tdev_pm_opp_add(cpu_dev, c->table[i].frequency * 1000,
\t\t\t\t\t\t\tvolt);
\t\t}"""

    if target in content:
        content = content.replace(target, replacement, 1)
        with open(path, "w") as f:
            f.write(content)
        print("✅ [2.8GHz C-Clamp] Successfully patched drivers/cpufreq/qcom-cpufreq-hw.c")
        return True
    else:
        print("⚠️ [2.8GHz C-Clamp] Target pattern not found in qcom-cpufreq-hw.c")
        return False

def patch_dts(path="arch/arm64/boot/dts/vendor/qcom/kona.dtsi"):
    if not os.path.exists(path):
        return True
    with open(path, 'r') as f:
        text = f.read()

    if 'qcom,freq-domain-max-freq' in text:
        text = re.sub(r"qcom,freq-domain-max-freq\s*=\s*<[^>]+>;", "qcom,freq-domain-max-freq = <2841600>;", text)
        with open(path, 'w') as f:
            f.write(text)
        print("✅ [2.8GHz C-Clamp] CPU Prime Core cap updated in kona.dtsi")
        return True

    markers = [
        '\t\t\t#freq-domain-cells = <2>;',
        '\t\t\tqcom,skip-enable-check;',
        '\t\t\tqcom,cpufreq-hw-freq-domain;',
    ]

    for marker in markers:
        if marker in text:
            insert = '\n\t\t\t/* EXTREME+ V2: Cap Prime Core (CPU7) to 2.84 GHz */\n\t\t\tqcom,freq-domain-max-freq = <2841600>;\n'
            text = text.replace(marker, marker + insert, 1)
            with open(path, 'w') as f:
                f.write(text)
            print(f"✅ [2.8GHz C-Clamp] CPU Prime Core capped in kona.dtsi via {marker.strip()}")
            return True
    return True

if __name__ == '__main__':
    patch_dts()
    patch_driver()
    sys.exit(0)
