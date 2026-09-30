#!/bin/bash
# ==========================================
# EXTREME++GAMING CUSTOM KERNEL ENGINE
# Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Target: HyperOS ONLY
# ==========================================

# Fail on any error and print the line number
set -e
trap 'echo "❌ [ERROR] Script failed on line $LINENO"; exit 1' ERR

if [ -z "$1" ]; then
    echo "[!] Error: No device specified."
    echo "Usage: $0 <device_name> [ksu]"
    exit 1
fi

DEVICE_NAME="$1"
DEFCONFIG="${DEVICE_NAME}_defconfig"
ENABLE_KSU=0

if [ "$2" == "ksu" ]; then
    ENABLE_KSU=1
fi

# Set absolute paths to avoid directory confusion
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

echo "[*] Cleaning previous builds and ensuring pure workspace..."
rm -rf "${OUT_DIR}" anykernel
mkdir -p "${OUT_DIR}"
# Nuke any prebuilt crap that might ruin our 2.8GHz/UV injection
find . -type f \( -name "dtbo.img" -o -name "Image" -o -name "Image.gz" \) -delete

# ------------------------------------------
# 1. Baseband & Network Guard (Strict Patch)
# ------------------------------------------
echo "[*] Injecting Baseband-guard Setup (Critical for SIM)..."
if ! wget -qO- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash; then
    echo "❌ [ERROR] Baseband-guard download failed!"
    exit 1
fi

if grep -q "selinux,baseband_guard" security/Kconfig; then
    echo "[+] Baseband-guard already in Kconfig."
else
    sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
    if ! grep -q "selinux,baseband_guard" security/Kconfig; then
        echo "⚠️ [WARNING] Strict baseband patch failed, trying fallback..."
        sed -i 's/default "selinux"/default "selinux,baseband_guard"/g' security/Kconfig
    fi
fi

# ------------------------------------------
# 2. SukiSU Ultra (Root) Script Download
# ------------------------------------------
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "[*] Injecting SukiSU Ultra Source..."
    if ! curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s main; then
        echo "❌ [ERROR] SukiSU script execution failed!"
        exit 1
    fi
    echo "[+] SukiSU Ultra Source Downloaded."
fi

# ------------------------------------------
# 3. HyperOS Display Optimizations
# ------------------------------------------
DTS_SOURCE="arch/arm64/boot/dts/vendor/qcom"
echo "[*] Applying HyperOS Display Optimizations..."
sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j1s* 2>/dev/null || true
sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j2* 2>/dev/null || true
sed -i 's/<155>/<1544>/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi 2>/dev/null || true
sed -i 's/<155>/<1545>/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi 2>/dev/null || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi 2>/dev/null || true
sed -i 's/<71>/<710>/g' ${DTS_SOURCE}/dsi-panel-j1s* 2>/dev/null || true
sed -i 's/120 90 60/120 90 60 50 30/g' ${DTS_SOURCE}/dsi-panel-g7a-36-02-0c-dsc-video.dtsi 2>/dev/null || true

# ------------------------------------------
# 4. AGGRESSIVE CONFIG INJECTION (Fixes Root & HyperOS bugs)
# ------------------------------------------
echo "[*] Force-Injecting configs directly into source defconfig..."

# Agar SukiSU enabled hai toh usko directly source file me pel do
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "CONFIG_KSU=y" >> "arch/arm64/configs/${DEFCONFIG}"
    echo "CONFIG_KSU_SUSFS=y" >> "arch/arm64/configs/${DEFCONFIG}"
fi

# Force HyperOS & Baseband Guard configs
cat << 'EOF' >> "arch/arm64/configs/${DEFCONFIG}"
CONFIG_PERF_CRITICAL_RT_TASK=y
CONFIG_SF_BINDER=y
CONFIG_OVERLAY_FS=y
CONFIG_MIGT=y
CONFIG_MIGT_ENERGY_MODEL=y
CONFIG_MIHW=y
CONFIG_XIAOMI_MIUI=y
CONFIG_TASK_DELAY_ACCT=y
CONFIG_MIUI_ZRAM_MEMORY_TRACKING=y
CONFIG_PERF_HELPER=y
# CONFIG_LTO_CLANG is not set
CONFIG_LTO_NONE=y
# CONFIG_SHADOW_CALL_STACK is not set
EOF

MAKE_OPTS=(
    -j"$(nproc --all)"
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
make "${MAKE_OPTS[@]}" "${DEFCONFIG}"

# ------------------------------------------
# 5. Build Kernel Image & DTBO
# ------------------------------------------
echo "[*] Compiling Kernel Image..."
make "${MAKE_OPTS[@]}" Image

echo "[*] Compiling DTBs & DTBO (For 2.8GHz & GPU UV)..."
make "${MAKE_OPTS[@]}" dtbs

# ------------------------------------------
# 6. AnyKernel3 Setup (Strictly PandeyJI-9)
# ------------------------------------------
echo "[*] Cloning Pure AnyKernel3..."
git clone --depth=1 https://github.com/osm0sis/AnyKernel3 anykernel

echo "[*] Creating EXTREME++ anykernel.sh..."
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

# Robust DTBO Flasher
if [ -f $home/dtbo.img ]; then
  ui_print "- Flashing Extreme Plus Gaming DTBO (2.8GHz/UV)...";
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
    ui_print "- ❌ WARNING: DTBO partition not found! 2.8GHz might not apply.";
  fi
fi
EOF

# ------------------------------------------
# 7. Validation & ZIP Packaging
# ------------------------------------------
echo "[*] Verifying compiled files..."

if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "❌ [ERROR] Kernel Image did NOT compile!"
    exit 1
fi
cp "${OUT_DIR}/arch/arm64/boot/Image" anykernel/
echo "[+] Kernel Image copied."

if [ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" anykernel/
    echo "[+] DTBO Image copied directly."
else
    echo "⚠️ dtbo.img not found directly. Attempting to pack from .dtbo files..."
    if [ -f "scripts/dtc/libfdt/mkdtboimg.py" ]; then
        count=$(ls -1 ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtbo 2>/dev/null | wc -l)
        if [ "$count" != "0" ]; then
             python3 scripts/dtc/libfdt/mkdtboimg.py create anykernel/dtbo.img --page_size=4096 ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtbo
             echo "[+] DTBO packed successfully from DTB fragments."
        else
             echo "❌ [ERROR] No .dtbo fragments found! Your 2.8GHz patch failed to compile into DTB."
             exit 1
        fi
    else
        echo "❌ [ERROR] mkdtboimg.py script is missing from source!"
        exit 1
    fi
fi

echo "[*] Zipping EXTREME++ Kernel..."
cd anykernel
KSU_TAG="NoRoot"
[ "$ENABLE_KSU" -eq 1 ] && KSU_TAG="SukiSU"
ZIP_NAME="EXTREME_HyperOS_munch_${KSU_TAG}_$(date +'%d%b%Y_%H%M').zip"

rm -rf .git
zip -r9 "../${ZIP_NAME}" ./* -x .gitignore out/ ./*.zip > /dev/null
cd ..

echo "[+] =========================================="
echo "[+] SUCCESS! File ready: ${ZIP_NAME}"
echo "[+] =========================================="
