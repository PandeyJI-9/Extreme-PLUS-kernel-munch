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
# 4. Native GPU FakeDreamer 10-Step OPP Table (150MHz - 670MHz UV)
# ------------------------------------------
echo "[*] Natively Applying FakeDreamer Adreno 650 10-Step OPP Table (150MHz - 670MHz UV)..."
python3 -c '
import re

path = "arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi"
with open(path, "r") as f:
    text = f.read()

OPP_TABLE = """\tgpu_opp_table: gpu-opp-table {
\t\tcompatible = "operating-points-v2";
\t\topp-670000000 {
\t\t\topp-hz = /bits/ 64 <670000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L2>;
\t\t};
\t\topp-587000000 {
\t\t\topp-hz = /bits/ 64 <587000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L1>;
\t\t};
\t\topp-525000000 {
\t\t\topp-hz = /bits/ 64 <525000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>;
\t\t};
\t\topp-490000000 {
\t\t\topp-hz = /bits/ 64 <490000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>;
\t\t};
\t\topp-441000000 {
\t\t\topp-hz = /bits/ 64 <441000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};
\t\topp-400000000 {
\t\t\topp-hz = /bits/ 64 <400000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};
\t\topp-305000000 {
\t\t\topp-hz = /bits/ 64 <305000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>;
\t\t};
\t\topp-250000000 {
\t\t\topp-hz = /bits/ 64 <250000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};
\t\topp-200000000 {
\t\t\topp-hz = /bits/ 64 <200000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>;
\t\t};
\t\topp-150000000 {
\t\t\topp-hz = /bits/ 64 <150000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>;
\t\t};
\t};"""

# Replace gpu_opp_table
pattern = r"\tgpu_opp_table:\s*gpu-opp-table\s*\{[^}]*opp-480000000[^}]*\}[^}]*opp-381000000[^}]*\}[^}]*opp-290000000[^}]*\}[^}]*\};"
m = re.search(pattern, text)
if m:
    text = text[:m.start()] + OPP_TABLE + text[m.end():]
elif "opp-670000000" not in text:
    idx = text.find("gpu_opp_table: gpu-opp-table")
    if idx != -1:
        end_idx = text.find("};", idx)
        if end_idx != -1:
            text = text[:idx] + OPP_TABLE.strip() + text[end_idx+2:]

# Set initial pwrlevel to 6 (400 MHz default)
text = re.sub(r"qcom,initial-pwrlevel\s*=\s*<\d+>;", "qcom,initial-pwrlevel = <6>;", text)

with open(path, "w") as f:
    f.write(text)

assert "150000000" in text and "670000000" in text, "GPU OPP injection verification failed!"
print("✅ GPU OPP 10-step Table natively injected!")
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
# 8. Full HyperOS / MIUI Config Injection (AstideLabs standard)
# ------------------------------------------
echo "[*] Injecting Full HyperOS / MIUI Subsystem Configs..."
scripts/config --file "${OUT_DIR}/.config" -e BBG
scripts/config --file "${OUT_DIR}/.config" --set-str LOCALVERSION "-EXTREME++GAMING_Hyperos"

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
## end boot install
EOF

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
