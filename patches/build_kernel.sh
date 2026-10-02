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
CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y
CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y
CONFIG_DEVFREQ_GOV_MSM_ADRENO_TZ=y
CONFIG_QCOM_ADRENO_DEFAULT_GOVERNOR="msm-adreno-tz"
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

if [ -f "drivers/gpu/msm/kgsl_gmu.c" ]; then
    sed -i 's/num_freqs > pri_rail->num || num_freqs > MAX_GX_LEVELS/num_freqs > MAX_GX_LEVELS/' drivers/gpu/msm/kgsl_gmu.c
    echo "[+] Adjusted DCVS level bounds check in drivers/gpu/msm/kgsl_gmu.c"
fi

python3 patch_gpu_dts.py

# Inject C-Level 10-Step Power Levels & OPP into drivers/gpu/msm/adreno.c
python3 -c '
path = "drivers/gpu/msm/adreno.c"
with open(path, "r") as f:
    text = f.read()

if "adreno_enforce_extreme_10step_pwrlevels" not in text:
    if "#include <linux/pm_opp.h>" not in text:
        text = text.replace("#include <soc/qcom/scm.h>", "#include <soc/qcom/scm.h>\n#include <linux/pm_opp.h>", 1)

    enforce_func = """/* ==========================================================
 * EXTREME++ 10-Step C-Level Power Levels & OPP Injection
 * Bypasses DTBO truncation and guarantees full 150-670MHz UV
 * ========================================================== */
static void adreno_enforce_extreme_10step_pwrlevels(struct adreno_device *adreno_dev)
{
\tstruct kgsl_device *device = KGSL_DEVICE(adreno_dev);
\tstruct kgsl_pwrctrl *pwr = &device->pwrctrl;
\tstatic const struct kgsl_pwrlevel extreme_levels[11] = {
\t\t{ 670000000, 11, 11, 11, 0x802b5ffd },
\t\t{ 587000000, 11, 11, 11, 0x802b5ffd },
\t\t{ 525000000,  9,  9, 11, 0x802b5ffd },
\t\t{ 490000000,  9,  6,  9, 0xa02b5ffd },
\t\t{ 441600000,  9,  6,  9, 0xa02b5ffd },
\t\t{ 400000000,  7,  6,  9, 0xa02b5ffd },
\t\t{ 305000000,  3,  2,  9, 0 },
\t\t{ 250000000,  3,  2,  9, 0 },
\t\t{ 200000000,  2,  1,  3, 0 },
\t\t{ 150000000,  2,  1,  3, 0 },
\t\t{         0,  0,  0,  0, 0 },
\t};

\tmemcpy(pwr->pwrlevels, extreme_levels, sizeof(extreme_levels));
\tpwr->num_pwrlevels = 11;
\tpwr->active_pwrlevel = 6;
\tpwr->default_pwrlevel = 6;
\tpwr->max_pwrlevel = 0;
\tpwr->min_pwrlevel = 9;
\tpwr->thermal_pwrlevel = 0;
\tpwr->thermal_pwrlevel_floor = 9;

\t/* Register all 10 OPP frequencies with RPMh voltages */
\tdev_pm_opp_add(&device->pdev->dev, 670000000, 224);
\tdev_pm_opp_add(&device->pdev->dev, 587000000, 192);
\tdev_pm_opp_add(&device->pdev->dev, 525000000, 128);
\tdev_pm_opp_add(&device->pdev->dev, 490000000, 128);
\tdev_pm_opp_add(&device->pdev->dev, 441600000, 64);
\tdev_pm_opp_add(&device->pdev->dev, 400000000, 64);
\tdev_pm_opp_add(&device->pdev->dev, 305000000, 48);
\tdev_pm_opp_add(&device->pdev->dev, 250000000, 48);
\tdev_pm_opp_add(&device->pdev->dev, 200000000, 48);
\tdev_pm_opp_add(&device->pdev->dev, 150000000, 48);
}

"""
    target = "static int adreno_of_get_legacy_pwrlevels("
    text = text.replace(target, enforce_func + target, 1)

    target_legacy = "\tadreno_of_get_bimc_iface_clk(adreno_dev, parent);\n\n\treturn 0;"
    patch_legacy = "\tadreno_of_get_bimc_iface_clk(adreno_dev, parent);\n\tadreno_enforce_extreme_10step_pwrlevels(adreno_dev);\n\n\treturn 0;"
    text = text.replace(target_legacy, patch_legacy, 1)

    target_pwr = "\t\t\tadreno_of_get_limits(adreno_dev, parent);\n\t\t\tadreno_of_get_limits(adreno_dev, child);\n\n\t\t\treturn 0;"
    patch_pwr = "\t\t\tadreno_of_get_limits(adreno_dev, parent);\n\t\t\tadreno_of_get_limits(adreno_dev, child);\n\t\t\tadreno_enforce_extreme_10step_pwrlevels(adreno_dev);\n\n\t\t\treturn 0;"
    text = text.replace(target_pwr, patch_pwr, 1)

    target_probe = "if (adreno_of_get_pwrlevels(adreno_dev, node))\n\t\treturn -EINVAL;"
    patch_probe = "if (adreno_of_get_pwrlevels(adreno_dev, node))\n\t\treturn -EINVAL;\n\tadreno_enforce_extreme_10step_pwrlevels(adreno_dev);"
    text = text.replace(target_probe, patch_probe, 1)

    with open(path, "w") as f:
        f.write(text)
    print("✅ drivers/gpu/msm/adreno.c: Injected 10-Step C-Level Power Levels & OPP Table override!")
else:
    print("ℹ️ drivers/gpu/msm/adreno.c already has 10-step enforcement")
'


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
# 🚀 Restore Adreno TrustZone GPU Devfreq Governor & Bus Monitor
scripts/config --file "${OUT_DIR}/.config" \
    -e DEVFREQ_GOV_QCOM_ADRENO_TZ \
    -e DEVFREQ_GOV_QCOM_GPUBW_MON \
    -e DEVFREQ_GOV_MSM_ADRENO_TZ \
    --set-str QCOM_ADRENO_DEFAULT_GOVERNOR "msm-adreno-tz"

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

# Ensure GPU Devfreq Governor, ZRAM ZSTD, Schedutil, and KSU survive olddefconfig
scripts/config --file "${OUT_DIR}/.config" \
    -e DEVFREQ_GOV_QCOM_ADRENO_TZ \
    -e DEVFREQ_GOV_QCOM_GPUBW_MON \
    -e DEVFREQ_GOV_MSM_ADRENO_TZ \
    --set-str QCOM_ADRENO_DEFAULT_GOVERNOR "msm-adreno-tz"

if ! grep -q "CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y" "${OUT_DIR}/.config"; then
    echo "CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y" >> "${OUT_DIR}/.config"
fi
if ! grep -q "CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y" "${OUT_DIR}/.config"; then
    echo "CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y" >> "${OUT_DIR}/.config"
fi
if ! grep -q "CONFIG_DEVFREQ_GOV_MSM_ADRENO_TZ=y" "${OUT_DIR}/.config"; then
    echo "CONFIG_DEVFREQ_GOV_MSM_ADRENO_TZ=y" >> "${OUT_DIR}/.config"
fi
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

# Direct block flashing fallback for dtbo if flashed via FKM / automated app flashers
if [ -f dtbo.img ]; then
    for dtbo_node in /dev/block/bootdevice/by-name/dtbo /dev/block/bootdevice/by-name/dtbo_a /dev/block/bootdevice/by-name/dtbo_b /dev/block/by-name/dtbo /dev/block/by-name/dtbo_a /dev/block/by-name/dtbo_b; do
        if [ -b "$dtbo_node" ]; then
            dd if=dtbo.img of="$dtbo_node" bs=4096 2>/dev/null || true
        fi
    done
fi
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
chmod 444 /sys/class/kgsl/kgsl-3d0/gpubusy 2>/dev/null
chmod 444 /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage 2>/dev/null

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
