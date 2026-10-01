#!/bin/bash
# ==========================================
# EXTREME++GAMING CUSTOM KERNEL ENGINE
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
# 1. Baseband & Network Guard
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
# 2. RKSU (RootHide KernelSU) Setup
# ------------------------------------------
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "[*] Injecting RKSU (RootHide KernelSU) Source..."
    curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s main || true
    
    echo "[*] Applying Native Failsafe for RKSU Kconfigs..."
    grep -q "KernelSU" drivers/Kconfig || echo 'source "drivers/KernelSU/Kconfig"' >> drivers/Kconfig
    grep -q "KernelSU" drivers/Makefile || echo 'obj-$(CONFIG_KSU) += KernelSU/' >> drivers/Makefile
fi

# ------------------------------------------
# 3. Compile Environment Setup
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
# 4. Safe Config Injection
# ------------------------------------------
echo "[*] Injecting Custom Configs Safely..."
scripts/config --file "${OUT_DIR}/.config" -e BBG

if [ "$ENABLE_KSU" -eq 1 ]; then
    scripts/config --file "${OUT_DIR}/.config" -e KPROBES -e HAVE_KPROBES -e KPROBE_EVENTS
    scripts/config --file "${OUT_DIR}/.config" -e KSU
fi

scripts/config --file "${OUT_DIR}/.config" \
    --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
    -e PERF_CRITICAL_RT_TASK -e SF_BINDER -e OVERLAY_FS -e MIGT \
    -e MIGT_ENERGY_MODEL -e MIHW -e XIAOMI_MIUI -e TASK_DELAY_ACCT \
    -e MIUI_ZRAM_MEMORY_TRACKING -e PERF_HELPER \
    -e LTO_NONE -d LTO_CLANG -d LTO_CLANG_THIN -d CFI_CLANG

make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" olddefconfig

# 🔥 THE ULTIMATE KSU FIX: Ensuring CONFIG_KSU survives olddefconfig
if [ "$ENABLE_KSU" -eq 1 ]; then
    if ! grep -q "CONFIG_KSU=y" "${OUT_DIR}/.config"; then
        echo "[!] CONFIG_KSU was dropped by olddefconfig! Forcing it back into .config..."
        echo "CONFIG_KSU=y" >> "${OUT_DIR}/.config"
    fi
fi

# ------------------------------------------
# 5. Build Kernel Image & DTBO
# ------------------------------------------
echo "[*] Compiling Kernel Image..."
make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" Image

echo "[*] Compiling DTBs & DTBO..."
make -j"${TOTAL_CORES}" "${MAKE_OPTS[@]}" dtbs

# ------------------------------------------
# 6. AnyKernel3 Setup
# ------------------------------------------
echo "[*] Cloning Pure AnyKernel3..."
git clone --depth=1 https://github.com/osm0sis/AnyKernel3 anykernel

cat > anykernel/anykernel.sh << 'EOF'
properties() { '
kernel.string=Extreme Plus Gaming On Hyper os
do.devicecheck=0
do.modules=0
do.cleanup=1
device.name1=munch
device.name2=POCO F4
supported.versions=13-17
'; }

BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;
. tools/ak3-core.sh;
dump_boot;
write_boot;

if [ -f $home/dtbo.img ]; then
  ui_print "- Flashing Extreme Plus Gaming DTBO...";
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

# ------------------------------------------
# 7. Packaging: EXACT DTB MATCH ONLY
# ------------------------------------------
echo "[*] Verifying compiled files..."

if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "❌ [ERROR] Kernel Image did NOT compile!"
    exit 1
fi
cp "${OUT_DIR}/arch/arm64/boot/Image" anykernel/
echo "[+] Kernel Image copied."

MUNCH_DTB=$(find ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/ -name "*munch*.dtb" | head -n 1)
if [ -n "$MUNCH_DTB" ] && [ -f "$MUNCH_DTB" ]; then
    cp "$MUNCH_DTB" anykernel/dtb
    echo "[+] DTB (Munch) successfully packed."
else
    KONA_DTB=$(find ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/ -name "*kona-v2.1*.dtb" | head -n 1)
    if [ -n "$KONA_DTB" ] && [ -f "$KONA_DTB" ]; then
        cp "$KONA_DTB" anykernel/dtb
        echo "[+] DTB (Kona v2.1) packed as fallback."
    else
        echo "❌ [ERROR] Failed to find ANY suitable DTB!"
        exit 1
    fi
fi

if [ ! -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
    if [ ! -f "scripts/dtc/libfdt/mkdtboimg.py" ]; then
        mkdir -p scripts/dtc/libfdt/
        curl -sL -o scripts/dtc/libfdt/mkdtboimg.py https://raw.githubusercontent.com/LineageOS/android_system_libufdt/lineage-19.1/utils/src/mkdtboimg.py
    fi
    count=$(ls -1 ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtbo 2>/dev/null | wc -l || echo "0")
    if [ "$count" != "0" ]; then
        python3 scripts/dtc/libfdt/mkdtboimg.py create anykernel/dtbo.img --page_size=4096 ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtbo
    else
        echo "❌ [ERROR] No .dtbo fragments found!"
        exit 1
    fi
else
    cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" anykernel/
fi

# ------------------------------------------
# 8. Final Zip Creation
# ------------------------------------------
echo "[*] Zipping EXTREME++ Kernel..."
cd anykernel
KSU_TAG="NoRoot"
[ "$ENABLE_KSU" -eq 1 ] && KSU_TAG="RKSU"
ZIP_NAME="EXTREME_HyperOS_munch_${KSU_TAG}_$(date +'%d%b%Y_%H%M').zip"

rm -rf .git
zip -r9 "../${ZIP_NAME}" ./* -x .gitignore out/ ./*.zip > /dev/null
cd ..

echo "[+] =========================================="
echo "[+] SUCCESS! File ready: ${ZIP_NAME}"
echo "[+] =========================================="
