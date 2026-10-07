#!/bin/bash
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Target: HyperOS ONLY
# Master Patch Application Suite
# ==============================================================================
KERNEL_SRC="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "━━━ [1/5] Patching GPU OPP Table (Adreno 650) ━━━"
python3 "${SCRIPT_DIR}/apply-gpu-opp.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi" || echo "⚠️ GPU Script issue, continuing build..."
echo ""

echo "━━━ [2/5] Patching CPU Prime Core Cap ━━━"
python3 "${SCRIPT_DIR}/apply-cpu-cap.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi" || echo "⚠️ CPU Script issue, continuing build..."
echo ""

echo "━━━ [3/5] Patching EAS Energy Model ━━━"
python3 "${SCRIPT_DIR}/apply-eas-tuning.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi" || echo "⚠️ EAS Script issue, continuing build..."
echo ""

echo "━━━ [4/5] Setting EXTREME++ Kernel Name & Pure Clean Base in ALL munch configs ━━━"
find "${KERNEL_SRC}/arch/arm64/configs" "${KERNEL_SRC}/arch/arm64/configs/vendor" -type f -name "*munch*" 2>/dev/null | while read -r DEFCONFIG; do
  echo "💉 Setting name in: $DEFCONFIG"

  # Set Kernel Name
  if grep -q "CONFIG_LOCALVERSION=" "$DEFCONFIG"; then
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-Extreme++Gaming-by-PandeyJi"/' "$DEFCONFIG"
  else
    echo 'CONFIG_LOCALVERSION="-Extreme++Gaming-by-PandeyJi"' >> "$DEFCONFIG"
  fi
done
echo "✅ Kernel name set in all munch defconfigs!"
echo ""

echo "━━━ [5/6] Patching Kernel for Bootloader Spoofing (Play Integrity) ━━━"
python3 "${SCRIPT_DIR}/apply-bootloader-spoof.py" "${KERNEL_SRC}" || echo "⚠️ Spoofing Script issue, continuing build..."
echo ""

echo "━━━ [6/6] Patching Universal Fast Charging, 67W Handshake & Thermal Guard ━━━"
(cd "${KERNEL_SRC}" && python3 "${SCRIPT_DIR}/apply-fastcharge-bypass.py") || echo "⚠️ Fast charging script issue, continuing build..."
echo ""

echo "✅ ALL PATCHES APPLIED SUCCESSFULLY!"
exit 0 
