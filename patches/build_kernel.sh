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

# ZRAM ZSTD, EXTREME+ Governor & GPU Devfreq defconfig tunables
sed -i 's/CONFIG_ZRAM_DEF_COMP_LZ4=y/CONFIG_ZRAM_DEF_COMP_ZSTD=y/' "arch/arm64/configs/${DEFCONFIG}"
grep -q "CONFIG_CRYPTO_ZSTD=y" "arch/arm64/configs/${DEFCONFIG}" || cat >> "arch/arm64/configs/${DEFCONFIG}" << 'EOF'
CONFIG_CRYPTO_ZSTD=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_ZRAM_DEF_COMP="zstd"
CONFIG_SCHEDUTIL_UP_RATE_LIMIT=0
CONFIG_PM_DEVFREQ=y
CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y
CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y
CONFIG_QCOM_ADRENO_DEFAULT_GOVERNOR="msm-adreno-tz"
CONFIG_QCOM_KGSL=y
CONFIG_CPU_FREQ_GOV_EXTREME_PLUS=y
CONFIG_CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS=y
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
# 4. 100% Pure FakeDreamer Adreno 650 Undervolt & Frequency Table
# Source: re-noroi/kernel_sm8250 (freesia/stable) commit 41ac7f89
# ------------------------------------------
echo "[*] Applying 100% Native FakeDreamer GPU Undervolt (150MHz - 670MHz) & Speed Bins..."

# Pure DTS Injection: Replace kona-v2-gpu.dtsi directly with FakeDreamer source
if [ -f "kona-v2-gpu.dtsi" ]; then
    cp -f kona-v2-gpu.dtsi arch/arm64/boot/dts/vendor/qcom/kona-v2-gpu.dtsi
    echo "[+] Copied FakeDreamer kona-v2-gpu.dtsi into kernel tree"
fi

# Ensure kona-v2.1-gpu.dtsi is stock FakeDreamer (cleanly inherits kona-v2-gpu.dtsi)
cat > arch/arm64/boot/dts/vendor/qcom/kona-v2.1-gpu.dtsi << 'EOF'
&msm_gpu {
	qcom,chipid = <0x06050002>;
};
EOF
echo "[+] kona-v2.1-gpu.dtsi set to pure FakeDreamer chipid override"



# ------------------------------------------
# 4b. Inject Custom EXTREME+ Governor (Zero-Latency & Anti-Choke)
# ------------------------------------------
echo "[*] Injecting Custom EXTREME+ Governor into kernel/sched/..."
if [ -f "cpufreq_extreme_plus.c" ]; then
    cp -f cpufreq_extreme_plus.c kernel/sched/cpufreq_extreme_plus.c
    echo "[+] Copied cpufreq_extreme_plus.c to kernel/sched/"
fi

if ! grep -q "cpufreq_extreme_plus.o" kernel/sched/Makefile; then
    echo 'obj-$(CONFIG_CPU_FREQ_GOV_EXTREME_PLUS) += cpufreq_extreme_plus.o' >> kernel/sched/Makefile
    echo "[+] Hooked cpufreq_extreme_plus.o into kernel/sched/Makefile"
fi

python3 -c '
path_kconfig = "drivers/cpufreq/Kconfig"
with open(path_kconfig, "r") as f:
    text = f.read()

gov_choice = """config CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS
\tbool "extreme_plus"
\tdepends on SMP
\tselect CPU_FREQ_GOV_EXTREME_PLUS
\tselect CPU_FREQ_GOV_PERFORMANCE
\thelp
\t  Use the "extreme_plus" CPUFreq governor by default. Zero latency,
\t  anti-100% prime choke, aggressive decay to idle for sustained hardcore gaming.
"""

gov_def = """config CPU_FREQ_GOV_EXTREME_PLUS
\tbool "\x27extreme_plus\x27 cpufreq policy governor"
\tdepends on CPU_FREQ && SMP
\tselect CPU_FREQ_GOV_ATTR_SET
\tselect IRQ_WORK
\thelp
\t  EXTREME+ governor based on scheduler utilization with zero latency
\t  up-scaling and aggressive decay to idle for sustained hardcore gaming.
"""

if "CPU_FREQ_GOV_EXTREME_PLUS" not in text:
    text = text.replace("config CPU_FREQ_DEFAULT_GOV_SCHEDUTIL", gov_choice + "\nconfig CPU_FREQ_DEFAULT_GOV_SCHEDUTIL")
    text = text.replace("config CPU_FREQ_GOV_SCHEDUTIL", gov_def + "\nconfig CPU_FREQ_GOV_SCHEDUTIL")
    with open(path_kconfig, "w") as f:
        f.write(text)
    print("✅ Injected EXTREME+ governor definitions into drivers/cpufreq/Kconfig")
else:
    print("ℹ️ EXTREME+ governor already in drivers/cpufreq/Kconfig")
'

# ------------------------------------------
# 5. Native CPU Peak Cap (2.84 GHz) & Safe Undervolt (-30mV offset)
# ------------------------------------------
echo "[*] Natively Applying CPU Peak Cap (2.84 GHz) & Safe Undervolt (-30mV offset)..."
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

# 2. Patch drivers/cpufreq/qcom-cpufreq-hw.c (C89 compliant, UV + Max Cap)
path_driver = "drivers/cpufreq/qcom-cpufreq-hw.c"
with open(path_driver, "r") as f:
    text_driver = f.read()

if "max_freq_cap" not in text_driver:
    target_decl = "\tu32 vc;\n\tunsigned long cpu;"
    patch_decl = "\tu32 vc, max_freq_cap = 0, raw_volt, new_raw_volt, new_reg;\n\tunsigned long cpu;"
    text_driver = text_driver.replace(target_decl, patch_decl, 1)

    target_read = "spin_lock_init(&c->skip_data.lock);"
    patch_read = """spin_lock_init(&c->skip_data.lock);
\tof_property_read_u32(dev->of_node, "qcom,freq-domain-max-freq", &max_freq_cap);
\tif (!max_freq_cap)
\t\tmax_freq_cap = 2841600;"""
    text_driver = text_driver.replace(target_read, patch_read, 1)

    target_volt = """\t\tdata = readl_relaxed(base_volt + i * lut_row_size);
\t\tvolt = (data & GENMASK(11, 0)) * 1000;
\t\tvc = data & GENMASK(21, 16);"""

    patch_volt = """\t\tdata = readl_relaxed(base_volt + i * lut_row_size);
\t\traw_volt = data & GENMASK(11, 0);
\t\tif (raw_volt > 650) {
\t\t\tnew_raw_volt = raw_volt - 30; /* EXTREME+: -30mV safe CPU undervolt */
\t\t\tnew_reg = (data & ~GENMASK(11, 0)) | (new_raw_volt & GENMASK(11, 0));
\t\t\twritel_relaxed(new_reg, base_volt + i * lut_row_size);
\t\t\tvolt = new_raw_volt * 1000;
\t\t} else {
\t\t\tvolt = raw_volt * 1000;
\t\t}
\t\tvc = data & GENMASK(21, 16);"""
    text_driver = text_driver.replace(target_volt, patch_volt, 1)

    target_break = "dev_dbg(dev, \"index=%d freq=%d, core_count %d\\n\","
    patch_break = """if (max_freq_cap && c->table[i].frequency > max_freq_cap) {
\t\t\tbreak;
\t\t}
\t\tdev_dbg(dev, \"index=%d freq=%d, core_count %d\\n\","""
    text_driver = text_driver.replace(target_break, patch_break, 1)

    with open(path_driver, "w") as f:
        f.write(text_driver)
    print("✅ qcom-cpufreq-hw driver patched (C89 compliant) with 2.84 GHz cap & -30mV CPU undervolt")
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
    -e PM_DEVFREQ \
    -e DEVFREQ_GOV_SIMPLE_ONDEMAND \
    -e DEVFREQ_GOV_PERFORMANCE \
    -e DEVFREQ_GOV_POWERSAVE \
    -e DEVFREQ_GOV_USERSPACE \
    -e DEVFREQ_GOV_PASSIVE \
    -e DEVFREQ_GOV_QCOM_ADRENO_TZ \
    -e DEVFREQ_GOV_QCOM_GPUBW_MON \
    -e QCOM_KGSL \
    -e QCOM_KGSL_IOMMU \
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

# 🚀 Custom EXTREME+ Governor (Zero Latency & Anti-Choke)
scripts/config --file "${OUT_DIR}/.config" \
    -e CPU_FREQ_GOV_EXTREME_PLUS \
    -e CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS \
    --set-str CPU_FREQ_DEFAULT_GOV "extreme_plus"

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
    -e PM_DEVFREQ \
    -e DEVFREQ_GOV_QCOM_ADRENO_TZ \
    -e DEVFREQ_GOV_QCOM_GPUBW_MON \
    -e QCOM_KGSL \
    --set-str QCOM_ADRENO_DEFAULT_GOVERNOR "msm-adreno-tz"

if ! grep -q "CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y" "${OUT_DIR}/.config"; then
    echo "CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y" >> "${OUT_DIR}/.config"
fi
if ! grep -q "CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y" "${OUT_DIR}/.config"; then
    echo "CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y" >> "${OUT_DIR}/.config"
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
    --set-val SCHEDUTIL_UP_RATE_LIMIT 0 \
    -e CPU_FREQ_GOV_EXTREME_PLUS \
    -e CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS \
    --set-str CPU_FREQ_DEFAULT_GOV "extreme_plus"

if ! grep -q "CONFIG_CPU_FREQ_GOV_EXTREME_PLUS=y" "${OUT_DIR}/.config"; then
    echo "CONFIG_CPU_FREQ_GOV_EXTREME_PLUS=y" >> "${OUT_DIR}/.config"
fi
if ! grep -q "CONFIG_CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS=y" "${OUT_DIR}/.config"; then
    echo "CONFIG_CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS=y" >> "${OUT_DIR}/.config"
fi

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
echo "[*] Compiling Kernel Image, DTBs, DTBO & Multi-DTB Image..."
make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" Image dtbs dtbo.img dtb

# ------------------------------------------
# 10. AnyKernel3 Setup (FakeDreamer Munch Branch with Fallback)
# ------------------------------------------
echo "[*] Cloning AnyKernel3 (Munch branch)..."
if ! git clone --depth=1 https://github.com/re-noroi/anykernel3-test -b munch anykernel; then
    echo "[!] Fallback to AstideLabs AnyKernel3..."
    git clone --depth=1 https://github.com/AstideLabs/AnyKernel3 -b kona anykernel
fi

cat > anykernel/anykernel.sh << 'EOF'
### AnyKernel3 Ramdisk Mod Script
## EXTREME++ HyperOS Kernel for POCO F4 (munch) by PandeyJI-9

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

# shell variables
block=/dev/block/bootdevice/by-name/boot;
BLOCK=boot;
is_slot_device=1;
IS_SLOT_DEVICE=auto;
ramdisk_compression=auto;
RAMDISK_COMPRESSION=auto;
patch_vbmeta_flag=auto;
PATCH_VBMETA_FLAG=auto;
no_block_display=1;
NO_BLOCK_DISPLAY=1;

. tools/ak3-core.sh;

ui_print " ";
ui_print "  -> Flashing EXTREME++ Kernel (boot)...";
dump_boot;
write_boot;

ui_print "  -> Flashing EXTREME++ Undervolted DTB (vendor_boot)...";
block=/dev/block/bootdevice/by-name/vendor_boot;
BLOCK=vendor_boot;
is_slot_device=1;
IS_SLOT_DEVICE=auto;
ramdisk_compression=auto;
RAMDISK_COMPRESSION=auto;
patch_vbmeta_flag=auto;
PATCH_VBMETA_FLAG=auto;
no_block_display=1;
NO_BLOCK_DISPLAY=1;

reset_ak;
dump_boot;
write_boot;

ui_print "  -> Flashing EXTREME++ DTBO Partition...";
flash_generic dtbo;

# Direct block flashing fallback for dtbo and dtb (all slot nodes)
if [ -f dtbo.img ]; then
    for dtbo_node in /dev/block/bootdevice/by-name/dtbo /dev/block/bootdevice/by-name/dtbo_a /dev/block/bootdevice/by-name/dtbo_b /dev/block/by-name/dtbo /dev/block/by-name/dtbo_a /dev/block/by-name/dtbo_b; do
        if [ -b "$dtbo_node" ]; then
            dd if=dtbo.img of="$dtbo_node" bs=4096 2>/dev/null || true
        fi
    done
fi

if [ -f dtb ]; then
    for dtb_node in /dev/block/bootdevice/by-name/dtb /dev/block/bootdevice/by-name/dtb_a /dev/block/bootdevice/by-name/dtb_b /dev/block/by-name/dtb /dev/block/by-name/dtb_a /dev/block/by-name/dtb_b; do
        if [ -b "$dtb_node" ]; then
            dd if=dtb of="$dtb_node" bs=4096 2>/dev/null || true
        fi
    done
fi

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
#  PROJECT EXTREME+ — Joyose, Governor & Sniper Boot Service
#  POCO F4 (munch / SM8250-AC Kona) | HyperOS ONLY
# ═══════════════════════════════════════════════════════════════

(
# Wait for Android framework to fully boot in background without blocking init
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done

sleep 5

# ── 1. Custom EXTREME+ Governor Activation & Core Tuning ──
# Set EXTREME+ governor across all CPU clusters (Silver, Gold, Prime)
for pol in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -d "$pol" ]; then
        chmod 666 "$pol/scaling_governor" 2>/dev/null
        echo "extreme_plus" > "$pol/scaling_governor" 2>/dev/null || echo "schedutil" > "$pol/scaling_governor" 2>/dev/null
    fi
done

# Tune EXTREME+ tunables: Zero latency ramp-up, fast decay to idle
for gov_path in /sys/devices/system/cpu/cpufreq/policy*/extreme_plus; do
    if [ -d "$gov_path" ]; then
        echo 0 > "$gov_path/up_rate_limit_us" 2>/dev/null
        echo 20000 > "$gov_path/down_rate_limit_us" 2>/dev/null
        echo 75 > "$gov_path/hispeed_load" 2>/dev/null
    fi
done

# ── 2. EAS Anti-100% Choke & Spillover Margins (WALT Migration) ──
# Thresholds: Spill from Prime (core 7) to Gold (cores 4-6) at 75-80% load
echo 75 80 > /proc/sys/kernel/sched_upmigrate 2>/dev/null
echo 60 70 > /proc/sys/kernel/sched_downmigrate 2>/dev/null
echo 75 > /proc/sys/kernel/sched_group_upmigrate 2>/dev/null
echo 60 > /proc/sys/kernel/sched_group_downmigrate 2>/dev/null

# ── 3. Smart Multitasking & ZRAM ZSTD Tuning (No App Kills) ──
echo 100 > /proc/sys/vm/swappiness 2>/dev/null
echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
echo 20 > /proc/sys/vm/dirty_ratio 2>/dev/null
echo 10 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
echo 50 > /proc/sys/vm/watermark_scale_factor 2>/dev/null
echo 0 > /proc/sys/vm/page-cluster 2>/dev/null
echo 750 > /proc/sys/vm/extfrag_threshold 2>/dev/null

# ── 4. Android LMKD Sniper Policy (Protect Foreground & Multitasking) ──
setprop sys.lmk.kill_heaviest_task false 2>/dev/null
setprop sys.lmk.kill_timeout_ms 100 2>/dev/null
setprop sys.lmk.thrashing_limit 50 2>/dev/null
setprop sys.lmk.minfree_levels "18432,23040,27648,32256,55296,80640" 2>/dev/null

# ── 5. Xiaomi Thermal Message / Performance Profile ──
# Lock sconfig to 10 (Game Turbo / Performance profile)
# This prevents Joyose from downgrading the system to aggressive throttling
# while preserving ALL hardware TSENS thermal zones and kernel overheat protections!
if [ -f /sys/class/thermal/thermal_message/sconfig ]; then
    chmod 666 /sys/class/thermal/thermal_message/sconfig
    echo 10 > /sys/class/thermal/thermal_message/sconfig
    chmod 444 /sys/class/thermal/thermal_message/sconfig
fi

# ── 6. Joyose Cloud Thermal Policy Optimization ──
# Clean Joyose cached cloud throttling rules without killing the package,
# keeping Game Turbo overlay, touch sampling rate, and SMS services 100% functional.
JOYOSE_DIR="/data/system/users/0/joyose"
if [ -d "$JOYOSE_DIR" ]; then
    rm -rf "$JOYOSE_DIR"/* 2>/dev/null
fi

# ── 7. Sysfs Permissive GPU Power Nodes & Adreno Governor Lock ──
# Ensure root tools (FKM) have full read/write access to GPU control nodes
chmod 666 /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/max_pwrlevel 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/gpu_min_clock 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/gpu_max_clock 2>/dev/null
chmod 444 /sys/class/kgsl/kgsl-3d0/gpubusy 2>/dev/null
chmod 444 /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage 2>/dev/null

if [ -f /sys/class/kgsl/kgsl-3d0/devfreq/governor ]; then
    chmod 666 /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null || true
fi

echo "PROJECT EXTREME+: Governor active, CPU UV (-30mV) & Joyose optimized!" > /dev/kmsg

# ── 8. Smart LMK Sniper Daemon (Continuous Background Protection) ──
(
while true; do
    sleep 45

    # A. Whitelist: Protect critical apps (Games, Music, Messaging)
    for pkg in \
        com.pubg.imobile \
        com.tencent.ig \
        com.activision.callofduty.shooter \
        com.miHoYo.GenshinImpact \
        com.dts.freefireth \
        com.spotify.music \
        com.google.android.apps.youtube.music \
        com.apple.android.music \
        com.amazon.mp3 \
        com.whatsapp \
        org.telegram.messenger \
        org.thunderdog.challegram \
        com.discord; do
        for pid in $(pidof "$pkg" 2>/dev/null); do
            if [ -n "$pid" ] && [ -f "/proc/$pid/oom_score_adj" ]; then
                echo -900 > "/proc/$pid/oom_score_adj" 2>/dev/null
            fi
        done
    done

    # B. Sniper Target Bloat when RAM pressure > 90%
    MEM_TOTAL=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    MEM_AVAIL=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -n "$MEM_TOTAL" ] && [ -n "$MEM_AVAIL" ] && [ "$MEM_TOTAL" -gt 0 ]; then
        MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
        MEM_USED_PCT=$(( (MEM_USED * 100) / MEM_TOTAL ))
        if [ "$MEM_USED_PCT" -ge 90 ]; then
            # Snipe strictly background bloatware, analytics, telemetry & system ad trackers
            for bloat in \
                com.miui.analytics \
                com.miui.msa.global \
                com.miui.daemon \
                com.google.android.gms.feedback \
                com.google.android.feedback; do
                pkill -f "$bloat" 2>/dev/null || true
            done

            # If pressure is critical (>93%), compact memory without killing user apps
            if [ "$MEM_USED_PCT" -ge 93 ]; then
                echo 1 > /proc/sys/vm/compact_memory 2>/dev/null
            fi
        fi
    fi
done
) &

) &
EOF
chmod 755 anykernel/00-extreme-performance.sh

# ------------------------------------------
# 11. Packaging: Multi-DTB Table & DTBO
# ------------------------------------------
echo "[*] Verifying compiled files..."

if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "❌ [ERROR] Kernel Image did NOT compile!"
    exit 1
fi
cp "${OUT_DIR}/arch/arm64/boot/Image" anykernel/
echo "[+] Kernel Image copied."

# MULTI-DTB TABLE (AstideLabs & Qualcomm Kona standard):
echo "[*] Packing multi-DTB table..."
if [ -f "${OUT_DIR}/arch/arm64/boot/dtb" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtb" anykernel/dtb
    echo "[+] DTB table copied from arch/arm64/boot/dtb"
elif [ -f "${OUT_DIR}/arch/arm64/boot/dtb.img" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtb.img" anykernel/dtb
    echo "[+] DTB table copied from arch/arm64/boot/dtb.img"
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
