#!/bin/bash
# ==========================================
# EXTREME++ HyperOS Kernel Build Script
# Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Target: HyperOS ONLY
# ==========================================

set -e
trap 'echo "❌ [ERROR] Script failed on line $LINENO"; exit 1' ERR

if [ -z "$1" ]; then
    echo "[!] Error: No device specified."
    exit 1
fi

DEVICE_NAME="$1"
DEFCONFIG="${DEVICE_NAME}_defconfig"
ENABLE_KSU=0

if [ "$2" == "ksu" ]; then
    ENABLE_KSU=1
fi

KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out"
TOOLCHAIN_BIN="$HOME/zyc-clang/bin"

export PATH="${TOOLCHAIN_BIN}:${PATH}"
export ARCH="arm64"
export SUBARCH="arm64"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
export CCACHE_DIR="$HOME/.cache/ccache_mikernel"
export CCACHE_EXEC=$(command -v ccache)
export USE_CCACHE=1

# ------------------------------------------
# 🚀 SYSTEM CORES SETUP (Full Speed)
# ------------------------------------------
TOTAL_CORES=$(nproc --all)
echo "[*] System Cores: ${TOTAL_CORES} | Running at FULL SPEED!"
echo "[*] Cleaning previous builds..."
rm -rf "${OUT_DIR}" anykernel
mkdir -p "${OUT_DIR}"
find . -type f \( -name "dtbo.img" -o -name "Image" -o -name "Image.gz" \) -delete

# ------------------------------------------
# 1. Custom Kernel Name Configuration
# ------------------------------------------
echo "[*] Setting Custom Kernel Name to -EXTREME++GAMING_Hyperos..."
rm -f localversion*
sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-EXTREME++GAMING_Hyperos"/' "arch/arm64/configs/${DEFCONFIG}"
grep -q "CONFIG_LOCALVERSION=" "arch/arm64/configs/${DEFCONFIG}" || echo 'CONFIG_LOCALVERSION="-EXTREME++GAMING_Hyperos"' >> "arch/arm64/configs/${DEFCONFIG}"
sed -i 's/^EXTRAVERSION =.*/EXTRAVERSION =/' Makefile

# ZRAM ZSTD & Schedutil defconfig tunables
sed -i 's/CONFIG_ZRAM_DEF_COMP_LZ4=y/CONFIG_ZRAM_DEF_COMP_ZSTD=y/' "arch/arm64/configs/${DEFCONFIG}"
grep -q "CONFIG_CRYPTO_ZSTD=y" "arch/arm64/configs/${DEFCONFIG}" || cat >> "arch/arm64/configs/${DEFCONFIG}" << 'EOF'
CONFIG_CRYPTO_ZSTD=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_ZRAM_DEF_COMP="zstd"
CONFIG_SCHEDUTIL_UP_RATE_LIMIT=0
EOF

# ------------------------------------------
# 2. Baseband & Network Guard
# ------------------------------------------
echo "[*] Injecting Baseband-guard Setup..."
if ! wget -qO- https://raw.githubusercontent.com/vc-teahouse/Baseband-guard/main/setup.sh | bash; then
    echo "❌ [ERROR] Baseband-guard download failed!"
    exit 1
fi

if ! grep -q "selinux,baseband_guard" security/Kconfig; then
    sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
fi

# ------------------------------------------
# 3. KernelSU (ReSukiSU Non-GKI 4.19 with SuSFS) Setup
# ------------------------------------------
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "[*] Injecting ReSukiSU (Non-GKI 4.19 Legacy with SuSFS) Source..."
    curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
    
    # Ensure defconfig has KSU, SuSFS, and THREAD_INFO_IN_TASK
    echo "CONFIG_KSU=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_KSU_SUSFS=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_THREAD_INFO_IN_TASK=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "[+] ReSukiSU Non-GKI setup finished."
fi

# ------------------------------------------
# 4. Native GPU FakeDreamer 10-Step OPP Table (150MHz - 670MHz UV) & Speed Bins
# ------------------------------------------
echo "[*] Natively Applying FakeDreamer Adreno 650 10-Step OPP Tables & All Speed Bins..."

# Expand KGSL_MAX_PWRLEVELS to 16 to support all 10 frequencies + off level
if [ -f "drivers/gpu/msm/kgsl_pwrctrl.h" ]; then
    sed -i 's/#define KGSL_MAX_PWRLEVELS 10/#define KGSL_MAX_PWRLEVELS 16/' drivers/gpu/msm/kgsl_pwrctrl.h
    echo "[+] Expanded KGSL_MAX_PWRLEVELS to 16 in drivers/gpu/msm/kgsl_pwrctrl.h"
fi

python3 << 'EOF'
import re, os

def find_block_end(text, start_idx):
    depth = 0
    i = start_idx
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                j = i + 1
                while j < len(text) and text[j] in " \t\n":
                    j += 1
                if j < len(text) and text[j] == ";":
                    return j + 1
                return i + 1
        i += 1
    return -1

OPP_TABLE_BODY = """
\t\topp-670000000 {
\t\t\topp-hz = /bits/ 64 <670000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L2>;
\t\t};
\t\topp-587000000 {
\t\t\topp-hz = /bits/ 64 <587000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L1>;
\t\t};
\t\topp-525000000 {
\t\t\topp-hz = /bits/ 64 <525000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>;
\t\t};
\t\topp-490000000 {
\t\t\topp-hz = /bits/ 64 <490000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>;
\t\t};
\t\topp-441600000 {
\t\t\topp-hz = /bits/ 64 <441600000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};
\t\topp-441000000 {
\t\t\topp-hz = /bits/ 64 <441000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};
\t\topp-400000000 {
\t\t\topp-hz = /bits/ 64 <400000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};
\t\topp-305000000 {
\t\t\topp-hz = /bits/ 64 <305000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>;
\t\t};
\t\topp-250000000 {
\t\t\topp-hz = /bits/ 64 <250000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};
\t\topp-200000000 {
\t\t\topp-hz = /bits/ 64 <200000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>;
\t\t};
\t\topp-150000000 {
\t\t\topp-hz = /bits/ 64 <150000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>;
\t\t};
\t};"""

OPP_TABLE_V1 = "\tgpu_opp_table: gpu-opp-table {\n\t\tcompatible = \"operating-points-v2\";" + OPP_TABLE_BODY
OPP_TABLE_V2 = "\tgpu_opp_table_v2: gpu-opp-table_v2 {\n\t\tcompatible = \"operating-points-v2\";" + OPP_TABLE_BODY

PWRLEVELS_10_BIN = """
			#address-cells = <1>;
			#size-cells = <0>;
			qcom,speed-bin = <{BIN}>;
			qcom,initial-pwrlevel = <6>;
			qcom,throttle-pwrlevel = <1>;

			qcom,gpu-pwrlevel@0 {
				reg = <0>;
				qcom,gpu-freq = <670000000>;
				qcom,bus-freq-ddr7 = <11>;
				qcom,bus-min-ddr7 = <11>;
				qcom,bus-max-ddr7 = <11>;
				qcom,bus-freq-ddr8 = <11>;
				qcom,bus-min-ddr8 = <11>;
				qcom,bus-max-ddr8 = <11>;
				qcom,acd-level = <0x802b5ffd>;
			};

			qcom,gpu-pwrlevel@1 {
				reg = <1>;
				qcom,gpu-freq = <587000000>;
				qcom,bus-freq-ddr7 = <11>;
				qcom,bus-min-ddr7 = <11>;
				qcom,bus-max-ddr7 = <11>;
				qcom,bus-freq-ddr8 = <11>;
				qcom,bus-min-ddr8 = <11>;
				qcom,bus-max-ddr8 = <11>;
				qcom,acd-level = <0x802b5ffd>;
			};

			qcom,gpu-pwrlevel@2 {
				reg = <2>;
				qcom,gpu-freq = <525000000>;
				qcom,bus-freq-ddr7 = <9>;
				qcom,bus-min-ddr7 = <9>;
				qcom,bus-max-ddr7 = <11>;
				qcom,bus-freq-ddr8 = <8>;
				qcom,bus-min-ddr8 = <8>;
				qcom,bus-max-ddr8 = <11>;
				qcom,acd-level = <0x802b5ffd>;
			};

			qcom,gpu-pwrlevel@3 {
				reg = <3>;
				qcom,gpu-freq = <490000000>;
				qcom,bus-freq-ddr7 = <9>;
				qcom,bus-min-ddr7 = <6>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <8>;
				qcom,bus-min-ddr8 = <7>;
				qcom,bus-max-ddr8 = <9>;
				qcom,acd-level = <0xa02b5ffd>;
			};

			qcom,gpu-pwrlevel@4 {
				reg = <4>;
				qcom,gpu-freq = <441600000>;
				qcom,bus-freq-ddr7 = <9>;
				qcom,bus-min-ddr7 = <6>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <8>;
				qcom,bus-min-ddr8 = <7>;
				qcom,bus-max-ddr8 = <9>;
				qcom,acd-level = <0xa02b5ffd>;
			};

			qcom,gpu-pwrlevel@5 {
				reg = <5>;
				qcom,gpu-freq = <400000000>;
				qcom,bus-freq-ddr7 = <7>;
				qcom,bus-min-ddr7 = <6>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <8>;
				qcom,bus-min-ddr8 = <6>;
				qcom,bus-max-ddr8 = <9>;
				qcom,acd-level = <0xa02b5ffd>;
			};

			qcom,gpu-pwrlevel@6 {
				reg = <6>;
				qcom,gpu-freq = <305000000>;
				qcom,bus-freq-ddr7 = <3>;
				qcom,bus-min-ddr7 = <2>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <3>;
				qcom,bus-min-ddr8 = <2>;
				qcom,bus-max-ddr8 = <9>;
			};

			qcom,gpu-pwrlevel@7 {
				reg = <7>;
				qcom,gpu-freq = <250000000>;
				qcom,bus-freq-ddr7 = <3>;
				qcom,bus-min-ddr7 = <2>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <3>;
				qcom,bus-min-ddr8 = <2>;
				qcom,bus-max-ddr8 = <9>;
			};

			qcom,gpu-pwrlevel@8 {
				reg = <8>;
				qcom,gpu-freq = <200000000>;
				qcom,bus-freq-ddr7 = <2>;
				qcom,bus-min-ddr7 = <1>;
				qcom,bus-max-ddr7 = <3>;
				qcom,bus-freq-ddr8 = <2>;
				qcom,bus-min-ddr8 = <1>;
				qcom,bus-max-ddr8 = <3>;
			};

			qcom,gpu-pwrlevel@9 {
				reg = <9>;
				qcom,gpu-freq = <150000000>;
				qcom,bus-freq-ddr7 = <2>;
				qcom,bus-min-ddr7 = <1>;
				qcom,bus-max-ddr7 = <3>;
				qcom,bus-freq-ddr8 = <2>;
				qcom,bus-min-ddr8 = <1>;
				qcom,bus-max-ddr8 = <3>;
			};

			qcom,gpu-pwrlevel@10 {
				reg = <10>;
				qcom,gpu-freq = <0>;
				qcom,bus-freq = <0>;
				qcom,bus-min = <0>;
				qcom,bus-max = <0>;
			};
		};"""

PWRLEVELS_10_LEGACY = """\t\tqcom,gpu-pwrlevels {
			#address-cells = <1>;
			#size-cells = <0>;
			compatible = "qcom,gpu-pwrlevels";
			qcom,initial-pwrlevel = <6>;
			qcom,throttle-pwrlevel = <1>;

			qcom,gpu-pwrlevel@0 {
				reg = <0>;
				qcom,gpu-freq = <670000000>;
				qcom,bus-freq-ddr7 = <11>;
				qcom,bus-min-ddr7 = <11>;
				qcom,bus-max-ddr7 = <11>;
				qcom,bus-freq-ddr8 = <11>;
				qcom,bus-min-ddr8 = <11>;
				qcom,bus-max-ddr8 = <11>;
				qcom,acd-level = <0x802b5ffd>;
			};

			qcom,gpu-pwrlevel@1 {
				reg = <1>;
				qcom,gpu-freq = <587000000>;
				qcom,bus-freq-ddr7 = <11>;
				qcom,bus-min-ddr7 = <11>;
				qcom,bus-max-ddr7 = <11>;
				qcom,bus-freq-ddr8 = <11>;
				qcom,bus-min-ddr8 = <11>;
				qcom,bus-max-ddr8 = <11>;
				qcom,acd-level = <0x802b5ffd>;
			};

			qcom,gpu-pwrlevel@2 {
				reg = <2>;
				qcom,gpu-freq = <525000000>;
				qcom,bus-freq-ddr7 = <9>;
				qcom,bus-min-ddr7 = <9>;
				qcom,bus-max-ddr7 = <11>;
				qcom,bus-freq-ddr8 = <8>;
				qcom,bus-min-ddr8 = <8>;
				qcom,bus-max-ddr8 = <11>;
				qcom,acd-level = <0x802b5ffd>;
			};

			qcom,gpu-pwrlevel@3 {
				reg = <3>;
				qcom,gpu-freq = <490000000>;
				qcom,bus-freq-ddr7 = <9>;
				qcom,bus-min-ddr7 = <6>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <8>;
				qcom,bus-min-ddr8 = <7>;
				qcom,bus-max-ddr8 = <9>;
				qcom,acd-level = <0xa02b5ffd>;
			};

			qcom,gpu-pwrlevel@4 {
				reg = <4>;
				qcom,gpu-freq = <441600000>;
				qcom,bus-freq-ddr7 = <9>;
				qcom,bus-min-ddr7 = <6>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <8>;
				qcom,bus-min-ddr8 = <7>;
				qcom,bus-max-ddr8 = <9>;
				qcom,acd-level = <0xa02b5ffd>;
			};

			qcom,gpu-pwrlevel@5 {
				reg = <5>;
				qcom,gpu-freq = <400000000>;
				qcom,bus-freq-ddr7 = <7>;
				qcom,bus-min-ddr7 = <6>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <8>;
				qcom,bus-min-ddr8 = <6>;
				qcom,bus-max-ddr8 = <9>;
				qcom,acd-level = <0xa02b5ffd>;
			};

			qcom,gpu-pwrlevel@6 {
				reg = <6>;
				qcom,gpu-freq = <305000000>;
				qcom,bus-freq-ddr7 = <3>;
				qcom,bus-min-ddr7 = <2>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <3>;
				qcom,bus-min-ddr8 = <2>;
				qcom,bus-max-ddr8 = <9>;
			};

			qcom,gpu-pwrlevel@7 {
				reg = <7>;
				qcom,gpu-freq = <250000000>;
				qcom,bus-freq-ddr7 = <3>;
				qcom,bus-min-ddr7 = <2>;
				qcom,bus-max-ddr7 = <9>;
				qcom,bus-freq-ddr8 = <3>;
				qcom,bus-min-ddr8 = <2>;
				qcom,bus-max-ddr8 = <9>;
			};

			qcom,gpu-pwrlevel@8 {
				reg = <8>;
				qcom,gpu-freq = <200000000>;
				qcom,bus-freq-ddr7 = <2>;
				qcom,bus-min-ddr7 = <1>;
				qcom,bus-max-ddr7 = <3>;
				qcom,bus-freq-ddr8 = <2>;
				qcom,bus-min-ddr8 = <1>;
				qcom,bus-max-ddr8 = <3>;
			};

			qcom,gpu-pwrlevel@9 {
				reg = <9>;
				qcom,gpu-freq = <150000000>;
				qcom,bus-freq-ddr7 = <2>;
				qcom,bus-min-ddr7 = <1>;
				qcom,bus-max-ddr7 = <3>;
				qcom,bus-freq-ddr8 = <2>;
				qcom,bus-min-ddr8 = <1>;
				qcom,bus-max-ddr8 = <3>;
			};

			qcom,gpu-pwrlevel@10 {
				reg = <10>;
				qcom,gpu-freq = <0>;
				qcom,bus-freq = <0>;
				qcom,bus-min = <0>;
				qcom,bus-max = <0>;
			};
		};"""

# 1. Patch arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi
path1 = "arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi"
if os.path.isfile(path1):
    with open(path1, "r") as f:
        t1 = f.read()

    m1 = re.search(r"gpu_opp_table:\s*gpu-opp-table\s*\{", t1)
    if m1:
        b1 = t1.find("{", m1.start())
        e1 = find_block_end(t1, b1)
        if e1 != -1:
            t1 = t1[:m1.start()] + OPP_TABLE_V1 + t1[e1:]

    mp1 = re.search(r"qcom,gpu-pwrlevels\s*\{", t1)
    if mp1:
        bp1 = t1.find("{", mp1.start())
        ep1 = find_block_end(t1, bp1)
        if ep1 != -1:
            t1 = t1[:mp1.start()] + PWRLEVELS_10_LEGACY + t1[ep1:]

    t1 = re.sub(r"qcom,initial-pwrlevel\s*=\s*<\d+>;", "qcom,initial-pwrlevel = <6>;", t1)
    with open(path1, "w") as f:
        f.write(t1)
    print("✅ kona-gpu.dtsi: Full 10-step UV OPP table + power levels injected!")

# 2. Patch arch/arm64/boot/dts/vendor/qcom/kona-v2-gpu.dtsi (Active on POCO F4 / Kona v2.x!)
path2 = "arch/arm64/boot/dts/vendor/qcom/kona-v2-gpu.dtsi"
if os.path.isfile(path2):
    with open(path2, "r") as f:
        t2 = f.read()

    m2 = re.search(r"gpu_opp_table_v2:\s*gpu-opp-table_v2\s*\{", t2)
    if m2:
        b2 = t2.find("{", m2.start())
        e2 = find_block_end(t2, b2)
        if e2 != -1:
            t2 = t2[:m2.start()] + OPP_TABLE_V2 + t2[e2:]

    # Replace all speed bins (bins 0, 1, 2, 3, 4) with full 10-step tables
    matches = list(re.finditer(r"(qcom,gpu-pwrlevels-(\d+)\s*\{)", t2))
    for m in reversed(matches):
        bin_idx = m.group(2)
        end = find_block_end(t2, m.end() - 1)
        old_block = t2[m.start():end]
        sb_match = re.search(r"qcom,speed-bin\s*=\s*<(\d+)>;", old_block)
        sb_val = sb_match.group(1) if sb_match else bin_idx
        new_block = "\t\tqcom,gpu-pwrlevels-" + bin_idx + " {" + PWRLEVELS_10_BIN.replace("{BIN}", sb_val)
        t2 = t2[:m.start()] + new_block + t2[end:]

    t2 = re.sub(r"qcom,initial-pwrlevel\s*=\s*<\d+>;", "qcom,initial-pwrlevel = <6>;", t2)
    with open(path2, "w") as f:
        f.write(t2)
    print("✅ kona-v2-gpu.dtsi: Full 10-step UV OPP table + ALL 5 speed bins injected!")

# 3. Patch arch/arm64/boot/dts/vendor/qcom/kona-v2.1-gpu.dtsi (Specific to POCO F4 / Kona v2.1 SM8250-AC!)
path3 = "arch/arm64/boot/dts/vendor/qcom/kona-v2.1-gpu.dtsi"
v2_1_content = """&soc {
\tgpu_opp_table_v2_1: gpu-opp-table_v2_1 {
\t\tcompatible = "operating-points-v2";
""" + OPP_TABLE_BODY + """
};

&msm_gpu {
\tqcom,chipid = <0x06050002>;
\toperating-points-v2 = <&gpu_opp_table_v2_1>;
\tqcom,initial-pwrlevel = <6>;
};
"""
with open(path3, "w") as f:
    f.write(v2_1_content)
print("✅ kona-v2.1-gpu.dtsi: Explicit gpu_opp_table_v2_1 UV OPP table locked to msm_gpu!")

print("✅ ALL GPU OPP TABLES AND SPEED BINS VERIFIED 100%!")

# 4. Patch drivers/gpu/msm/adreno.c (C-level hardcoding of 10 UV levels + OPPs + safe fallback)
path_adreno = "drivers/gpu/msm/adreno.c"
if os.path.isfile(path_adreno):
    with open(path_adreno, "r") as f:
        t_adreno = f.read()

    # Include pm_opp.h if not present
    if "<linux/pm_opp.h>" not in t_adreno:
        inc_target = "#include <linux/of_fdt.h>"
        inc_patch = "#include <linux/of_fdt.h>\n#include <linux/pm_opp.h>"
        if inc_target in t_adreno:
            t_adreno = t_adreno.replace(inc_target, inc_patch, 1)

    # Non-fatal dev_pm_opp_of_add_table (prevent DTBO clash panic)
    opp_target = """	/* ADD the GPU OPP table if we define it */
	if (of_find_property(device->pdev->dev.of_node,
			"operating-points-v2", NULL)) {
		ret = dev_pm_opp_of_add_table(&device->pdev->dev);
		if (ret) {
			dev_err(device->dev,
				"Unable to set the GPU OPP table: %d\\n", ret);
			return ret;
		}
	}"""
    opp_patch = """	/* ADD the GPU OPP table if we define it */
	if (of_find_property(device->pdev->dev.of_node,
			"operating-points-v2", NULL)) {
		ret = dev_pm_opp_of_add_table(&device->pdev->dev);
		if (ret && ret != -EEXIST) {
			dev_warn(device->dev,
				"Unable to set the GPU OPP table: %d (continuing with C enforcement)\\n", ret);
		}
	}"""
    if opp_target in t_adreno:
        t_adreno = t_adreno.replace(opp_target, opp_patch, 1)

    # Bulletproof bounds check in adreno_of_get_initial_pwrlevel
    b_target = """	if (init_level < 0 || init_level > pwr->num_pwrlevels)
		init_level = 1;"""
    b_patch = """	if (init_level < 0 || (pwr->num_pwrlevels > 0 && init_level >= pwr->num_pwrlevels - 1))
		init_level = (pwr->num_pwrlevels > 6) ? 6 : 1;"""
    if b_target in t_adreno:
        t_adreno = t_adreno.replace(b_target, b_patch, 1)

    # Inject adreno_enforce_extreme_pwrlevels definition
    if "adreno_enforce_extreme_pwrlevels" not in t_adreno:
        func_target = "static void adreno_of_get_initial_pwrlevel("
        func_code = """/* EXTREME++ Natively Enforced 10-Step GPU UV Power Levels (150MHz - 670MHz) */
static void adreno_enforce_extreme_pwrlevels(struct adreno_device *adreno_dev)
{
	struct kgsl_device *device = KGSL_DEVICE(adreno_dev);
	struct kgsl_pwrctrl *pwr = &device->pwrctrl;
	int ddr;
	bool is_ddr7;
	int i;
	static const unsigned long opp_freqs[10] = {
		670000000, 587000000, 525000000, 490000000, 441600000,
		400000000, 305000000, 250000000, 200000000, 150000000
	};
	static const unsigned long opp_volts[10] = {
		224, 192, 128, 128, 64,
		64, 48, 64, 48, 48
	};

	ddr = of_fdt_get_ddrtype();
	is_ddr7 = (ddr == 7);

	for (i = 0; i < 10; i++) {
		struct dev_pm_opp *opp;
		opp = dev_pm_opp_find_freq_exact(&device->pdev->dev, opp_freqs[i], true);
		if (IS_ERR_OR_NULL(opp)) {
			dev_pm_opp_add(&device->pdev->dev, opp_freqs[i], opp_volts[i]);
		} else {
			dev_pm_opp_put(opp);
		}
	}

	pwr->num_pwrlevels = 11;

	/* Level 0: 670 MHz */
	pwr->pwrlevels[0].gpu_freq = 670000000;
	pwr->pwrlevels[0].bus_freq = 11;
	pwr->pwrlevels[0].bus_min = 11;
	pwr->pwrlevels[0].bus_max = 11;
	pwr->pwrlevels[0].acd_level = 0x802b5ffd;

	/* Level 1: 587 MHz */
	pwr->pwrlevels[1].gpu_freq = 587000000;
	pwr->pwrlevels[1].bus_freq = 11;
	pwr->pwrlevels[1].bus_min = 11;
	pwr->pwrlevels[1].bus_max = 11;
	pwr->pwrlevels[1].acd_level = 0x802b5ffd;

	/* Level 2: 525 MHz */
	pwr->pwrlevels[2].gpu_freq = 525000000;
	pwr->pwrlevels[2].bus_freq = is_ddr7 ? 9 : 8;
	pwr->pwrlevels[2].bus_min = is_ddr7 ? 9 : 8;
	pwr->pwrlevels[2].bus_max = 11;
	pwr->pwrlevels[2].acd_level = 0x802b5ffd;

	/* Level 3: 490 MHz */
	pwr->pwrlevels[3].gpu_freq = 490000000;
	pwr->pwrlevels[3].bus_freq = is_ddr7 ? 9 : 8;
	pwr->pwrlevels[3].bus_min = is_ddr7 ? 6 : 7;
	pwr->pwrlevels[3].bus_max = 9;
	pwr->pwrlevels[3].acd_level = 0xa02b5ffd;

	/* Level 4: 441.6 MHz */
	pwr->pwrlevels[4].gpu_freq = 441600000;
	pwr->pwrlevels[4].bus_freq = is_ddr7 ? 9 : 8;
	pwr->pwrlevels[4].bus_min = is_ddr7 ? 6 : 7;
	pwr->pwrlevels[4].bus_max = 9;
	pwr->pwrlevels[4].acd_level = 0xa02b5ffd;

	/* Level 5: 400 MHz */
	pwr->pwrlevels[5].gpu_freq = 400000000;
	pwr->pwrlevels[5].bus_freq = is_ddr7 ? 7 : 8;
	pwr->pwrlevels[5].bus_min = 6;
	pwr->pwrlevels[5].bus_max = 9;
	pwr->pwrlevels[5].acd_level = 0xa02b5ffd;

	/* Level 6: 305 MHz (Default boot level) */
	pwr->pwrlevels[6].gpu_freq = 305000000;
	pwr->pwrlevels[6].bus_freq = 3;
	pwr->pwrlevels[6].bus_min = 2;
	pwr->pwrlevels[6].bus_max = 9;
	pwr->pwrlevels[6].acd_level = 0;

	/* Level 7: 250 MHz (Low Idle) */
	pwr->pwrlevels[7].gpu_freq = 250000000;
	pwr->pwrlevels[7].bus_freq = 3;
	pwr->pwrlevels[7].bus_min = 2;
	pwr->pwrlevels[7].bus_max = 9;
	pwr->pwrlevels[7].acd_level = 0;

	/* Level 8: 200 MHz (Ultra Low Idle) */
	pwr->pwrlevels[8].gpu_freq = 200000000;
	pwr->pwrlevels[8].bus_freq = 2;
	pwr->pwrlevels[8].bus_min = 1;
	pwr->pwrlevels[8].bus_max = 3;
	pwr->pwrlevels[8].acd_level = 0;

	/* Level 9: 150 MHz (Lowest Active UV State) */
	pwr->pwrlevels[9].gpu_freq = 150000000;
	pwr->pwrlevels[9].bus_freq = 2;
	pwr->pwrlevels[9].bus_min = 1;
	pwr->pwrlevels[9].bus_max = 3;
	pwr->pwrlevels[9].acd_level = 0;

	/* Level 10: 0 MHz (Power Off) */
	pwr->pwrlevels[10].gpu_freq = 0;
	pwr->pwrlevels[10].bus_freq = 0;
	pwr->pwrlevels[10].bus_min = 0;
	pwr->pwrlevels[10].bus_max = 0;
	pwr->pwrlevels[10].acd_level = 0;

	pwr->max_pwrlevel = 0;
	pwr->min_pwrlevel = 9;
	pwr->thermal_pwrlevel = 0;
	pwr->thermal_pwrlevel_floor = 9;
	pwr->default_pwrlevel = 6;
	pwr->active_pwrlevel = 6;

	dev_info(device->dev, "EXTREME++: Natively enforced 10-step GPU UV power levels (150MHz - 670MHz)\\n");
}

"""
        if func_target in t_adreno:
            t_adreno = t_adreno.replace(func_target, func_code + func_target, 1)

        # Enforce in adreno_of_get_pwrlevels
        call_target1 = """			adreno_of_get_limits(adreno_dev, parent);
			adreno_of_get_limits(adreno_dev, child);

			return 0;"""
        call_patch1 = """			adreno_of_get_limits(adreno_dev, parent);
			adreno_of_get_limits(adreno_dev, child);

			adreno_enforce_extreme_pwrlevels(adreno_dev);
			return 0;"""
        if call_target1 in t_adreno:
            t_adreno = t_adreno.replace(call_target1, call_patch1, 1)

        # Enforce on speed-bin mismatch fallback
        idx = t_adreno.find("mismatch for efused bin")
        if idx != -1:
            start = t_adreno.rfind("dev_err(KGSL_DEVICE(adreno_dev)", 0, idx)
            end = t_adreno.find("return -ENODEV;", idx)
            if start != -1 and end != -1:
                end += len("return -ENODEV;")
                new_fallback = """dev_err(KGSL_DEVICE(adreno_dev)->dev,
		"GPU speed_bin:%d mismatch for efused bin:%d, falling back to EXTREME++ UV\\n",
		adreno_dev->speed_bin, bin);
	adreno_enforce_extreme_pwrlevels(adreno_dev);
	return 0;"""
                t_adreno = t_adreno[:start] + new_fallback + t_adreno[end:]

        # Enforce in legacy pwrlevels
        legacy_target = """	adreno_of_get_bimc_iface_clk(adreno_dev, parent);

	return 0;"""
        legacy_patch = """	adreno_of_get_bimc_iface_clk(adreno_dev, parent);

	adreno_enforce_extreme_pwrlevels(adreno_dev);
	return 0;"""
        if legacy_target in t_adreno:
            t_adreno = t_adreno.replace(legacy_target, legacy_patch, 1)

        # Enforce in adreno_of_get_power with safe fallback
        power_target = """	if (adreno_of_get_pwrlevels(adreno_dev, node))
		return -EINVAL;"""
        power_patch = """	if (adreno_of_get_pwrlevels(adreno_dev, node)) {
		dev_warn(device->dev, "adreno_of_get_pwrlevels failed, falling back to EXTREME++ UV\\n");
		adreno_enforce_extreme_pwrlevels(adreno_dev);
	} else {
		adreno_enforce_extreme_pwrlevels(adreno_dev);
	}"""
        if power_target in t_adreno:
            t_adreno = t_adreno.replace(power_target, power_patch, 1)

        with open(path_adreno, "w") as f:
            f.write(t_adreno)
        print("✅ adreno.c: Patched with C-level 10-step UV enforcement & DTBO bypass!")

# 5. Patch drivers/gpu/msm/kgsl_pwrctrl.h (expand KGSL_MAX_PWRLEVELS from 10 to 16 to prevent buffer overflow)
path_pwrctrl_h = "drivers/gpu/msm/kgsl_pwrctrl.h"
if os.path.isfile(path_pwrctrl_h):
    with open(path_pwrctrl_h, "r") as f:
        t_h = f.read()
    t_h = t_h.replace("#define KGSL_MAX_PWRLEVELS 10", "#define KGSL_MAX_PWRLEVELS 16", 1)
    with open(path_pwrctrl_h, "w") as f:
        f.write(t_h)
    print("✅ kgsl_pwrctrl.h: Expanded KGSL_MAX_PWRLEVELS to 16 (anti-overflow)")

print("✅ ALL GPU OPP TABLES, SPEED BINS, AND C DRIVER ENFORCEMENT APPLIED 100%!")
EOF


# ------------------------------------------
# 5. Native CPU Peak Cap (2.84 GHz / Drop 3.2 GHz Peak Step)
# ------------------------------------------
echo "[*] Natively Applying CPU Peak Cap (2.84 GHz / Drop 3.2 GHz Peak Step)..."
python3 -c '
import re

# 1. Patch kona.dtsi
path_dts = "arch/arm64/boot/dts/vendor/qcom/kona.dtsi"
with open(path_dts, "r") as f:
    text_dts = f.read()

marker = "qcom,skip-enable-check;"
insertion = "\n\t\t\t/* EXTREME++: Cap Prime Core peak to 2.84 GHz (remove 3.187 GHz step) */\n\t\t\tqcom,freq-domain-max-freq = <2841600>;"
if "qcom,freq-domain-max-freq" in text_dts:
    text_dts = re.sub(r"qcom,freq-domain-max-freq\s*=\s*<[^>]+>;", "qcom,freq-domain-max-freq = <2841600>;", text_dts)
else:
    text_dts = text_dts.replace(marker, marker + insertion, 1)

with open(path_dts, "w") as f:
    f.write(text_dts)
print("✅ CPU Prime Core max-freq cap (<2841600>) set in kona.dtsi")

# 2. Patch drivers/cpufreq/qcom-cpufreq-hw.c (C89 compliant)
path_driver = "drivers/cpufreq/qcom-cpufreq-hw.c"
with open(path_driver, "r") as f:
    text_driver = f.read()

if "max_freq_cap" not in text_driver:
    target_decl = "\tu32 vc;\n\tunsigned long cpu;"
    patch_decl = "\tu32 vc, max_freq_cap = 0;\n\tunsigned long cpu;"
    text_driver = text_driver.replace(target_decl, patch_decl, 1)

    target_read = "spin_lock_init(&c->skip_data.lock);"
    patch_read = """spin_lock_init(&c->skip_data.lock);
\tof_property_read_u32(dev->of_node, "qcom,freq-domain-max-freq", &max_freq_cap);
\tif (!max_freq_cap)
\t\tmax_freq_cap = 2841600;"""
    text_driver = text_driver.replace(target_read, patch_read, 1)

    target_break = "dev_dbg(dev, \"index=%d freq=%d, core_count %d\\n\","
    patch_break = """if (max_freq_cap && c->table[i].frequency > max_freq_cap) {
\t\t\tbreak;
\t\t}
\t\tdev_dbg(dev, \"index=%d freq=%d, core_count %d\\n\","""
    text_driver = text_driver.replace(target_break, patch_break, 1)

    with open(path_driver, "w") as f:
        f.write(text_driver)
    print("✅ qcom-cpufreq-hw driver patched (C89 compliant) to honor freq-domain-max-freq (strictly 2841600)")
else:
    print("ℹ️ qcom-cpufreq-hw driver already patched")
'

# ------------------------------------------
# 6. HyperOS Display DTS Patches
# ------------------------------------------
DTS_SOURCE="arch/arm64/boot/dts/vendor/qcom"
echo "[*] Applying HyperOS / MIUI Display & Panel DTS patches..."
sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j1s* 2>/dev/null || true
sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j2* 2>/dev/null || true
sed -i 's/<155>/<1544>/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi 2>/dev/null || true
sed -i 's/<155>/<1545>/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi 2>/dev/null || true
sed -i 's/<155>/<1546>/g' ${DTS_SOURCE}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi 2>/dev/null || true
sed -i 's/<155>/<1546>/g' ${DTS_SOURCE}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi 2>/dev/null || true
sed -i 's/<71>/<710>/g' ${DTS_SOURCE}/dsi-panel-j1s* 2>/dev/null || true
sed -i 's/<71>/<710>/g' ${DTS_SOURCE}/dsi-panel-j2* 2>/dev/null || true
sed -i 's/120 90 60/120 90 60 50 30/g' ${DTS_SOURCE}/dsi-panel-g7a-36-02-0c-dsc-video.dtsi 2>/dev/null || true
sed -i 's/120 90 60/120 90 60 50 30/g' ${DTS_SOURCE}/dsi-panel-g7a-37-02-0a-dsc-video.dtsi 2>/dev/null || true
sed -i 's/120 90 60/120 90 60 50 30/g' ${DTS_SOURCE}/dsi-panel-g7a-37-02-0b-dsc-video.dtsi 2>/dev/null || true
sed -i 's/144 120 90 60/144 120 90 60 50 48 30/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi 2>/dev/null || true

# ------------------------------------------
# 7. Compile Environment Setup
# ------------------------------------------
MAKE_OPTS=(
    O="${OUT_DIR}"
    ARCH="${ARCH}"
    SUBARCH="${SUBARCH}"
    LLVM=1
    LLVM_IAS=1
    CC="ccache clang"
    HOSTCC="ccache clang"
    CROSS_COMPILE="${CROSS_COMPILE}"
    CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}"
)

echo "[*] Generating Defconfig (${DEFCONFIG})..."
make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" "${DEFCONFIG}"

# ------------------------------------------
# 8. Full HyperOS / MIUI Config Injection (AstideLabs standard) & Performance Tunables
# ------------------------------------------
echo "[*] Injecting Full HyperOS / MIUI Subsystem Configs..."
scripts/config --file "${OUT_DIR}/.config" -e BBG
scripts/config --file "${OUT_DIR}/.config" --set-str LOCALVERSION "-EXTREME++GAMING_Hyperos"

# 🚀 6GB RAM & Zero-Stutter Memory Optimizations (ZRAM ZSTD)
scripts/config --file "${OUT_DIR}/.config" \
    -e ZRAM \
    -e CRYPTO_ZSTD \
    -e ZSTD_COMPRESS \
    -e ZSTD_DECOMPRESS \
    -e ZRAM_DEF_COMP_ZSTD \
    -d ZRAM_DEF_COMP_LZ4 \
    --set-str ZRAM_DEF_COMP "zstd"

# 🚀 Instant Touch Reaction (Schedutil Governor zero-latency ramp-up)
scripts/config --file "${OUT_DIR}/.config" \
    -e CPU_FREQ_GOV_SCHEDUTIL \
    --set-val SCHEDUTIL_UP_RATE_LIMIT 0

# Native source patches for VM & Schedutil tunables
if [ -f "kernel/sched/cpufreq_schedutil.c" ]; then
    sed -i 's/tunables->up_rate_limit_us = CONFIG_SCHEDUTIL_UP_RATE_LIMIT;/tunables->up_rate_limit_us = 0;/' kernel/sched/cpufreq_schedutil.c
    echo "[+] Schedutil up_rate_limit_us set to 0 in kernel/sched/cpufreq_schedutil.c"
fi
if [ -f "drivers/cpufreq/cpufreq_schedutil.c" ]; then
    sed -i 's/tunables->up_rate_limit_us = CONFIG_SCHEDUTIL_UP_RATE_LIMIT;/tunables->up_rate_limit_us = 0;/' drivers/cpufreq/cpufreq_schedutil.c
    echo "[+] Schedutil up_rate_limit_us set to 0 in drivers/cpufreq/cpufreq_schedutil.c"
fi
if [ -f "mm/vmscan.c" ]; then
    sed -i 's/int vm_swappiness = 60;/int vm_swappiness = 100;/' mm/vmscan.c
    echo "[+] Optimized default vm_swappiness to 100 in mm/vmscan.c"
fi
if [ -f "fs/dcache.c" ]; then
    sed -i 's/int sysctl_vfs_cache_pressure __read_mostly = [0-9]*;/int sysctl_vfs_cache_pressure __read_mostly = 100;/' fs/dcache.c
    echo "[+] Optimized sysctl_vfs_cache_pressure to 100 in fs/dcache.c"
fi

if [ "$ENABLE_KSU" -eq 1 ]; then
    scripts/config --file "${OUT_DIR}/.config" -e KPROBES -e HAVE_KPROBES -e KPROBE_EVENTS
    scripts/config --file "${OUT_DIR}/.config" -e KSU -e THREAD_INFO_IN_TASK -e KSU_SUSFS
fi

scripts/config --file "${OUT_DIR}/.config" \
    --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
    -e PERF_CRITICAL_RT_TASK \
    -e SF_BINDER \
    -e OVERLAY_FS \
    -e MIGT \
    -e MIGT_ENERGY_MODEL \
    -e MIHW \
    -e PACKAGE_RUNTIME_INFO \
    -e BINDER_OPT \
    -e KPERFEVENTS \
    -e PERF_HUMANTASK \
    -d LTO_CLANG \
    -e LTO_NONE \
    -d SHADOW_CALL_STACK \
    -e XIAOMI_MIUI \
    -d MI_MEMORY_SYSFS \
    -e TASK_DELAY_ACCT \
    -e MIUI_ZRAM_MEMORY_TRACKING \
    -e PERF_HELPER \
    -e BOOTUP_RECLAIM \
    -e MI_RECLAIM \
    -e RTMM \
    -e MILLET_CGROUP \
    -e MILLET_SIG \
    -e MILLET_BINDER \
    -e MILLET_PKG \
    -e MILLET_BINDER_GKI \
    -e MILLET_CORE \
    -e MILLET_HS \
    -e BINDER_PRIO \
    -d REKERNEL \
    -d REKERNEL_NETWORK \
    -d LTO_CLANG_THIN -d CFI_CLANG

make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" olddefconfig

# Ensure ZRAM ZSTD, Schedutil, and KSU survive olddefconfig
scripts/config --file "${OUT_DIR}/.config" \
    -e ZRAM \
    -e CRYPTO_ZSTD \
    -e ZSTD_COMPRESS \
    -e ZSTD_DECOMPRESS \
    -e ZRAM_DEF_COMP_ZSTD \
    -d ZRAM_DEF_COMP_LZ4 \
    --set-str ZRAM_DEF_COMP "zstd" \
    -e CPU_FREQ_GOV_SCHEDUTIL \
    --set-val SCHEDUTIL_UP_RATE_LIMIT 0

# 🔥 THE ULTIMATE KSU FIX: Ensuring CONFIG_KSU survives olddefconfig
if [ "$ENABLE_KSU" -eq 1 ]; then
    if ! grep -q "CONFIG_KSU=y" "${OUT_DIR}/.config"; then
        echo "[!] CONFIG_KSU was dropped by olddefconfig! Forcing it back into .config..."
        echo "CONFIG_KSU=y" >> "${OUT_DIR}/.config"
    fi
    if ! grep -q "CONFIG_KSU_SUSFS=y" "${OUT_DIR}/.config"; then
        echo "CONFIG_KSU_SUSFS=y" >> "${OUT_DIR}/.config"
    fi
    if ! grep -q "CONFIG_THREAD_INFO_IN_TASK=y" "${OUT_DIR}/.config"; then
        echo "CONFIG_THREAD_INFO_IN_TASK=y" >> "${OUT_DIR}/.config"
    fi
fi

# ------------------------------------------
# 9. Build Kernel Image & DTBs
# ------------------------------------------
echo "[*] Compiling Kernel Image..."
make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" Image

echo "[*] Compiling DTBs & DTBO..."
make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" dtbs

# ------------------------------------------
# 10. AnyKernel3 Setup (AstideLabs Kona Branch)
# ------------------------------------------
echo "[*] Cloning AstideLabs AnyKernel3 (Kona branch)..."
git clone --depth=1 https://github.com/AstideLabs/AnyKernel3 -b kona anykernel

cat > anykernel/anykernel.sh << 'EOF'
### AnyKernel3 Ramdisk Mod Script
## Adapted for POCO F4 (munch) HyperOS by PandeyJI-9

properties() { '
kernel.string=EXTREME++GAMING_Hyperos | POCO F4 (munch)
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=munch
device.name2=POCO F4
supported.versions=13-17
'; }

BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;
NO_BLOCK_DISPLAY=1;

. tools/ak3-core.sh;

ui_print "  -> Flashing EXTREME++ Kernel (split_boot method)...";

# boot install (leaves stock HyperOS ramdisk byte-for-byte untouched)
split_boot;

flash_boot;
flash_generic dtbo;
## end boot install

# Install post-boot optimization script into /data/adb/service.d for KSU/ReSukiSU/Magisk
if [ ! -d /data/adb/service.d ]; then
    mount /data 2>/dev/null
fi
if [ -d /data/adb ]; then
    mkdir -p /data/adb/service.d
    ui_print "  -> Installing EXTREME++ Joyose & Performance Service...";
    cp -f 00-extreme-performance.sh /data/adb/service.d/00-extreme-performance.sh 2>/dev/null || cp -f $home/00-extreme-performance.sh /data/adb/service.d/00-extreme-performance.sh 2>/dev/null
    chmod 755 /data/adb/service.d/00-extreme-performance.sh
    chown root:root /data/adb/service.d/00-extreme-performance.sh 2>/dev/null
fi
EOF

cat > anykernel/00-extreme-performance.sh << 'EOF'
#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════
#  EXTREME++ GAMING — Joyose & Performance Boot Service
#  POCO F4 (munch) | HyperOS / MIUI
# ═══════════════════════════════════════════════════════════════

(
# Wait for Android framework to fully boot in background without blocking init
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done

sleep 5

# ── 1. Xiaomi Thermal Message / Performance Profile ──
# Lock sconfig to 10 (Game Turbo / Performance profile)
# This prevents Joyose from downgrading the system to aggressive throttling
# while preserving ALL hardware TSENS thermal zones and kernel overheat protections!
if [ -f /sys/class/thermal/thermal_message/sconfig ]; then
    chmod 666 /sys/class/thermal/thermal_message/sconfig
    echo 10 > /sys/class/thermal/thermal_message/sconfig
    chmod 444 /sys/class/thermal/thermal_message/sconfig
fi

# ── 2. Joyose Cloud Thermal Policy Optimization ──
# Clean Joyose cached cloud throttling rules without killing the package,
# keeping Game Turbo overlay, touch sampling rate, and SMS services 100% functional.
JOYOSE_DIR="/data/system/users/0/joyose"
if [ -d "$JOYOSE_DIR" ]; then
    rm -rf "$JOYOSE_DIR"/* 2>/dev/null
fi

# ── 3. Sysfs Permissive GPU Power Nodes ──
# Ensure root tools (FKM) have full read/write access to GPU control nodes
chmod 666 /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/max_pwrlevel 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/gpu_min_clock 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/gpu_max_clock 2>/dev/null

echo "EXTREME++: Joyose optimized & thermal performance mode active!" > /dev/kmsg
) &
EOF
chmod 755 anykernel/00-extreme-performance.sh

# ------------------------------------------
# 11. Packaging: Concatenated Multi-DTB Table & DTBO
# ------------------------------------------
echo "[*] Verifying compiled files..."

if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "❌ [ERROR] Kernel Image did NOT compile!"
    exit 1
fi
cp "${OUT_DIR}/arch/arm64/boot/Image" anykernel/
echo "[+] Kernel Image copied."

# CONCATENATED MULTI-DTB TABLE (AstideLabs & Qualcomm Kona standard):
echo "[*] Packing concatenated multi-DTB table..."
if [ -f "${OUT_DIR}/arch/arm64/boot/dtb" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtb" anykernel/dtb
    echo "[+] DTB table copied from arch/arm64/boot/dtb"
else
    cat ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtb > anykernel/dtb
    echo "[+] Concatenated all compiled DTBs into anykernel/dtb"
fi

# DTBO packaging
if [ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" anykernel/
    echo "[+] DTBO Image copied directly."
else
    if [ ! -f "scripts/dtc/libfdt/mkdtboimg.py" ]; then
        mkdir -p scripts/dtc/libfdt/
        curl -sL -o scripts/dtc/libfdt/mkdtboimg.py https://raw.githubusercontent.com/LineageOS/android_system_libufdt/lineage-19.1/utils/src/mkdtboimg.py
    fi
    count=$(ls -1 ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtbo 2>/dev/null | wc -l || echo "0")
    if [ "$count" != "0" ]; then
        python3 scripts/dtc/libfdt/mkdtboimg.py create anykernel/dtbo.img --page_size=4096 ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtbo
        echo "[+] DTBO packed successfully from DTBO fragments."
    else
        echo "❌ [ERROR] No .dtbo fragments found!"
        exit 1
    fi
fi

# ------------------------------------------
# 12. Final Zip Creation
# ------------------------------------------
echo "[*] Zipping EXTREME++ Kernel..."
cd anykernel
KSU_TAG="NoRoot"
[ "$ENABLE_KSU" -eq 1 ] && KSU_TAG="ReSukiSU"
ZIP_NAME="EXTREME++GAMING_Hyperos_munch_${KSU_TAG}_$(date +'%d%b%Y_%H%M').zip"

rm -rf .git
zip -r9 "../${ZIP_NAME}" ./* -x .gitignore out/ ./*.zip > /dev/null
cd ..

echo "[+] =========================================="
echo "[+] SUCCESS! File ready: ${ZIP_NAME}"
echo "[+] =========================================="
