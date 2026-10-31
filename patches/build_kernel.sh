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
    echo "Usage: $0 <device_name> [root|noroot|both] [hyperos|aosp|both]"
    exit 1
fi

DEVICE_NAME="$1"
DEFCONFIG="${DEVICE_NAME}_defconfig"

ROOT_MODE="${2:-ksu_susfs}"
ROOT_MODE=$(echo "$ROOT_MODE" | tr '[:upper:]' '[:lower:]')
case "$ROOT_MODE" in
    ksu_susfs|susfs|root|ksu|true|1)
        ROOT_MODE="ksu_susfs"
        ;;
    ksu_no_susfs|nosusfs|no_susfs|ksunosusfs)
        ROOT_MODE="ksu_no_susfs"
        ;;
    noroot|clean|false|0)
        ROOT_MODE="noroot"
        ;;
    all)
        ROOT_MODE="all"
        ;;
    both)
        ROOT_MODE="both"
        ;;
    *)
        ROOT_MODE="ksu_susfs"
        ;;
esac

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
echo "   Root Mode: ${ROOT_MODE}"
echo "   Target Mode: ${TARGET_OS}"
echo "   System Cores: ${TOTAL_CORES} (Running at Full Speed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ------------------------------------------
# 1. Base Cleanup & Custom Defconfig Tunables
# ------------------------------------------
echo "[*] Cleaning previous temporary outputs..."
rm -rf out out_hyperos out_aosp anykernel anykernel_* EXTREME++*.zip
find . -type f \( -name "dtbo.img" -o -name "Image" -o -name "Image.gz" \) -delete

# Fast ZRAM LZ4 (Zero CPU Overhead), EXTREME+ Governor & GPU Devfreq base symbols
sed -i 's/CONFIG_ZRAM_DEF_COMP_ZSTD=y/CONFIG_ZRAM_DEF_COMP_LZ4=y/' "arch/arm64/configs/${DEFCONFIG}"
grep -q "CONFIG_ZRAM_DEF_COMP_LZ4=y" "arch/arm64/configs/${DEFCONFIG}" || cat >> "arch/arm64/configs/${DEFCONFIG}" << 'EOF'
CONFIG_CRYPTO_LZ4=y
CONFIG_LZ4_COMPRESS=y
CONFIG_LZ4_DECOMPRESS=y
CONFIG_ZRAM_DEF_COMP_LZ4=y
CONFIG_ZRAM_DEF_COMP="lz4"
CONFIG_CRYPTO_ZSTD=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y
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
# 3. KernelSU (RKSU / ReSukiSU Multi-Manager Non-GKI 4.19 with SuSFS v2.3.0) Setup Function
# ------------------------------------------
inject_ksu_susfs() {
    if [ -d "KernelSU" ] || [ -d "drivers/kernelsu" ]; then
        echo "[*] ReSukiSU source already present, skipping re-injection..."
        return 0
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚡ Injecting ReSukiSU / KowSU Multi-Manager & SuSFS v2.3.0 Source..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
}

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

if [ -f "apply-millet-compat.py" ]; then
    echo "[*] Applying Xiaomi HyperOS 4 / MIUI Universal Millet Dual-ABI Compatibility Patch..."
    python3 apply-millet-compat.py . || echo "⚠️ Millet patch skipped"
fi

if [ -f "kernel/sched/cpufreq_schedutil.c" ]; then
    sed -i 's/tunables->up_rate_limit_us = CONFIG_SCHEDUTIL_UP_RATE_LIMIT;/tunables->up_rate_limit_us = 0;/' kernel/sched/cpufreq_schedutil.c
    echo "[+] Schedutil up_rate_limit_us set to 0 in kernel/sched/cpufreq_schedutil.c for lightning boot"
fi


# ------------------------------------------
# 7. Clone AnyKernel3 Base Template (Clean AstideLabs / osm0sis)
# ------------------------------------------
echo "[*] Cloning clean AnyKernel3 base template..."
rm -rf anykernel_template
if ! git clone --depth=1 https://github.com/AstideLabs/AnyKernel3 -b kona anykernel_template; then
    echo "[!] Fallback to osm0sis AnyKernel3..."
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3 -b master anykernel_template
fi
rm -rf anykernel_template/.git
# Sanitize: Remove any lingering foreign trigger/flag files (*.dreamless, stale images/dtb)
rm -f anykernel_template/*.dreamless anykernel_template/*.img anykernel_template/*dtb*

# ==============================================================================
# MODULAR BUILD FUNCTION (HyperOS vs AOSP)
# ==============================================================================
build_target_os() {
    local OS="$1"
    local ROOT_TYPE="${2:-0}"
    local OS_UPPER=$(echo "$OS" | tr '[:lower:]' '[:upper:]')
    local ENABLE_KSU=0
    local ENABLE_SUSFS=0
    local ROOT_LABEL="Pure Clean Base"
    local ROOT_BANNER="Pure Clean Base (No Root)"
    local ZIP_SUFFIX="NoRoot"

    if [ "$ROOT_TYPE" == "1" ] || [ "$ROOT_TYPE" == "ksu_susfs" ]; then
        ENABLE_KSU=1
        ENABLE_SUSFS=1
        ROOT_LABEL="KowSU + SuSFS v2.3.0"
        ROOT_BANNER="KowSU + SuSFS v2.3.0 (Multi-Manager)"
        ZIP_SUFFIX="KowSU_SuSFS"
    elif [ "$ROOT_TYPE" == "2" ] || [ "$ROOT_TYPE" == "ksu_no_susfs" ]; then
        ENABLE_KSU=1
        ENABLE_SUSFS=0
        ROOT_LABEL="KowSU Multi-Manager (No SuSFS)"
        ROOT_BANNER="KowSU Multi-Manager (Clean / No SuSFS)"
        ZIP_SUFFIX="KowSU_NoSuSFS"
    fi
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
    echo "🔨 Starting Kernel Compilation for ${DEVICE_NAME} (Target: ${OS_UPPER} | ${ROOT_LABEL})"
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

    # 3. ZRAM Fast LZ4 Default Memory Compression (Instant Zero-Latency Decompress)
    scripts/config --file "${OUT_DIR}/.config" \
        -e ZRAM \
        -e CRYPTO_LZ4 \
        -e LZ4_COMPRESS \
        -e LZ4_DECOMPRESS \
        -e ZRAM_DEF_COMP_LZ4 \
        -d ZRAM_DEF_COMP_ZSTD \
        --set-str ZRAM_DEF_COMP "lz4" \
        -e CRYPTO_ZSTD \
        -e ZSTD_COMPRESS \
        -e ZSTD_DECOMPRESS

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

    # 6. Root Configuration (ksu_susfs vs ksu_no_susfs vs noroot)
    if [ "$ENABLE_KSU" -eq 1 ]; then
        if [ "$ENABLE_SUSFS" -eq 1 ]; then
            echo "[*] Injecting Full RKSU / KowSU + SuSFS v2.3.0 Configuration into ${OS_UPPER} .config..."
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
            echo "[*] Injecting KowSU Multi-Manager (Standard / No SuSFS Features) Configuration into ${OS_UPPER} .config..."
            scripts/config --file "${OUT_DIR}/.config" \
                -e KSU \
                -e KSU_SUSFS \
                -d KSU_TRACEPOINT_HOOK \
                -d KSU_MANUAL_HOOK \
                -e KSU_MULTI_MANAGER_SUPPORT \
                -e THREAD_INFO_IN_TASK \
                -d KSU_SUSFS_SUS_PATH \
                -d KSU_SUSFS_SUS_MOUNT \
                -d KSU_SUSFS_SUS_KSTAT \
                -d KSU_SUSFS_SPOOF_UNAME \
                -d KSU_SUSFS_ENABLE_LOG \
                -d KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
                -d KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
                -d KSU_SUSFS_OPEN_REDIRECT \
                -d KSU_SUSFS_SUS_MAP \
                -d KSU_DISABLE_MANAGER \
                -d KSU_DISABLE_POLICY
        fi
    else
        echo "[*] Disabling embedded KSU for Pure Clean Kernel (${OS_UPPER})..."
        scripts/config --file "${OUT_DIR}/.config" \
            -d KSU \
            -d KSU_SUSFS \
            -d KSU_TRACEPOINT_HOOK \
            -d KSU_MANUAL_HOOK \
            -d KSU_MULTI_MANAGER_SUPPORT
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
    # Safety cleanup: Ensure zero unwanted trigger/dreamless files exist in the flashable zip
    rm -f "${AK_DIR}"/*.dreamless "${AK_DIR}"/*.img "${AK_DIR}"/dtb*

    cp "${OUT_DIR}/arch/arm64/boot/Image" "${AK_DIR}/Image"
    if [ -f "${OUT_DIR}/arch/arm64/boot/dtb" ]; then
        cp "${OUT_DIR}/arch/arm64/boot/dtb" "${AK_DIR}/dtb"
    elif [ -f "${OUT_DIR}/arch/arm64/boot/dtb.img" ]; then
        cp "${OUT_DIR}/arch/arm64/boot/dtb.img" "${AK_DIR}/dtb"
    else
        cat ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtb > "${AK_DIR}/dtb"
    fi

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
ui_print "  🛡️  ROOT    : ${ROOT_BANNER} ";
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

# Clean conflicting legacy service.d scripts from /data/adb (Fixes Poco logo freeze & bootloops)
ui_print "  [3/4] 🛡️ Checking Storage & Subsystems...";
mount /data 2>/dev/null
if [ -d /data/adb ]; then
    ui_print "  [3/4] 🧹 Auto-purging conflicting legacy scripts from /data/adb...";
    rm -f /data/adb/service.d/00-extreme-performance.sh
    rm -f /data/adb/post-fs-data.d/00-extreme-props.sh
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
    local ZIP_NAME="${ZIP_BASE}_${ZIP_SUFFIX}_${DATE_TAG}.zip"

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
if [ "$ROOT_MODE" == "noroot" ]; then
    echo "[*] Executing Pure Clean Non-Root Build..."
    sed -i '/CONFIG_KSU/d' "arch/arm64/configs/${DEFCONFIG}" 2>/dev/null || true
    if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "hyperos" 0
    fi
    if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "aosp" 0
    fi
elif [ "$ROOT_MODE" == "ksu_no_susfs" ]; then
    echo "[*] Executing KowSU Multi-Manager (Standard / No SuSFS) Build..."
    inject_ksu_susfs
    if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "hyperos" 2
    fi
    if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "aosp" 2
    fi
elif [ "$ROOT_MODE" == "ksu_susfs" ]; then
    echo "[*] Executing KowSU + SuSFS v2.3.0 Root Build..."
    inject_ksu_susfs
    if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "hyperos" 1
    fi
    if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "aosp" 1
    fi
elif [ "$ROOT_MODE" == "both" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 DUAL BUILD REQUESTED: Compiling Pure Clean & KowSU + SuSFS!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sed -i '/CONFIG_KSU/d' "arch/arm64/configs/${DEFCONFIG}" 2>/dev/null || true
    if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "hyperos" 0
    fi
    if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "aosp" 0
    fi
    inject_ksu_susfs
    if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "hyperos" 1
    fi
    if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "aosp" 1
    fi
elif [ "$ROOT_MODE" == "all" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 COMPLETE SUITE REQUESTED: Compiling ALL 3 Root Variants!"
    echo "   1. Pure Clean Base (No Root)"
    echo "   2. KowSU Multi-Manager (Standard / No SuSFS)"
    echo "   3. KowSU Multi-Manager + SuSFS v2.3.0"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sed -i '/CONFIG_KSU/d' "arch/arm64/configs/${DEFCONFIG}" 2>/dev/null || true
    if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "hyperos" 0
    fi
    if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "aosp" 0
    fi
    inject_ksu_susfs
    if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "hyperos" 2
    fi
    if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "aosp" 2
    fi
    if [ "$TARGET_OS" == "hyperos" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "hyperos" 1
    fi
    if [ "$TARGET_OS" == "aosp" ] || [ "$TARGET_OS" == "both" ]; then
        build_target_os "aosp" 1
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 ALL REQUESTED EXTREME++ BUILDS COMPLETED SUCCESSFULLY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
