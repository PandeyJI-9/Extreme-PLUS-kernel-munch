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

echo "[*] Cleaning previous builds..."
rm -rf "${OUT_DIR}" anykernel
mkdir -p "${OUT_DIR}"
find . -type f \( -name "dtbo.img" -o -name "Image" -o -name "Image.gz" \) -delete

# ------------------------------------------
# 1. Baseband & Network Guard
# ------------------------------------------
echo "[*] Injecting Baseband-guard Setup..."
if ! wget -qO- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash; then
    echo "❌ [ERROR] Baseband-guard download failed!"
    exit 1
fi

if ! grep -q "selinux,baseband_guard" security/Kconfig; then
    sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
    if ! grep -q "selinux,baseband_guard" security/Kconfig; then
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
fi

# ==========================================
# (TOUCH BUG FIXED: HATA DIYA DISPLAY PATCHES KA KACHRA!)
# ==========================================

# ------------------------------------------
# 3. AGGRESSIVE CONFIG INJECTION
# ------------------------------------------
echo "[*] Force-Injecting configs directly into source defconfig..."

if [ "$ENABLE_KSU" -eq 1 ]; then
    # [FIX] Added KPROBES explicitly so SukiSU works!
    cat << 'EOF' >> "arch/arm64/configs/${DEFCONFIG}"
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_KPROBE_EVENTS=y
EOF
fi

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
# 4. Build Kernel Image, DTB & DTBO
# ------------------------------------------
echo "[*] Compiling Kernel Image..."
make "${MAKE_OPTS[@]}" Image

echo "[*] Compiling DTBs & DTBO (For CPU & GPU patches)..."
make "${MAKE_OPTS[@]}" dtbs

# ------------------------------------------
# 5. AnyKernel3 Setup
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
# 6. Packaging: DTB, DTBO, & Image (THE ROOT & CLOCK FIX)
# ------------------------------------------
echo "[*] Verifying compiled files..."

if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "❌ [ERROR] Kernel Image did NOT compile!"
    exit 1
fi
cp "${OUT_DIR}/arch/arm64/boot/Image" anykernel/
echo "[+] Kernel Image copied."

# Main DTB for CPU/GPU Frequencies
echo "[*] Copying main DTB for CPU/GPU Frequencies..."
cat ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtb > anykernel/dtb
if [ -s anykernel/dtb ]; then
    echo "[+] DTB successfully packed."
else
    echo "❌ [ERROR] Failed to compile main DTB!"
    exit 1
fi

# DTBO File Tool Fix
if [ ! -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
    echo "⚠️ dtbo.img not found. Packing from .dtbo files..."
    if [ ! -f "scripts/dtc/libfdt/mkdtboimg.py" ]; then
        echo "[*] Downloading missing mkdtboimg.py tool..."
        mkdir -p scripts/dtc/libfdt/
        curl -sL -o scripts/dtc/libfdt/mkdtboimg.py https://raw.githubusercontent.com/LineageOS/android_system_libufdt/lineage-19.1/utils/src/mkdtboimg.py
    fi
    count=$(ls -1 ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtbo 2>/dev/null | wc -l)
    if [ "$count" != "0" ]; then
        python3 scripts/dtc/libfdt/mkdtboimg.py create anykernel/dtbo.img --page_size=4096 ${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom/*.dtbo
        echo "[+] DTBO packed successfully from fragments."
    else
        echo "❌ [ERROR] No .dtbo fragments found!"
        exit 1
    fi
else
    cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" anykernel/
    echo "[+] DTBO Image copied directly."
fi

# ------------------------------------------
# 7. Final Zip Creation
# ------------------------------------------
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
