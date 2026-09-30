#!/bin/bash
# ==========================================
# EXTREME++GAMING CUSTOM KERNEL ENGINE
# Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | OS: HyperOS ONLY
# ==========================================

set -e

if [ -z "$1" ]; then
    echo "[!] Error: No device specified."
    echo "Usage: $0 <device_name> [ksu]"
    exit 1
fi

DEVICE_NAME="$1"
DEFCONFIG="${DEVICE_NAME}_defconfig"
DEFCONFIG_PATH="arch/arm64/configs/${DEFCONFIG}"

ENABLE_KSU=0
if [ "$2" == "ksu" ]; then
    ENABLE_KSU=1
fi

KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out_hyperos"
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
# SukiSU Ultra Setup (Replaced Dev's ReSukiSU)
# ==========================================
if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "==========================================="
    echo " [*] Initializing SukiSU Ultra (Root)"
    echo "==========================================="
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s main
    echo "[+] SukiSU Ultra setup finished."
fi

# ==========================================
# Baseband-guard Setup
# ==========================================
echo "==========================================="
echo " [*] Initializing Baseband-guard Setup"
echo "==========================================="
wget -O- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig

# ==========================================
# Compilation Setup
# ==========================================
echo "==========================================="
echo " Starting EXTREME++ Compilation for ${DEVICE_NAME} (HyperOS)"
echo "==========================================="

MAKE_OPTS=(
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

# --- HyperOS/MIUI Display Patches ---
DTS_SOURCE="arch/arm64/boot/dts/vendor/qcom"
DTS_BACKUP=".dts.bak.hyperos"
echo "[*] Applying HyperOS Display Patches..."
cp -a "${DTS_SOURCE}" "${DTS_BACKUP}"

sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j1s* || true
sed -i 's/<154>/<1537>/g' ${DTS_SOURCE}/dsi-panel-j2* || true
sed -i 's/<155>/<1544>/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi || true
sed -i 's/<155>/<1545>/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi || true
sed -i 's/<155>/<1546>/g' ${DTS_SOURCE}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi || true
sed -i 's/<155>/<1546>/g' ${DTS_SOURCE}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-j11-38-08-0a-fhd-cmd.dtsi || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-j3s-37-02-0a-dsc-video.dtsi || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-k11a-38-08-0a-dsc-cmd.dtsi || true
sed -i 's/<70>/<695>/g' ${DTS_SOURCE}/dsi-panel-l11r-38-08-0a-dsc-cmd.dtsi || true
sed -i 's/<71>/<710>/g' ${DTS_SOURCE}/dsi-panel-j1s* || true
sed -i 's/<71>/<710>/g' ${DTS_SOURCE}/dsi-panel-j2* || true
sed -i 's/\/\/ mi,mdss-dsi-pan-enable-smart-fps/mi,mdss-dsi-pan-enable-smart-fps/g' ${DTS_SOURCE}/dsi-panel* || true
sed -i 's/\/\/ mi,mdss-dsi-smart-fps-max_framerate/mi,mdss-dsi-smart-fps-max_framerate/g' ${DTS_SOURCE}/dsi-panel* || true
sed -i 's/\/\/ qcom,mdss-dsi-pan-enable-smart-fps/qcom,mdss-dsi-pan-enable-smart-fps/g' ${DTS_SOURCE}/dsi-panel* || true
sed -i 's/qcom,mdss-dsi-qsync-min-refresh-rate/\/\/qcom,mdss-dsi-qsync-min-refresh-rate/g' ${DTS_SOURCE}/dsi-panel* || true

echo "[*] Making defconfig: ${DEFCONFIG}..."
make "${MAKE_OPTS[@]}" "${DEFCONFIG}"

# --- Configurations ---
echo "[*] Injecting HyperOS & Baseband configurations..."
scripts/config --file "${OUT_DIR}/.config" -e BBG
scripts/config --file "${OUT_DIR}/.config" \
    --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
    -e PERF_CRITICAL_RT_TASK -e SF_BINDER -e OVERLAY_FS -e MIGT \
    -e MIGT_ENERGY_MODEL -e MIHW -e PACKAGE_RUNTIME_INFO -e BINDER_OPT \
    -e KPERFEVENTS -e PERF_HUMANTASK -d LTO_CLANG -e LTO_NONE \
    -d SHADOW_CALL_STACK -e XIAOMI_MIUI -d MI_MEMORY_SYSFS \
    -e TASK_DELAY_ACCT -e MIUI_ZRAM_MEMORY_TRACKING -e PERF_HELPER \
    -e BOOTUP_RECLAIM -e MI_RECLAIM -e RTMM -e MILLET_CGROUP \
    -e MILLET_SIG -e MILLET_BINDER -e MILLET_PKG -e MILLET_BINDER_GKI \
    -e MILLET_CORE -e MILLET_HS -e BINDER_PRIO -d REKERNEL -d REKERNEL_NETWORK

if [ "$ENABLE_KSU" -eq 1 ]; then
    echo "[*] Injecting SukiSU configurations..."
    scripts/config --file "${OUT_DIR}/.config" -e KSU -e THREAD_INFO_IN_TASK -e KSU_SUSFS
fi

make "${MAKE_OPTS[@]}" olddefconfig

# --- Compile ---
echo "[*] Building kernel & DTBs..."
make "${MAKE_OPTS[@]}" 
make "${MAKE_OPTS[@]}" dtbs

# Restore DTS backup
rm -rf "${DTS_SOURCE}"
mv "${DTS_BACKUP}" "${DTS_SOURCE}"

# ==========================================
# Custom AnyKernel3 Setup (PandeyJI-9 Exclusive)
# ==========================================
if [ -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "[+] Build Successful! Packaging..."
    
    rm -rf anykernel
    # Cloning original osmosis repo, no AstideLabs branding
    git clone https://github.com/osm0sis/AnyKernel3 --depth=1 anykernel
    
    # Overwriting Anykernel.sh with your custom strings
    cat > anykernel/anykernel.sh << 'EOF'
properties() { '
kernel.string=Extreme Plus Gaming On Hyper os
do.devicecheck=0
do.modules=0
do.cleanup=1
do.cleanuponabort=0
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

# Custom EXTREME++ DTBO Flash Logic
if [ -f $home/dtbo.img ]; then
  ui_print "- Flashing 2.8GHz/150MHz UV DTBO...";
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

    # Copy files
    cp "${OUT_DIR}/arch/arm64/boot/Image" anykernel/
    cp "${OUT_DIR}/arch/arm64/boot/dtb" anykernel/ 2>/dev/null || true
    if [ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
        cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" anykernel/
    fi
    
    # Zip creation
    KSU_ZIP_STR="NoRoot"
    if [ "$ENABLE_KSU" -eq 1 ]; then
        KSU_ZIP_STR="SukiSU-Ultra"
    fi
    
    ZIP_FILENAME="EXTREME++HyperOS_${DEVICE_NAME}_${KSU_ZIP_STR}_$(date +'%Y%m%d').zip"
    
    pushd anykernel > /dev/null
    zip -r9 "$ZIP_FILENAME" ./* -x .git .gitignore out/ ./*.zip > /dev/null
    mv "$ZIP_FILENAME" ../
    popd > /dev/null
    
    echo "ZIP_PATH=${KERNEL_DIR}/${ZIP_FILENAME}" >> $GITHUB_ENV
    echo "ZIP_NAME=${ZIP_FILENAME}" >> $GITHUB_ENV
    echo "[+] Done! ZIP created: $ZIP_FILENAME"
else
    echo "[-] Build Failed. Kernel Image not found."
    exit 1
fi
