#!/bin/bash
# ==========================================
# EXTREME++GAMING CUSTOM KERNEL ENGINE
# Modified for POCO F4 (munch)
# ==========================================

set -e

if [ -z "$1" ]; then
    echo "[!] Error: No device specified."
    exit 1
fi

DEVICE_NAME="$1"
DEFCONFIG="${DEVICE_NAME}_defconfig"
DEFCONFIG_PATH="arch/arm64/configs/${DEFCONFIG}"

ENABLE_KSU=0
TARGET_OS="both"

shift
for arg in "$@"; do
    case "$arg" in
        ksu) ENABLE_KSU=1 ;;
        miui) TARGET_OS="miui" ;;
        aosp) TARGET_OS="aosp" ;;
    esac
done

KERNEL_DIR="$(pwd)"
TOOLCHAIN_BIN="$HOME/zyc-clang/bin"

export PATH="${TOOLCHAIN_BIN}:${PATH}"
export ARCH="arm64"
export SUBARCH="arm64"
export CCACHE_DIR="$HOME/.cache/ccache_mikernel"
export CCACHE_EXEC=$(command -v ccache)
export USE_CCACHE=1
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"

mkdir -p "$CCACHE_DIR"

# ==========================================
# EXTREME++ SukiSU Ultra Setup
# ==========================================
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "==========================================="
    echo " [*] Initializing SukiSU Ultra"
    echo "==========================================="
    # HIJACKED: Ab ye ReSukiSU nahi, SukiSU-Ultra download karega!
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s main
    echo "[+] SukiSU Ultra setup finished."
fi

echo "==========================================="
echo " [*] Initializing Baseband-guard Setup"
echo "==========================================="
wget -O- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig

# ==========================================
# AnyKernel3 & DTBO Flasher Setup
# ==========================================
echo "==========================================="
echo " [*] Initializing AnyKernel3 Workspace"
echo "==========================================="
rm -rf anykernel
git clone https://github.com/AstideLabs/AnyKernel3 -b kona --single-branch --depth=1 anykernel
sed -i "s/^device\.name1=.*/device.name1=${DEVICE_NAME}/" anykernel/anykernel.sh

# INJECTING EXTREME++ DTBO FLASHER INTO ANYKERNEL
cat << 'EOF' >> anykernel/anykernel.sh

# EXTREME++ DTBO DIRECT FLASH
if [ -f $home/dtbo.img ]; then
  ui_print "- Flashing EXTREME++ 2.8GHz & 150MHz DTBO...";
  DTBO_BLOCK=""
  for path in /dev/block/bootdevice/by-name/dtbo$slot /dev/block/mapper/dtbo$slot /dev/block/by-name/dtbo$slot; do
    if [ -e "$path" ]; then
      DTBO_BLOCK="$path"
      break
    fi
  done
  if [ -n "$DTBO_BLOCK" ]; then
    dd if=$home/dtbo.img of=$DTBO_BLOCK
    ui_print "- ✅ DTBO Flashed Successfully!";
  else
    ui_print "- ❌ WARNING: DTBO partition not found!";
  fi
fi
EOF

build_target() {
    local OS_TYPE=$1
    echo "==========================================="
    echo " Starting Kernel Compilation for ${DEVICE_NAME} ($OS_TYPE)"
    echo "==========================================="
    
    local OUT_DIR="${KERNEL_DIR}/out_${OS_TYPE}"
    local MAKE_OPTS=(
        -j"$(nproc)"
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

    rm -rf "${OUT_DIR}"
    mkdir -p "${OUT_DIR}"

    local DTS_SOURCE="arch/arm64/boot/dts/vendor/qcom"
    local DTS_BACKUP=".dts.bak.${OS_TYPE}"

    if [ "$OS_TYPE" == "miui" ]; then
        cp -a "${DTS_SOURCE}" "${DTS_BACKUP}"
        sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j1s* || true
        # (Keeping Dev's MIUI display patches intact to prevent screen bleeding)
    fi

    make "${MAKE_OPTS[@]}" "${DEFCONFIG}"

    scripts/config --file "${OUT_DIR}/.config" -e BBG

    if [ "$ENABLE_KSU" -eq 1 ]; then
        scripts/config --file "${OUT_DIR}/.config" -e KSU -e THREAD_INFO_IN_TASK -e KSU_SUSFS
    fi

    if [ "$OS_TYPE" == "miui" ]; then
        scripts/config --file "${OUT_DIR}/.config" --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd -e PERF_CRITICAL_RT_TASK -e SF_BINDER -e OVERLAY_FS -e MIGT -e MIGT_ENERGY_MODEL -e MIHW -e PACKAGE_RUNTIME_INFO -e BINDER_OPT -e KPERFEVENTS -e PERF_HUMANTASK -d LTO_CLANG -e LTO_NONE -d SHADOW_CALL_STACK -e XIAOMI_MIUI -d MI_MEMORY_SYSFS -e TASK_DELAY_ACCT -e MIUI_ZRAM_MEMORY_TRACKING -e PERF_HELPER -e BOOTUP_RECLAIM -e MI_RECLAIM -e RTMM -e MILLET_CGROUP -e MILLET_SIG -e MILLET_BINDER -e MILLET_PKG -e MILLET_BINDER_GKI -e MILLET_CORE -e MILLET_HS -e BINDER_PRIO -d REKERNEL -d REKERNEL_NETWORK
    fi

    make "${MAKE_OPTS[@]}" olddefconfig

    echo "[*] Building kernel and EXTREME++ DTBO..."
    make "${MAKE_OPTS[@]}" 
    make "${MAKE_OPTS[@]}" dtbs # FORCE BUILD DTBO!

    if [ "$OS_TYPE" == "miui" ]; then
        rm -rf "${DTS_SOURCE}"
        mv "${DTS_BACKUP}" "${DTS_SOURCE}"
    fi

    if [ -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
        rm -rf anykernel/kernels/*
        mkdir -p "anykernel/kernels/${OS_TYPE}/"
        
        cp "${OUT_DIR}/arch/arm64/boot/Image" "anykernel/"
        
        if [ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
            echo "✅ 2.8GHz DTBO Found! Packaging..."
            cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" "anykernel/"
        fi
        
        local KSU_ZIP_STR="NoRoot"
        if [ "$ENABLE_KSU" -eq 1 ]; then
            KSU_ZIP_STR="SukiSU-Ultra"
        fi
        local ZIP_FILENAME="EXTREME_HyperOS_${DEVICE_NAME}_${KSU_ZIP_STR}_$(date +'%Y%m%d').zip"
        
        echo "[*] Zipping $ZIP_FILENAME ..."
        pushd anykernel > /dev/null
        zip -r9 "$ZIP_FILENAME" ./* -x .git .gitignore out/ ./*.zip > /dev/null
        mv "$ZIP_FILENAME" ../
        popd > /dev/null
        
        echo "ZIP_PATH=${KERNEL_DIR}/${ZIP_FILENAME}" >> $GITHUB_ENV
        echo "ZIP_NAME=${ZIP_FILENAME}" >> $GITHUB_ENV
    else
        echo "[-] Build Failed."
        exit 1
    fi
}

if [ "$TARGET_OS" == "miui" ] || [ "$TARGET_OS" == "both" ]; then
    build_target "miui"
fi
