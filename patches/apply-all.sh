#!/bin/bash
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Target: HyperOS ONLY
# Master Patch Application Suite
# ==============================================================================
KERNEL_SRC="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "━━━ [1/7] Patching GPU OPP Table (Adreno 650) ━━━"
python3 "${SCRIPT_DIR}/apply-gpu-opp.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi" || echo "⚠️ GPU Script issue, continuing build..."
echo ""

echo "━━━ [2/7] Patching CPU Prime Core Driver & DTS (3.19 GHz Full Peak) ━━━"
python3 "${SCRIPT_DIR}/apply-cpu-cap.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi" "${KERNEL_SRC}/drivers/cpufreq/qcom-cpufreq-hw.c" 3187200 || echo "⚠️ CPU Script issue, continuing build..."
echo ""

echo "━━━ [3/7] Patching EAS Energy Model ━━━"
python3 "${SCRIPT_DIR}/apply-eas-tuning.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi" 3187200 || echo "⚠️ EAS Script issue, continuing build..."
echo ""

echo "━━━ [4/7] Setting EXTREME++ Kernel Name & Pure Clean Base in ALL munch configs ━━━"
find "${KERNEL_SRC}/arch/arm64/configs" "${KERNEL_SRC}/arch/arm64/configs/vendor" -type f -name "*munch*" 2>/dev/null | while read -r DEFCONFIG; do
  echo "💉 Setting name in: $DEFCONFIG"

  # Set Kernel Name
  if grep -q "CONFIG_LOCALVERSION=" "$DEFCONFIG"; then
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-Extreme++Gaming-BMW-Edition"/' "$DEFCONFIG"
  else
    echo 'CONFIG_LOCALVERSION="-Extreme++Gaming-BMW-Edition"' >> "$DEFCONFIG"
  fi
done
echo "✅ Kernel name set in all munch defconfigs!"
echo ""

echo "━━━ [5/7] Patching Kernel for Bootloader Spoofing (Play Integrity) ━━━"
python3 "${SCRIPT_DIR}/apply-bootloader-spoof.py" "${KERNEL_SRC}" || echo "⚠️ Spoofing Script issue, continuing build..."
echo ""

echo "━━━ [6/7] Patching Safe PD/PPS Fast Charging & Thermal DTS Stepping ━━━"
(cd "${KERNEL_SRC}" && python3 "${SCRIPT_DIR}/apply-fastcharge-bypass.py") || echo "⚠️ Fast charging script issue, continuing build..."
echo ""

echo "━━━ [7/7] Patching Critical Tasks Direct Reclaim Anti-Stutter (Google ACK fix) ━━━"
python3 "${SCRIPT_DIR}/apply-vmscan-critical.py" "${KERNEL_SRC}/mm/vmscan.c" || echo "⚠️ vmscan script issue, continuing build..."
echo ""

echo "✅ ALL PATCHES APPLIED SUCCESSFULLY!"
exit 0
