#!/bin/bash
# ==============================================================================
# EXTREME++ BMW Edition Kernel Build Script
# Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Targets: HyperOS 4 / HyperOS & AOSP (Android 13–17)
# ==============================================================================

set -e
trap 'echo "❌ [ERROR] Script failed on line $LINENO"; exit 1' ERR

if [ -z "$1" ]; then
    echo "[!] Error: No device specified."
    echo "Usage: $0 <device_name> [ksu|noroot] [hyperos|aosp|both]"
    exit 1
fi

DEVICE_NAME="$1"
DEFCONFIG="${DEVICE_NAME}_defconfig"
ENABLE_KSU=0

if [ "$2" == "ksu" ] || [ "$2" == "true" ] || [ "$2" == "1" ]; then
    ENABLE_KSU=1
fi

TARGET_OS="${3:-both}"
TARGET_OS=$(echo "$TARGET_OS" | tr '[:upper:]' '[:lower:]')
case "$TARGET_OS" in
    hyperos|miui) TARGET_OS="hyperos" ;;
    aosp) TARGET_OS="aosp" ;;
    *) TARGET_OS="both" ;;
esac

KERNEL_DIR="$(pwd)"
TOOLCHAIN_BIN="$HOME/zyc-clang/bin"

export PATH="${TOOLCHAIN_BIN}:${PATH}"
export ARCH="arm64"
export SUBARCH="arm64"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
export CCACHE_DIR="$HOME/.cache/ccache_mikernel"
export CCACHE_EXEC=$(command -v ccache)
export USE_CCACHE=1

TOTAL_CORES=$(nproc --all)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 EXTREME++ BMW Edition Build Engine Initiated!"
echo "   Device: POCO F4 (munch / SM8250-AC)"
echo "   Root Mode: $([ "$ENABLE_KSU" -eq 1 ] && echo 'KowSU Multi-Manager + SuSFS v2.3.0' || echo 'Pure Clean Base')"
echo "   Target Mode: ${TARGET_OS}"
echo "   System Cores: ${TOTAL_CORES} (Running at Full Speed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ------------------------------------------
# 1. Base Cleanup & Custom Defconfig Tunables
# ------------------------------------------
echo "[*] Cleaning previous temporary outputs..."
rm -rf out out_hyperos out_aosp anykernel anykernel_* EXTREME++*.zip
find . -type f \( -name "dtbo.img" -o -name "Image" -o -name "Image.gz" \) -delete

# ZRAM ZSTD, EXTREME+ Governor & GPU Devfreq base symbols
sed -i 's/CONFIG_ZRAM_DEF_COMP_LZ4=y/CONFIG_ZRAM_DEF_COMP_ZSTD=y/' "arch/arm64/configs/${DEFCONFIG}"
grep -q "CONFIG_CRYPTO_ZSTD=y" "arch/arm64/configs/${DEFCONFIG}" || cat >> "arch/arm64/configs/${DEFCONFIG}" << 'EOF'
CONFIG_CRYPTO_ZSTD=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_ZRAM_DEF_COMP="zstd"
CONFIG_PM_DEVFREQ=y
CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y
CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y
CONFIG_QCOM_ADRENO_DEFAULT_GOVERNOR="msm-adreno-tz"
CONFIG_QCOM_KGSL=y
CONFIG_CPU_FREQ_GOV_EXTREME_PLUS=y
CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y
CONFIG_CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS=y
CONFIG_CPU_FREQ_DEFAULT_GOV="extreme+"
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
# 3. KernelSU (RKSU / ReSukiSU Multi-Manager Non-GKI 4.19 with SuSFS v2.3.0) Setup
# ------------------------------------------
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "[*] Injecting ReSukiSU / RKSU Multi-Manager (Non-GKI 4.19 with SuSFS v2.3.0) Source..."
    curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash -s -- v4.2.0-rc3

    if [ -f "drivers/kernelsu/Kconfig" ]; then
        sed -i 's/default KSU_TRACEPOINT_HOOK/default KSU_SUSFS/' drivers/kernelsu/Kconfig
        echo "[+] Default hook set to KSU_SUSFS in drivers/kernelsu/Kconfig"
    fi

    python3 -c '
import os

candidates = [
    "drivers/kernelsu/kernel/manager/apk_sign.c",
    "drivers/kernelsu/manager/apk_sign.c",
    "drivers/kernelsu/apk_sign.c",
]
apk_sign_path = next((p for p in candidates if os.path.exists(p)), None)
if apk_sign_path:
    with open(apk_sign_path, "r") as f:
        content = f.read()

    hook_target = "return check_v2_signature(path, signature_index);"
    hook_replacement = """// Bulletproof Fallback: check known manager package names
    if (check_v2_signature(path, signature_index))
        return true;
    char pkg_buf[128];
    if (get_pkg_from_apk_path(pkg_buf, path) == 0) {
        if (!strcmp(pkg_buf, "me.weishu.kernelsu") ||
            !strcmp(pkg_buf, "org.resukisu.resukisu") ||
            !strcmp(pkg_buf, "org.bakasu.bakasu") ||
            !strcmp(pkg_buf, "com.sukisu.ultra") ||
            !strcmp(pkg_buf, "com.kowx712.supermanager") ||
            !strcmp(pkg_buf, "com.resukisu")) {
            pr_info("PROJECT EXTREME+: Manager recognized by known package name: %s\\n", pkg_buf);
            *signature_index = 0;
            return true;
        }
    }
    return false;"""
    if hook_target in content and "pkg_buf" not in content:
        content = content.replace(hook_target, hook_replacement)
        with open(apk_sign_path, "w") as f:
            f.write(content)
        print("✅ Patched " + apk_sign_path + " with universal manager package verification")
    else:
        print("ℹ️ " + apk_sign_path + " already patched or target signature pattern handled")
' 2>/dev/null || true

    echo "CONFIG_KSU=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_KSU_SUSFS=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_THREAD_INFO_IN_TASK=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "[+] RKSU / ReSukiSU Multi-Manager Non-GKI setup finished."
else
    echo "[*] Ensuring Pure Clean Kernel Base (Zero embedded root hooks)..."
    sed -i '/CONFIG_KSU/d' "arch/arm64/configs/${DEFCONFIG}" 2>/dev/null || true
fi

# ------------------------------------------
# 4. Native FakeDreamer Adreno 650 Undervolt & Speed Bins (150MHz - 670MHz)
# ------------------------------------------
echo "[*] Applying Native FakeDreamer GPU Undervolt (150MHz - 670MHz) & Speed Bins..."
if [ -f "kona-v2-gpu.dtsi" ]; then
    cp -f kona-v2-gpu.dtsi arch/arm64/boot/dts/vendor/qcom/kona-v2-gpu.dtsi
    echo "[+] Copied FakeDreamer kona-v2-gpu.dtsi into kernel tree"
fi

cat > arch/arm64/boot/dts/vendor/qcom/kona-v2.1-gpu.dtsi << 'EOF'
&msm_gpu {
	qcom,chipid = <0x06050002>;
};
EOF
echo "[+] kona-v2.1-gpu.dtsi set to pure FakeDreamer chipid override"

# ------------------------------------------
# 5. Inject Custom EXTREME+ Governor (Zero-Latency & Anti-Choke)
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

# ------------------------------------------
# 6. Apply Performance, EAS, Charging & VM Patches
# ------------------------------------------
if [ -f "apply-cpu-cap.py" ]; then
    echo "[*] Ensuring full-range 3.19 GHz Prime Core driver & DTS alignment..."
    python3 apply-cpu-cap.py 3187200
fi

if [ -f "apply-fastcharge-bypass.py" ]; then
    echo "[*] Applying safe PD/PPS Fast Charge & Thermal DTS Stepping patches..."
    python3 apply-fastcharge-bypass.py
fi

if [ -f "apply-bootloader-spoof.py" ]; then
    echo "[*] Applying bootloader spoofing kernel hooks..."
    python3 apply-bootloader-spoof.py . || true
fi

if [ -f "apply-eas-tuning.py" ]; then
    echo "[*] Applying EAS Energy Model & Capacity Margin Tuning..."
    python3 apply-eas-tuning.py arch/arm64/boot/dts/vendor/qcom/kona.dtsi || echo "⚠️ EAS tuning failed, continuing..."
fi

if [ -f "apply-vmscan-critical.py" ]; then
    echo "[*] Applying Critical Task Direct Reclaim Anti-Stutter Patch (Google ACK fix)..."
    python3 apply-vmscan-critical.py mm/vmscan.c || echo "⚠️ vmscan patch skipped"
fi

if [ -f "kernel/sched/cpufreq_schedutil.c" ]; then
    sed -i 's/tunables->up_rate_limit_us = CONFIG_SCHEDUTIL_UP_RATE_LIMIT;/tunables->up_rate_limit_us = 0;/' kernel/sched/cpufreq_schedutil.c
    echo "[+] Schedutil up_rate_limit_us set to 0 in kernel/sched/cpufreq_schedutil.c for lightning boot"
fi

if [ -f "fs/dcache.c" ]; then
    sed -i 's/int sysctl_vfs_cache_pressure __read_mostly = [0-9]*;/int sysctl_vfs_cache_pressure __read_mostly = 50;/' fs/dcache.c
    echo "[+] Optimized sysctl_vfs_cache_pressure to 50 in fs/dcache.c for instant app launch"
fi

# ------------------------------------------
# 7. Clone AnyKernel3 Base Template
# ------------------------------------------
echo "[*] Cloning AnyKernel3 base template..."
rm -rf anykernel_template
if ! git clone --depth=1 https://github.com/re-noroi/anykernel3-test -b munch anykernel_template; then
    echo "[!] Fallback to AstideLabs AnyKernel3..."
    git clone --depth=1 https://github.com/AstideLabs/AnyKernel3 -b kona anykernel_template
fi
rm -rf anykernel_template/.git

# ==============================================================================
# MODULAR BUILD FUNCTION (HyperOS vs AOSP)
# ==============================================================================
build_target_os() {
    local OS="$1"
    local OS_UPPER=$(echo "$OS" | tr '[:lower:]' '[:upper:]')
    local OUT_DIR="${KERNEL_DIR}/out_${OS}"
    local MAKE_OPTS=(
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

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔨 Starting Kernel Compilation for ${DEVICE_NAME} (Target: ${OS_UPPER})"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    rm -rf "${OUT_DIR}"
    mkdir -p "${OUT_DIR}"

    echo "[*] Generating Defconfig (${DEFCONFIG}) for ${OS_UPPER}..."
    make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" "${DEFCONFIG}"

    # 1. Baseband-guard
    scripts/config --file "${OUT_DIR}/.config" -e BBG

    # 2. Adreno TrustZone GPU Devfreq Governor & Bus Monitor
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

    # 3. ZRAM ZSTD Zero-Stutter Memory Compression
    scripts/config --file "${OUT_DIR}/.config" \
        -e ZRAM \
        -e CRYPTO_ZSTD \
        -e ZSTD_COMPRESS \
        -e ZSTD_DECOMPRESS \
        -e ZRAM_DEF_COMP_ZSTD \
        -d ZRAM_DEF_COMP_LZ4 \
        --set-str ZRAM_DEF_COMP "zstd"

    # 4. Ultra-Fast & Safe Boot (Zero-Latency EXTREME+ Governor)
    scripts/config --file "${OUT_DIR}/.config" \
        -e CPU_FREQ_GOV_SCHEDUTIL \
        -e CPU_FREQ_GOV_EXTREME_PLUS \
        -e CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS \
        -d CPU_FREQ_DEFAULT_GOV_SCHEDUTIL \
        --set-str CPU_FREQ_DEFAULT_GOV "extreme+"

    # 5. TCP BBR Congestion Control & Lightweight Gaming Tunables
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

    # 6. Root Configuration (KowSU / ReSukiSU + SuSFS v2.3.0 vs Pure Clean Base)
    if [ "$ENABLE_KSU" -eq 1 ]; then
        echo "[*] Injecting Full RKSU / ReSukiSU + SuSFS v2.3.0 Configuration into ${OS_UPPER} .config..."
        scripts/config --file "${OUT_DIR}/.config" \
            -e KSU \
            -e KSU_SUSFS \
            -d KSU_TRACEPOINT_HOOK \
            -d KSU_MANUAL_HOOK \
            -e KSU_MULTI_MANAGER_SUPPORT \
            -e THREAD_INFO_IN_TASK \
            -e KSU_SUSFS_SUS_PATH \
            -e KSU_SUSFS_SUS_MOUNT \
            -e KSU_SUSFS_SUS_KSTAT \
            -e KSU_SUSFS_SPOOF_UNAME \
            -e KSU_SUSFS_ENABLE_LOG \
            -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
            -e KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
            -e KSU_SUSFS_OPEN_REDIRECT \
            -e KSU_SUSFS_SUS_MAP \
            -d KSU_DISABLE_MANAGER \
            -d KSU_DISABLE_POLICY
    else
        echo "[*] Disabling embedded KSU for Pure Clean Kernel (${OS_UPPER})..."
        scripts/config --file "${OUT_DIR}/.config" \
            -d KSU \
            -d KSU_SUSFS \
            -d KSU_TRACEPOINT_HOOK \
            -d KSU_MANUAL_HOOK
        sed -i '/CONFIG_KSU/d' "${OUT_DIR}/.config" 2>/dev/null || true
    fi

    # 7. Target-Specific Kernel Subsystems & Settings
    local LOCALVER
    local TITLE
    local ZIP_BASE
    local OS_BADGE

    if [ "$OS" == "hyperos" ]; then
        echo "[*] Injecting Xiaomi HyperOS / HyperOS 4 Subsystems..."
        LOCALVER="-Extreme++Gaming-HyperOS-BMW"
        TITLE="Extreme++Gaming BMW Edition [HyperOS] | POCO F4 (munch)"
        ZIP_BASE="EXTREME++Gaming_BMW_Edition_HyperOS"
        OS_BADGE="HyperOS 4 / HyperOS (Android 13–17)"

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
    else
        echo "[*] Injecting Clean AOSP Subsystems (Android 16 & 17 Tested & Verified)..."
        LOCALVER="-Extreme++Gaming-AOSP-BMW"
        TITLE="Extreme++Gaming BMW Edition [AOSP A16/A17] | POCO F4 (munch)"
        ZIP_BASE="EXTREME++Gaming_BMW_Edition_AOSP"
        OS_BADGE="AOSP Custom ROMs (Android 13–17 / A16 & A17 Tested)"

        scripts/config --file "${OUT_DIR}/.config" \
            --set-str STATIC_USERMODEHELPER_PATH "" \
            -d XIAOMI_MIUI \
            -d MIGT \
            -d MIGT_ENERGY_MODEL \
            -d MIHW \
            -d SF_BINDER \
            -d RTMM \
            -d BOOTUP_RECLAIM \
            -d MI_RECLAIM \
            -d PERF_HELPER \
            -d PERF_HUMANTASK \
            -d PERF_CRITICAL_RT_TASK \
            -d MILLET_CGROUP \
            -d MILLET_SIG \
            -d MILLET_BINDER \
            -d MILLET_PKG \
            -d MILLET_BINDER_GKI \
            -d MILLET_CORE \
            -d MILLET_HS \
            -d BINDER_PRIO \
            -d PACKAGE_RUNTIME_INFO \
            -d BINDER_OPT \
            -d MIUI_ZRAM_MEMORY_TRACKING \
            -d MI_MEMORY_SYSFS \
            -e OVERLAY_FS \
            -e REKERNEL \
            -e REKERNEL_NETWORK \
            -d LTO_CLANG \
            -e LTO_NONE \
            -d SHADOW_CALL_STACK \
            -d LTO_CLANG_THIN -d CFI_CLANG
    fi

    scripts/config --file "${OUT_DIR}/.config" --set-str LOCALVERSION "${LOCALVER}"
    rm -f "${OUT_DIR}/include/config/kernel.release"
    make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" olddefconfig

    # 8. Compile Master DTB Table & DTBO
    echo "[*] Compiling ${OS_UPPER} Master DTB Table & DTBO Image..."
    make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" dtbs dtbo.img dtb

    # 9. Compile Master Kernel Image
    echo "[*] Compiling ${OS_UPPER} Master Kernel Image (3.19 GHz Monster Peak)..."
    make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" Image

    if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
        echo "❌ [ERROR] ${OS_UPPER} Master Kernel Image did NOT compile!"
        exit 1
    fi
    echo "✅ [SUCCESS] ${OS_UPPER} Image compiled successfully ($(du -h "${OUT_DIR}/arch/arm64/boot/Image" | cut -f1))"

    # 10. AnyKernel3 Packaging for Target
    local AK_DIR="${KERNEL_DIR}/anykernel_${OS}"
    rm -rf "${AK_DIR}"
    cp -r anykernel_template "${AK_DIR}"

    cp "${OUT_DIR}/arch/arm64/boot/Image" "${AK_DIR}/Image"
    if [ -f "${OUT_DIR}/arch/arm64/boot/dtb" ]; then
        cp "${OUT_DIR}/arch/arm64/boot/dtb" "${AK_DIR}/dtb"
    elif [ -f "${OUT_DIR}/arch/arm64/boot/dtb.img" ]; then
        cp "${OUT_DIR}/arch/arm64/boot/dtb.img" "${AK_DIR}/dtb"
    else
        cat ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtb > "${AK_DIR}/dtb"
    fi

    # Post-boot performance service script
    if [ "$OS" == "hyperos" ]; then
        cat > "${AK_DIR}/00-extreme-performance.sh" << 'EOF'
#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════
#  PROJECT EXTREME++ — HyperOS Joyose, Governor & Sniper Service
#  POCO F4 (munch / SM8250-AC Kona) | HyperOS 1-4
# ═══════════════════════════════════════════════════════════════

(
for queue in /sys/block/*/queue; do
    case "$queue" in
        *zram*|*loop*) continue ;;
        *) [ -d "$queue" ] && echo 2048 > "$queue/read_ahead_kb" 2>/dev/null || true ;;
    esac
done

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done
sleep 15

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH"
RP="$(command -v resetprop 2>/dev/null)"
[ -z "$RP" ] && [ -x /data/adb/ksu/bin/resetprop ] && RP="/data/adb/ksu/bin/resetprop"
[ -z "$RP" ] && [ -x /data/adb/ap/bin/resetprop ] && RP="/data/adb/ap/bin/resetprop"
[ -z "$RP" ] && [ -x /data/adb/magisk/resetprop ] && RP="/data/adb/magisk/resetprop"

if [ -n "$RP" ]; then
    "$RP" -n ro.boot.verifiedbootstate green 2>/dev/null || true
    "$RP" -n ro.boot.vbmeta.device_state locked 2>/dev/null || true
    "$RP" -n ro.boot.veritymode enforcing 2>/dev/null || true
    "$RP" -n ro.boot.flash.locked 1 2>/dev/null || true
    "$RP" -n ro.boot.bootloader.locked 1 2>/dev/null || true
    "$RP" -n sys.oem_unlock_allowed 0 2>/dev/null || true
    "$RP" -n ro.secureboot.lockstate locked 2>/dev/null || true
    "$RP" -n ro.boot.warranty_bit 0 2>/dev/null || true
    "$RP" -n ro.warranty_bit 0 2>/dev/null || true
fi

# iOS-Style QoS CPU Pinning
echo 0-3 > /dev/cpuset/background/cpus 2>/dev/null || true
echo 0-3 > /dev/cpuset/system-background/cpus 2>/dev/null || true
echo 0-3 > /dev/cpuset/restricted/cpus 2>/dev/null || true
echo 0-7 > /dev/cpuset/foreground/cpus 2>/dev/null || true
echo 0-7 > /dev/cpuset/top-app/cpus 2>/dev/null || true

# Dynamic Task Weighting
echo 15 > /dev/stune/top-app/schedtune.boost 2>/dev/null || true
echo 1 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null || true
echo 1 > /dev/stune/foreground/schedtune.prefer_idle 2>/dev/null || true
echo 0 > /dev/stune/background/schedtune.prefer_idle 2>/dev/null || true
echo 15 > /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null || true
echo 1 > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null || true

echo "65 80" > /proc/sys/kernel/sched_upmigrate 2>/dev/null || true
echo "50 65" > /proc/sys/kernel/sched_downmigrate 2>/dev/null || true
echo 70 > /proc/sys/kernel/sched_group_upmigrate 2>/dev/null || true
echo 55 > /proc/sys/kernel/sched_group_downmigrate 2>/dev/null || true

# EXTREME+ Governor Enforcement
for p in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -f "$p/scaling_available_governors" ] && grep -q "extreme+" "$p/scaling_available_governors"; then
        echo "extreme+" > "$p/scaling_governor" 2>/dev/null || true
    fi
    for gov in extreme+ schedutil; do
        if [ -d "$p/$gov" ]; then
            echo 0 > "$p/$gov/up_rate_limit_us" 2>/dev/null || true
            echo 5000 > "$p/$gov/down_rate_limit_us" 2>/dev/null || true
            echo 65 > "$p/$gov/hispeed_load" 2>/dev/null || true
            echo 1 > "$p/$gov/pl" 2>/dev/null || true
        fi
    done
done

echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq 2>/dev/null || true
echo 710400 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq 2>/dev/null || true
echo 844800 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq 2>/dev/null || true
echo Y > /sys/module/workqueue/parameters/power_efficient 2>/dev/null || true

# Memory & LMK Suite
echo 100 > /proc/sys/vm/swappiness 2>/dev/null || true
echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null || true
echo 15 > /proc/sys/vm/dirty_ratio 2>/dev/null || true
echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null || true
echo 16 > /proc/sys/vm/watermark_scale_factor 2>/dev/null || true
echo 40960 > /proc/sys/vm/extra_free_kbytes 2>/dev/null || true
echo 0 > /proc/sys/vm/page-cluster 2>/dev/null || true
echo 750 > /proc/sys/vm/extfrag_threshold 2>/dev/null || true
echo 20 > /proc/sys/vm/compaction_proactiveness 2>/dev/null || true
echo 1 > /proc/sys/vm/compact_unevictable_allowed 2>/dev/null || true

setprop ro.lmk.kill_heaviest_task false 2>/dev/null || true
setprop ro.lmk.kill_timeout_ms 150 2>/dev/null || true
setprop ro.lmk.psi_partial_stall_ms 70 2>/dev/null || true
setprop ro.lmk.psi_complete_stall_ms 700 2>/dev/null || true
setprop ro.lmk.swap_util_max 90 2>/dev/null || true
setprop ro.lmk.thrashing_limit 30 2>/dev/null || true
setprop ro.lmk.downgrade_pressure 100 2>/dev/null || true

for queue in /sys/block/*/queue; do
    if [ -d "$queue" ]; then
        echo 0 > "$queue/iostats" 2>/dev/null || true
        echo 512 > "$queue/read_ahead_kb" 2>/dev/null || true
        echo 0 > "$queue/add_random" 2>/dev/null || true
        echo 0 > "$queue/nomerges" 2>/dev/null || true
        echo 0 > "$queue/rotational" 2>/dev/null || true
    fi
done

# Network TCP BBR
echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_sack 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_dsack 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null || true
echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null || true
echo "fq" > /proc/sys/net/core/default_qdisc 2>/dev/null || true

# Joyose Neutralizer (HyperOS ONLY)
setprop persist.sys.joyose.thermal.disabled 1 2>/dev/null || true

# Node Permissions
chown root:system /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null || true
chown root:system /sys/class/kgsl/kgsl-3d0/force_bus_on 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/force_bus_on 2>/dev/null || true
chown root:system /sys/class/kgsl/kgsl-3d0/force_clk_on 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/force_clk_on 2>/dev/null || true
chown root:system /sys/class/kgsl/kgsl-3d0/gpu_min_clock 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/gpu_min_clock 2>/dev/null || true
chown root:system /sys/class/kgsl/kgsl-3d0/gpu_max_clock 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/gpu_max_clock 2>/dev/null || true
chmod 444 /sys/class/kgsl/kgsl-3d0/gpubusy 2>/dev/null || true
chmod 444 /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage 2>/dev/null || true

chown root:system /sys/devices/system/cpu/cpufreq/policy*/scaling_governor 2>/dev/null || true
chmod 664 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor 2>/dev/null || true
chown root:system /sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq 2>/dev/null || true
chmod 664 /sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq 2>/dev/null || true
chown root:system /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq 2>/dev/null || true
chmod 664 /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq 2>/dev/null || true
chown root:system /sys/kernel/extreme_profile 2>/dev/null || true
chmod 664 /sys/kernel/extreme_profile 2>/dev/null || true
chown root:system /sys/kernel/extreme_target_fps 2>/dev/null || true
chmod 664 /sys/kernel/extreme_target_fps 2>/dev/null || true

# Bypass Charging Permissions & Compatibility Symlink
chmod 666 /sys/class/power_supply/battery/input_suspend 2>/dev/null || true
chmod 666 /sys/class/power_supply/battery/battery_input_suspend 2>/dev/null || true
chmod 666 /sys/class/power_supply/battery/charging_enabled 2>/dev/null || true
chown root:system /sys/class/power_supply/battery/input_suspend 2>/dev/null || true
if [ -d /sys/class/qcom-battery ] && [ ! -e /sys/class/qcom-battery/bypass_charging_enable ]; then
    ln -sf /sys/class/power_supply/battery/input_suspend /sys/class/qcom-battery/bypass_charging_enable 2>/dev/null || true
fi

for f in /sys/class/qcom-battery/quick_charge_type /sys/class/power_supply/battery/fastcharge_mode; do
    [ -f "$f" ] && echo 1 > "$f" 2>/dev/null || true
done

echo "PROJECT EXTREME++: HyperOS Beast service active!" > /dev/kmsg 2>/dev/null || true
) &
EOF
    else
        cat > "${AK_DIR}/00-extreme-performance.sh" << 'EOF'
#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════
#  PROJECT EXTREME++ — AOSP Governor & Performance Sniper Service
#  POCO F4 (munch / SM8250-AC Kona) | AOSP Android 13–17 (A16 & A17)
# ═══════════════════════════════════════════════════════════════

(
for queue in /sys/block/*/queue; do
    case "$queue" in
        *zram*|*loop*) continue ;;
        *) [ -d "$queue" ] && echo 2048 > "$queue/read_ahead_kb" 2>/dev/null || true ;;
    esac
done

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done
sleep 15

export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH"
RP="$(command -v resetprop 2>/dev/null)"
[ -z "$RP" ] && [ -x /data/adb/ksu/bin/resetprop ] && RP="/data/adb/ksu/bin/resetprop"
[ -z "$RP" ] && [ -x /data/adb/ap/bin/resetprop ] && RP="/data/adb/ap/bin/resetprop"
[ -z "$RP" ] && [ -x /data/adb/magisk/resetprop ] && RP="/data/adb/magisk/resetprop"

if [ -n "$RP" ]; then
    "$RP" -n ro.boot.verifiedbootstate green 2>/dev/null || true
    "$RP" -n ro.boot.vbmeta.device_state locked 2>/dev/null || true
    "$RP" -n ro.boot.veritymode enforcing 2>/dev/null || true
    "$RP" -n ro.boot.flash.locked 1 2>/dev/null || true
    "$RP" -n ro.boot.bootloader.locked 1 2>/dev/null || true
    "$RP" -n sys.oem_unlock_allowed 0 2>/dev/null || true
    "$RP" -n ro.secureboot.lockstate locked 2>/dev/null || true
    "$RP" -n ro.boot.warranty_bit 0 2>/dev/null || true
    "$RP" -n ro.warranty_bit 0 2>/dev/null || true
fi

# iOS-Style QoS CPU Pinning
echo 0-3 > /dev/cpuset/background/cpus 2>/dev/null || true
echo 0-3 > /dev/cpuset/system-background/cpus 2>/dev/null || true
echo 0-3 > /dev/cpuset/restricted/cpus 2>/dev/null || true
echo 0-7 > /dev/cpuset/foreground/cpus 2>/dev/null || true
echo 0-7 > /dev/cpuset/top-app/cpus 2>/dev/null || true

# Dynamic Task Weighting (A16 & A17 uclamp cgroup v2 prioritized)
echo 15 > /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null || true
echo 1 > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null || true
echo 15 > /dev/stune/top-app/schedtune.boost 2>/dev/null || true
echo 1 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null || true
echo 1 > /dev/stune/foreground/schedtune.prefer_idle 2>/dev/null || true
echo 0 > /dev/stune/background/schedtune.prefer_idle 2>/dev/null || true

echo "65 80" > /proc/sys/kernel/sched_upmigrate 2>/dev/null || true
echo "50 65" > /proc/sys/kernel/sched_downmigrate 2>/dev/null || true
echo 70 > /proc/sys/kernel/sched_group_upmigrate 2>/dev/null || true
echo 55 > /proc/sys/kernel/sched_group_downmigrate 2>/dev/null || true

# EXTREME+ Governor Enforcement
for p in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -f "$p/scaling_available_governors" ] && grep -q "extreme+" "$p/scaling_available_governors"; then
        echo "extreme+" > "$p/scaling_governor" 2>/dev/null || true
    fi
    for gov in extreme+ schedutil; do
        if [ -d "$p/$gov" ]; then
            echo 0 > "$p/$gov/up_rate_limit_us" 2>/dev/null || true
            echo 5000 > "$p/$gov/down_rate_limit_us" 2>/dev/null || true
            echo 65 > "$p/$gov/hispeed_load" 2>/dev/null || true
            echo 1 > "$p/$gov/pl" 2>/dev/null || true
        fi
    done
done

echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq 2>/dev/null || true
echo 710400 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq 2>/dev/null || true
echo 844800 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq 2>/dev/null || true
echo Y > /sys/module/workqueue/parameters/power_efficient 2>/dev/null || true

# Memory & LMK Suite
echo 100 > /proc/sys/vm/swappiness 2>/dev/null || true
echo 50 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null || true
echo 15 > /proc/sys/vm/dirty_ratio 2>/dev/null || true
echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null || true
echo 16 > /proc/sys/vm/watermark_scale_factor 2>/dev/null || true
echo 40960 > /proc/sys/vm/extra_free_kbytes 2>/dev/null || true
echo 0 > /proc/sys/vm/page-cluster 2>/dev/null || true
echo 750 > /proc/sys/vm/extfrag_threshold 2>/dev/null || true
echo 20 > /proc/sys/vm/compaction_proactiveness 2>/dev/null || true
echo 1 > /proc/sys/vm/compact_unevictable_allowed 2>/dev/null || true

setprop ro.lmk.kill_heaviest_task false 2>/dev/null || true
setprop ro.lmk.kill_timeout_ms 150 2>/dev/null || true
setprop ro.lmk.psi_partial_stall_ms 70 2>/dev/null || true
setprop ro.lmk.psi_complete_stall_ms 700 2>/dev/null || true
setprop ro.lmk.swap_util_max 90 2>/dev/null || true
setprop ro.lmk.thrashing_limit 30 2>/dev/null || true
setprop ro.lmk.downgrade_pressure 100 2>/dev/null || true

for queue in /sys/block/*/queue; do
    if [ -d "$queue" ]; then
        echo 0 > "$queue/iostats" 2>/dev/null || true
        echo 512 > "$queue/read_ahead_kb" 2>/dev/null || true
        echo 0 > "$queue/add_random" 2>/dev/null || true
        echo 0 > "$queue/nomerges" 2>/dev/null || true
        echo 0 > "$queue/rotational" 2>/dev/null || true
    fi
done

# Network TCP BBR
echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_sack 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_dsack 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null || true
echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null || true
echo "fq" > /proc/sys/net/core/default_qdisc 2>/dev/null || true

chown root:system /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null || true
chown root:system /sys/class/kgsl/kgsl-3d0/force_bus_on 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/force_bus_on 2>/dev/null || true
chown root:system /sys/class/kgsl/kgsl-3d0/force_clk_on 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/force_clk_on 2>/dev/null || true
chown root:system /sys/class/kgsl/kgsl-3d0/gpu_min_clock 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/gpu_min_clock 2>/dev/null || true
chown root:system /sys/class/kgsl/kgsl-3d0/gpu_max_clock 2>/dev/null || true
chmod 664 /sys/class/kgsl/kgsl-3d0/gpu_max_clock 2>/dev/null || true
chmod 444 /sys/class/kgsl/kgsl-3d0/gpubusy 2>/dev/null || true
chmod 444 /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage 2>/dev/null || true

chown root:system /sys/devices/system/cpu/cpufreq/policy*/scaling_governor 2>/dev/null || true
chmod 664 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor 2>/dev/null || true
chown root:system /sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq 2>/dev/null || true
chmod 664 /sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq 2>/dev/null || true
chown root:system /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq 2>/dev/null || true
chmod 664 /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq 2>/dev/null || true
chown root:system /sys/kernel/extreme_profile 2>/dev/null || true
chmod 664 /sys/kernel/extreme_profile 2>/dev/null || true
chown root:system /sys/kernel/extreme_target_fps 2>/dev/null || true
chmod 664 /sys/kernel/extreme_target_fps 2>/dev/null || true

# Bypass Charging Permissions & Compatibility Symlink
chmod 666 /sys/class/power_supply/battery/input_suspend 2>/dev/null || true
chmod 666 /sys/class/power_supply/battery/battery_input_suspend 2>/dev/null || true
chmod 666 /sys/class/power_supply/battery/charging_enabled 2>/dev/null || true
chown root:system /sys/class/power_supply/battery/input_suspend 2>/dev/null || true
if [ -d /sys/class/qcom-battery ] && [ ! -e /sys/class/qcom-battery/bypass_charging_enable ]; then
    ln -sf /sys/class/power_supply/battery/input_suspend /sys/class/qcom-battery/bypass_charging_enable 2>/dev/null || true
fi

echo "PROJECT EXTREME++: AOSP Beast service active!" > /dev/kmsg 2>/dev/null || true
) &
EOF
    fi
    chmod 755 "${AK_DIR}/00-extreme-performance.sh"

    # Early-boot props script
    cat > "${AK_DIR}/00-extreme-props.sh" << 'EOF'
#!/system/bin/sh
export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH"
RP="$(command -v resetprop 2>/dev/null)"
[ -z "$RP" ] && [ -x /data/adb/ksu/bin/resetprop ] && RP="/data/adb/ksu/bin/resetprop"
[ -z "$RP" ] && [ -x /data/adb/ap/bin/resetprop ] && RP="/data/adb/ap/bin/resetprop"
[ -z "$RP" ] && [ -x /data/adb/magisk/resetprop ] && RP="/data/adb/magisk/resetprop"

if [ -n "$RP" ]; then
    "$RP" -n ro.boot.verifiedbootstate green 2>/dev/null || true
    "$RP" -n ro.boot.vbmeta.device_state locked 2>/dev/null || true
    "$RP" -n ro.boot.veritymode enforcing 2>/dev/null || true
    "$RP" -n ro.boot.flash.locked 1 2>/dev/null || true
    "$RP" -n ro.boot.bootloader.locked 1 2>/dev/null || true
    "$RP" -n sys.oem_unlock_allowed 0 2>/dev/null || true
    "$RP" -n ro.secureboot.lockstate locked 2>/dev/null || true
    "$RP" -n ro.boot.warranty_bit 0 2>/dev/null || true
    "$RP" -n ro.warranty_bit 0 2>/dev/null || true
    echo "EXTREME++: Early-boot bootloader properties synced (green/locked) in post-fs-data!" > /dev/kmsg 2>/dev/null || true
elif [ -x /data/adb/ksu/bin/ksud ]; then
    /data/adb/ksu/bin/ksud resetprop -n ro.boot.verifiedbootstate green 2>/dev/null || true
    /data/adb/ksu/bin/ksud resetprop -n ro.boot.vbmeta.device_state locked 2>/dev/null || true
    /data/adb/ksu/bin/ksud resetprop -n ro.boot.veritymode enforcing 2>/dev/null || true
    /data/adb/ksu/bin/ksud resetprop -n ro.boot.flash.locked 1 2>/dev/null || true
    /data/adb/ksu/bin/ksud resetprop -n ro.boot.bootloader.locked 1 2>/dev/null || true
    /data/adb/ksu/bin/ksud resetprop -n sys.oem_unlock_allowed 0 2>/dev/null || true
    /data/adb/ksu/bin/ksud resetprop -n ro.secureboot.lockstate locked 2>/dev/null || true
    /data/adb/ksu/bin/ksud resetprop -n ro.boot.warranty_bit 0 2>/dev/null || true
    /data/adb/ksu/bin/ksud resetprop -n ro.warranty_bit 0 2>/dev/null || true
fi
EOF
    chmod 755 "${AK_DIR}/00-extreme-props.sh"

    # anykernel.sh for target
    cat > "${AK_DIR}/anykernel.sh" << EOF
### AnyKernel3 Ramdisk Mod Script
## EXTREME++ ${OS_UPPER} Kernel for POCO F4 (munch) - BMW Edition

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

# shell variables
block=boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=0;

. tools/ak3-core.sh;

ui_print " ";
ui_print " ══════════════════════════════════════════════";
ui_print "   ______      __                              ";
ui_print "  / ____/  __ / /_ _____ ___   ____ ___ ___    ";
ui_print " / __/ | |/_// __// ___// _ \\ / __ '__// _ \\   ";
ui_print "/ /___ _>  < / /_ / /   /  __// / / / /  __/   ";
ui_print "\\____//_/|_| \\__//_/    \\___//_/ /_/ / \\___/   ";
ui_print "                 [ + + ]                       ";
ui_print " ══════════════════════════════════════════════";
ui_print "  🏎️  EDITION : BMW Gaming Edition (${OS_UPPER}) ";
ui_print "  👑  AUTHOR  : Extreme++ by @pandey_ji_8      ";
ui_print "  📱  DEVICE  : POCO F4 (munch) | ${OS_UPPER}  ";
ui_print "  ⚡  CLOCK   : 3.19 GHz Unlocked Monster Peak ";
ui_print "  🚀  PROFILES: In-Kernel Dynamic Switcher     ";
ui_print " ══════════════════════════════════════════════";
ui_print " ";

ui_print "  [1/4] ⚡ Extracting & Patching Boot Partition...";
dump_boot;
ui_print "  [1/4] 🚀 Writing EXTREME++ 3.19 GHz Kernel Image...";
write_boot;

## vendor_boot DTB install
ui_print "  [2/4] 📦 Analyzing Vendor Boot Partition...";
block=vendor_boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=0;

reset_ak;
dump_boot;
ui_print "  [2/4] 🏎️ Writing FakeDreamer Adreno 650 Undervolted DTB...";
write_boot;

# Install post-fs-data & service.d scripts into /data/adb for KSU/RKSU/Magisk/APatch
ui_print "  [3/4] 🛡️ Checking /data Storage & Root Subsystem...";
mount /data 2>/dev/null
[ -d /data ] && mkdir -p /data/adb/post-fs-data.d /data/adb/service.d 2>/dev/null
if [ -d /data/adb ]; then
    mkdir -p /data/adb/post-fs-data.d
    mkdir -p /data/adb/service.d
    ui_print "  [3/4] 💉 Installing Early Bootloader Lock Guard (post-fs-data)...";
    cp -f 00-extreme-props.sh /data/adb/post-fs-data.d/00-extreme-props.sh 2>/dev/null || cp -f \$home/00-extreme-props.sh /data/adb/post-fs-data.d/00-extreme-props.sh 2>/dev/null
    chmod 755 /data/adb/post-fs-data.d/00-extreme-props.sh
    chown root:root /data/adb/post-fs-data.d/00-extreme-props.sh 2>/dev/null

    ui_print "  [3/4] ⚙️ Installing Performance Optimizer & Dynamic Profiles (service.d)...";
    cp -f 00-extreme-performance.sh /data/adb/service.d/00-extreme-performance.sh 2>/dev/null || cp -f \$home/00-extreme-performance.sh /data/adb/service.d/00-extreme-performance.sh 2>/dev/null
    chmod 755 /data/adb/service.d/00-extreme-performance.sh
    chown root:root /data/adb/service.d/00-extreme-performance.sh 2>/dev/null
fi

ui_print "  [4/4] ✨ Preserving OEM Display Calibrations & Finalizing...";
ui_print " ";
ui_print " ══════════════════════════════════════════════";
ui_print "  🎉 Extreme++ Kernel (${OS_UPPER}) Flashed!  ";
ui_print "  🏎️ BMW Edition is Ready to Rock!             ";
ui_print " ══════════════════════════════════════════════";
ui_print " ";
EOF

    # Package into flashable ZIP
    local DATE_TAG="$(date +'%d%b%Y_%H%M')"
    local ZIP_NAME
    if [ "$ENABLE_KSU" -eq 1 ]; then
        ZIP_NAME="${ZIP_BASE}_KowSU_${DATE_TAG}.zip"
    else
        ZIP_NAME="${ZIP_BASE}_NoRoot_${DATE_TAG}.zip"
    fi

    (
        cd "${AK_DIR}"
        zip -r9 "../${ZIP_NAME}" ./* -x .gitignore out/ ./*.zip > /dev/null
    )

    echo "[+] =========================================================="
    echo "[+] SUCCESS! ${OS_UPPER} package ready: ${ZIP_NAME}"
    echo "[+] =========================================================="
}

# ==============================================================================
# EXECUTE REQUESTED TARGET BUILDS
# ==============================================================================
if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
    build_target_os "hyperos"
fi

if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
    build_target_os "aosp"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 ALL REQUESTED EXTREME++ BUILDS COMPLETED SUCCESSFULLY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
