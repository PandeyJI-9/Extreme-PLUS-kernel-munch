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

if [ "$2" == "ksu" ] || [ "$2" == "true" ] || [ "$2" == "1" ]; then
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
CONFIG_SCHEDUTIL_UP_RATE_LIMIT=500
CONFIG_WQ_POWER_EFFICIENT=y
CONFIG_WQ_POWER_EFFICIENT_DEFAULT=y
CONFIG_PM_DEVFREQ=y
CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y
CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y
CONFIG_QCOM_ADRENO_DEFAULT_GOVERNOR="msm-adreno-tz"
CONFIG_QCOM_KGSL=y
CONFIG_CPU_FREQ_GOV_EXTREME_PLUS=y
CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_FQ_CODEL=y
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
# 3. KowSU (KOWX712/KernelSU Multi-Manager Non-GKI 4.19) Setup
# ------------------------------------------
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "[*] Injecting KowSU (KOWX712/KernelSU) Multi-Manager Source..."
    # Fetch official KowSU setup script and checkout master
    curl -LSs "https://raw.githubusercontent.com/KOWX712/KernelSU/master/kernel/setup.sh" | bash -s master

    # Apply Universal Multi-Manager Crowning & App-Profile Zero-Failure Patch
    if [ -f "apply-kowsu-fixes.py" ]; then
        python3 apply-kowsu-fixes.py
    elif [ -f "patches/apply-kowsu-fixes.py" ]; then
        python3 patches/apply-kowsu-fixes.py
    fi

    # Inject defconfig base symbols for KowSU
    echo "CONFIG_KSU=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_KPROBES=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_HAVE_KPROBES=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_KRETPROBES=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_THREAD_INFO_IN_TASK=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "[+] KowSU (KOWX712/KernelSU) Multi-Manager setup finished."
else
    echo "[*] Ensuring Pure Clean Kernel Base (Zero embedded root hooks)..."
    sed -i '/CONFIG_KSU/d' "arch/arm64/configs/${DEFCONFIG}" 2>/dev/null || true
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
\tbool "extreme+"
\tdepends on SMP
\tselect CPU_FREQ_GOV_EXTREME_PLUS
\tselect CPU_FREQ_GOV_PERFORMANCE
\thelp
\t  Use the "extreme+" CPUFreq governor by default. Zero latency,
\t  anti-100% prime choke, active frame pacing floor for sustained hardcore gaming.
"""

gov_def = """config CPU_FREQ_GOV_EXTREME_PLUS
\tbool "\x27extreme+\x27 cpufreq policy governor"
\tdepends on CPU_FREQ && SMP
\tselect CPU_FREQ_GOV_ATTR_SET
\tselect IRQ_WORK
\thelp
\t  EXTREME+ governor based on scheduler utilization with active task
\t  frame pacing floor, zero latency up-scaling, and 60ms decay window.
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

## ------------------------------------------
# 5. Display Panel DTS Configuration (100% Stock AstideLabs Preserved)
# ------------------------------------------
echo "[*] Preserving 100% Native AstideLabs Display & Panel DTS (prevents black screen)..."

# ------------------------------------------
# 6. Safe PD / PPS Fast Charging & Thermal DTS Stepping
# ------------------------------------------
if [ -f "apply-fastcharge-bypass.py" ]; then
    echo "[*] Applying safe PD/PPS Fast Charge & Thermal DTS Stepping patches..."
    python3 apply-fastcharge-bypass.py
fi

if [ -f "apply-bootloader-spoof.py" ]; then
    echo "[*] Applying user custom patches..."
    python3 apply-bootloader-spoof.py . || true
fi

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

# 🚀 Instant Touch Reaction (Schedutil Governor 500us ramp-up)
scripts/config --file "${OUT_DIR}/.config" \
    -e CPU_FREQ_GOV_SCHEDUTIL \
    --set-val SCHEDUTIL_UP_RATE_LIMIT 500 \
    -e WQ_POWER_EFFICIENT \
    -e WQ_POWER_EFFICIENT_DEFAULT

# 🚀 Custom EXTREME+ Governor (Responsive 500us ramp-up & 20ms decay)
scripts/config --file "${OUT_DIR}/.config" \
    -e CPU_FREQ_GOV_EXTREME_PLUS \
    -d CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS \
    -e CPU_FREQ_DEFAULT_GOV_SCHEDUTIL \
    --set-str CPU_FREQ_DEFAULT_GOV "schedutil"

# Native source patches for VM & Schedutil tunables
if [ -f "kernel/sched/cpufreq_schedutil.c" ]; then
    sed -i 's/tunables->up_rate_limit_us = CONFIG_SCHEDUTIL_UP_RATE_LIMIT;/tunables->up_rate_limit_us = 500;/' kernel/sched/cpufreq_schedutil.c
    echo "[+] Schedutil up_rate_limit_us tuned to 500us in kernel/sched/cpufreq_schedutil.c"
fi
if [ -f "drivers/cpufreq/cpufreq_schedutil.c" ]; then
    sed -i 's/tunables->up_rate_limit_us = CONFIG_SCHEDUTIL_UP_RATE_LIMIT;/tunables->up_rate_limit_us = 500;/' drivers/cpufreq/cpufreq_schedutil.c
    echo "[+] Schedutil up_rate_limit_us tuned to 500us in drivers/cpufreq/cpufreq_schedutil.c"
fi
if [ -f "mm/vmscan.c" ]; then
    echo "[+] Preserving balanced OEM vm_swappiness = 60 in mm/vmscan.c"
fi
if [ -f "fs/dcache.c" ]; then
    sed -i 's/int sysctl_vfs_cache_pressure __read_mostly = [0-9]*;/int sysctl_vfs_cache_pressure __read_mostly = 100;/' fs/dcache.c
    echo "[+] Optimized sysctl_vfs_cache_pressure to 100 in fs/dcache.c"
fi

# 🚀 Full Xiaomi HyperOS / MIUI Kernel Subsystems
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

# 🚀 TCP BBR Congestion Control & Lightweight Gaming Tunables (Disable I/O Stats & Debugging)
scripts/config --file "${OUT_DIR}/.config" \
    -e TCP_CONG_BBR \
    -e DEFAULT_BBR \
    --set-str DEFAULT_TCP_CONG "bbr" \
    -e NET_SCH_FQ \
    -e NET_SCH_FQ_CODEL \
    -d TASK_IO_ACCOUNTING \
    -d BLK_DEV_IO_TRACE \
    -d SCHEDSTATS \
    -d PROVE_LOCKING \
    -d LOCKDEP \
    -d LOCK_STAT \
    -d DEBUG_KMEMLEAK \
    -d DEBUG_PREEMPT

# 🚀 Root Configuration: KowSU Multi-Manager vs Pure Clean Base
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "[*] Injecting Full KowSU Multi-Manager Configuration into .config..."
    scripts/config --file "${OUT_DIR}/.config" \
        -e KSU \
        -e KPROBES \
        -e HAVE_KPROBES \
        -e KRETPROBES \
        -e HAVE_SYSCALL_TRACEPOINTS \
        -e THREAD_INFO_IN_TASK \
        -d KSU_DISABLE_MANAGER \
        -d KSU_DISABLE_POLICY
else
    echo "[*] Disabling embedded KSU for Pure Clean Kernel..."
    scripts/config --file "${OUT_DIR}/.config" \
        -d KSU
    sed -i '/CONFIG_KSU/d' "${OUT_DIR}/.config" 2>/dev/null || true
fi

echo "[*] Synchronizing final kernel config with olddefconfig..."
make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" olddefconfig

# ------------------------------------------
# 9. Multi-Variant Architecture & AnyKernel3 Preparation
# ------------------------------------------
TARGET_VARIANT="${3:-all}"
VARIANTS_TO_BUILD=()
case "${TARGET_VARIANT,,}" in
    battery|2.5ghz|2.5|2.4ghz|2.4)
        VARIANTS_TO_BUILD=("Battery")
        ;;
    bal-gaming|bal_gaming|balanced|2.8ghz|2.8)
        VARIANTS_TO_BUILD=("Bal-Gaming")
        ;;
    gaming|3.2ghz|3.2)
        VARIANTS_TO_BUILD=("Gaming")
        ;;
    all|both|*)
        VARIANTS_TO_BUILD=("Battery" "Bal-Gaming" "Gaming")
        ;;
esac

echo "[*] Selected Target Variant(s): ${VARIANTS_TO_BUILD[*]}"

# Step 9a: Compile Shared Multi-DTB Table & DTBO
echo "[*] Compiling Shared Multi-DTB Table & DTBO Image..."
make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" dtbs dtbo.img dtb

# ------------------------------------------
# 10. AnyKernel3 Setup (FakeDreamer Munch Branch with Fallback)
# ------------------------------------------
echo "[*] Cloning AnyKernel3 (Munch branch)..."
if ! git clone --depth=1 https://github.com/re-noroi/anykernel3-test -b munch anykernel; then
    echo "[!] Fallback to AstideLabs AnyKernel3..."
    git clone --depth=1 https://github.com/AstideLabs/AnyKernel3 -b kona anykernel
fi
rm -rf anykernel/.git anykernel/kernels

# Copy multi-DTB table into anykernel
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

# NOTE: Stock DTBO partition is preserved 100% untouched to ensure OEM display panel calibrations & recovery work flawlessly!
echo "[*] Skipping DTBO packaging (Stock DTBO on device is preserved)..."

# Create 00-extreme-performance.sh post-boot service
cat > anykernel/00-extreme-performance.sh << 'EOF'
#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════
#  PROJECT EXTREME++ — Joyose, Governor & Sniper Boot Service
#  POCO F4 (munch / SM8250-AC Kona) | HyperOS ONLY
# ═══════════════════════════════════════════════════════════════

(
# Wait for Android framework to fully complete boot in background without blocking init
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# Extra settling delay to ensure all critical system daemons have initialized
sleep 15

# ── 0. Post-Boot Bootloader Lock Property Spoofing (Zero Bootloop, 100% Locked) ──
# Android has fully booted! AVB verification and partition mounting are 100% complete.
# Now spoof system properties to locked/green so Play Integrity, Key Attestation & banking apps report locked!
for rp in resetprop /data/adb/ksu/bin/ksud /data/adb/ksud; do
    if command -v resetprop >/dev/null 2>&1; then
        resetprop -n ro.boot.verifiedbootstate green 2>/dev/null || true
        resetprop -n ro.boot.vbmeta.device_state locked 2>/dev/null || true
        resetprop -n ro.boot.flash.locked 1 2>/dev/null || true
        resetprop -n ro.boot.bootloader.locked 1 2>/dev/null || true
        resetprop -n sys.oem_unlock_allowed 0 2>/dev/null || true
        resetprop -n ro.secureboot.lockstate locked 2>/dev/null || true
        resetprop -n ro.boot.warranty_bit 0 2>/dev/null || true
        resetprop -n ro.warranty_bit 0 2>/dev/null || true
        echo "PROJECT EXTREME+: Bootloader properties successfully spoofed to locked/green post-boot via resetprop!" > /dev/kmsg 2>/dev/null || true
        break
    elif [ -x /data/adb/ksu/bin/ksud ]; then
        /data/adb/ksu/bin/ksud resetprop -n ro.boot.verifiedbootstate green 2>/dev/null || true
        /data/adb/ksu/bin/ksud resetprop -n ro.boot.vbmeta.device_state locked 2>/dev/null || true
        /data/adb/ksu/bin/ksud resetprop -n ro.boot.flash.locked 1 2>/dev/null || true
        /data/adb/ksu/bin/ksud resetprop -n ro.boot.bootloader.locked 1 2>/dev/null || true
        /data/adb/ksu/bin/ksud resetprop -n sys.oem_unlock_allowed 0 2>/dev/null || true
        /data/adb/ksu/bin/ksud resetprop -n ro.secureboot.lockstate locked 2>/dev/null || true
        /data/adb/ksu/bin/ksud resetprop -n ro.boot.warranty_bit 0 2>/dev/null || true
        /data/adb/ksu/bin/ksud resetprop -n ro.warranty_bit 0 2>/dev/null || true
        echo "PROJECT EXTREME+: Bootloader properties successfully spoofed to locked/green post-boot via ksud resetprop!" > /dev/kmsg 2>/dev/null || true
        break
    elif [ -x /data/adb/ksud ]; then
        /data/adb/ksud resetprop -n ro.boot.verifiedbootstate green 2>/dev/null || true
        /data/adb/ksud resetprop -n ro.boot.vbmeta.device_state locked 2>/dev/null || true
        /data/adb/ksud resetprop -n ro.boot.flash.locked 1 2>/dev/null || true
        /data/adb/ksud resetprop -n ro.boot.bootloader.locked 1 2>/dev/null || true
        /data/adb/ksud resetprop -n sys.oem_unlock_allowed 0 2>/dev/null || true
        /data/adb/ksud resetprop -n ro.secureboot.lockstate locked 2>/dev/null || true
        /data/adb/ksud resetprop -n ro.boot.warranty_bit 0 2>/dev/null || true
        /data/adb/ksud resetprop -n ro.warranty_bit 0 2>/dev/null || true
        echo "PROJECT EXTREME+: Bootloader properties successfully spoofed to locked/green post-boot via legacy ksud resetprop!" > /dev/kmsg 2>/dev/null || true
        break
    fi
done

# ── 1. Dynamic Task Weighting (Schedtune Boost) & WALT Core Spillover ──
# Dynamic Task Weighting: Lean boost for top-app on render burst without starving audio HAL or system services
echo 5 > /dev/stune/top-app/schedtune.boost 2>/dev/null
echo 1 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
echo 5 > /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null
echo 1 > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null

# Clean Core Spillover: Keep light/background tasks on Little cores, migrate to Gold at 85%, Prime at 95%
echo "85 95" > /proc/sys/kernel/sched_upmigrate 2>/dev/null
echo "65 75" > /proc/sys/kernel/sched_downmigrate 2>/dev/null
echo 85 > /proc/sys/kernel/sched_group_upmigrate 2>/dev/null
echo 70 > /proc/sys/kernel/sched_group_downmigrate 2>/dev/null

# ── 2. Power Efficient Workqueues & Deep Sleep Suspend ──
echo Y > /sys/module/workqueue/parameters/power_efficient 2>/dev/null || true

# Schedutil & EXTREME+ Rate Limits (500us ramp-up, 20ms decay)
for gov in /sys/devices/system/cpu/cpufreq/policy*/schedutil /sys/devices/system/cpu/cpufreq/policy*/extreme+; do
    if [ -d "$gov" ]; then
        echo 500 > "$gov/up_rate_limit_us" 2>/dev/null || true
        echo 20000 > "$gov/down_rate_limit_us" 2>/dev/null || true
    fi
done

# ── 3. Smart Multitasking & ZRAM ZSTD Tuning (No App Kills, No Reclaim Thrashing) ──
echo 60 > /proc/sys/vm/swappiness 2>/dev/null
echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
echo 20 > /proc/sys/vm/dirty_ratio 2>/dev/null
echo 10 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
echo 16 > /proc/sys/vm/watermark_scale_factor 2>/dev/null
echo 0 > /proc/sys/vm/page-cluster 2>/dev/null
echo 750 > /proc/sys/vm/extfrag_threshold 2>/dev/null

# ── 4. Network & TCP BBR Congestion Control (Low Ping & Sleep Friendly) ──
echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
echo 0 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_sack 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_dsack 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null
echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null
echo "fq" > /proc/sys/net/core/default_qdisc 2>/dev/null

# ── 5. Joyose & Xiaomi Game Throttling Neutering (Pure Clean FPS) ──
# Keep mi_thermald & thermal-engine running for stock 67W Mi Turbo authentication & battery health.
# Only neutralize Joyose cloud game throttling.
setprop persist.sys.joyose.thermal.disabled 1 2>/dev/null || true

# ── 6. Storage I/O Optimization (UFS 3.1 Zero-Stutter Gaming) ──
for queue in /sys/block/*/queue; do
    if [ -d "$queue" ]; then
        echo 0 > "$queue/iostats" 2>/dev/null
        echo 128 > "$queue/read_ahead_kb" 2>/dev/null
        echo 0 > "$queue/add_random" 2>/dev/null
        echo 2 > "$queue/nomerges" 2>/dev/null
    fi
done

# ── 7. Sysfs Permissive GPU Power Nodes & Adreno Governor Lock ──
# Ensure root tools (FKM) have full read/write access to GPU control nodes
chmod 666 /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/force_bus_on 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/force_clk_on 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/gpu_min_clock 2>/dev/null
chmod 666 /sys/class/kgsl/kgsl-3d0/gpu_max_clock 2>/dev/null
chmod 444 /sys/class/kgsl/kgsl-3d0/gpubusy 2>/dev/null
chmod 444 /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage 2>/dev/null

# ── 8. CPU Freq Governor Permissions ──
chmod 666 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor 2>/dev/null
chmod 666 /sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq 2>/dev/null
chmod 666 /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq 2>/dev/null

# ── 9. Xiaomi Battery Fast Charge Unlock ──
for f in /sys/class/qcom-battery/quick_charge_type /sys/class/power_supply/battery/fastcharge_mode; do
    [ -f "$f" ] && echo 1 > "$f" 2>/dev/null
done

echo "PROJECT EXTREME++: Joyose neutralized, 67W Mi Turbo authentication preserved, GPU devfreq unlocked!" > /dev/kmsg 2>/dev/null || true

) &
EOF
chmod 755 anykernel/00-extreme-performance.sh

# ------------------------------------------
# 11. Multi-Variant Compilation & Packaging Engine
# ------------------------------------------
DATE_TAG="$(date +'%d%b%Y_%H%M')"

for VARIANT in "${VARIANTS_TO_BUILD[@]}"; do
    case "$VARIANT" in
        Battery)
            FREQ="2419200"
            LOCALVER="-Extreme++Battery-by-PandeyJi"
            TITLE="Extreme++Battery by PandeyJi | POCO F4 (munch)"
            ZIP_BASE="EXTREME++Battery"
            ;;
        Bal-Gaming)
            FREQ="2841600"
            LOCALVER="-Extreme++Bal-Gaming-by-PandeyJi"
            TITLE="Extreme++Bal-Gaming by PandeyJi | POCO F4 (munch)"
            ZIP_BASE="EXTREME++Bal-Gaming"
            ;;
        Gaming)
            FREQ="3187200"
            LOCALVER="-Extreme++Gaming-by-PandeyJi"
            TITLE="Extreme++Gaming by PandeyJi | POCO F4 (munch)"
            ZIP_BASE="EXTREME++Gaming"
            ;;
    esac

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 Building EXTREME++ Variant: ${VARIANT} (${FREQ} kHz)"
    echo "   Android Settings Kernel Display: 4.19.xxx${LOCALVER}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 1. Apply C-level hardware frequency clamp in qcom-cpufreq-hw.c & kona.dtsi
    if [ -f "apply-cpu-cap.py" ]; then
        python3 apply-cpu-cap.py "${FREQ}"
    fi

    # 2. Update CONFIG_LOCALVERSION and sync config
    scripts/config --file "${OUT_DIR}/.config" --set-str LOCALVERSION "${LOCALVER}"
    rm -f "${OUT_DIR}/include/config/kernel.release"
    make "${MAKE_OPTS[@]}" olddefconfig

    # 3. Compile Kernel Image for this variant
    echo "[*] Compiling Kernel Image for ${VARIANT}..."
    make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" Image

    if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
        echo "❌ [ERROR] Kernel Image for ${VARIANT} did NOT compile!"
        exit 1
    fi

    # 4. Copy newly compiled Image to anykernel
    cp "${OUT_DIR}/arch/arm64/boot/Image" anykernel/Image

    # 5. Write variant-specific anykernel.sh
    cat > anykernel/anykernel.sh << EOF
### AnyKernel3 Ramdisk Mod Script
## EXTREME++ HyperOS Kernel for POCO F4 (munch) by PandeyJI-9

properties() { '
kernel.string=${TITLE}
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=munch
device.name2=POCO F4
supported.versions=13-17
'; }

# boot shell variables
block=boot;
is_slot_device=auto;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;
no_block_display=1;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

ui_print " ";
ui_print "  -> Flashing ${TITLE} (boot)...";

# Safe boot install (Preserves first-stage ramdisk 100% untouched, replaces only Image and DTB)
split_boot;
flash_boot;
# NOTE: Stock vendor_boot and DTBO partitions are preserved 100% untouched to prevent any bootloops!

# Install post-boot optimization script into /data/adb/service.d for KSU/RKSU/Magisk
if [ ! -d /data/adb/service.d ]; then
    mount /data 2>/dev/null
fi
if [ -d /data/adb ]; then
    mkdir -p /data/adb/service.d
    ui_print "  -> Installing EXTREME++ Joyose & Performance Service...";
    cp -f 00-extreme-performance.sh /data/adb/service.d/00-extreme-performance.sh 2>/dev/null || cp -f \$home/00-extreme-performance.sh /data/adb/service.d/00-extreme-performance.sh 2>/dev/null
    chmod 755 /data/adb/service.d/00-extreme-performance.sh
    chown root:root /data/adb/service.d/00-extreme-performance.sh 2>/dev/null
fi
EOF

    # 6. Package into flashable ZIP
    if [ "$ENABLE_KSU" -eq 1 ]; then
        ZIP_NAME="${ZIP_BASE}_${DATE_TAG}.zip"
    else
        ZIP_NAME="${ZIP_BASE}_NoRoot_${DATE_TAG}.zip"
    fi

    (
        cd anykernel
        zip -r9 "../${ZIP_NAME}" ./* -x .gitignore out/ ./*.zip > /dev/null
    )

    echo "[+] =========================================================="
    echo "[+] SUCCESS! ${VARIANT} package ready: ${ZIP_NAME}"
    echo "[+] =========================================================="
done

echo ""
echo "🎉 ALL REQUESTED EXTREME++ VARIANTS BUILT AND PACKAGED SUCCESSFULLY!"
exit 0
