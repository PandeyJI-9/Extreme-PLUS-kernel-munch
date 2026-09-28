#!/bin/bash
set -euo pipefail
KERNEL_SRC="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "━━━ [1/4] Patching GPU OPP Table (Adreno 650) ━━━"
python3 "${SCRIPT_DIR}/apply-gpu-opp.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi"
echo ""

echo "━━━ [2/4] Patching CPU Prime Core Cap ━━━"
python3 "${SCRIPT_DIR}/apply-cpu-cap.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi"
echo ""

echo "━━━ [3/4] Patching EAS Energy Model ━━━"
python3 "${SCRIPT_DIR}/apply-eas-tuning.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi"
echo ""

echo "━━━ [4/4] Setting kernel version string ━━━"
DEFCONFIG="${KERNEL_SRC}/arch/arm64/configs/munch_defconfig"
if [ -f "$DEFCONFIG" ]; then
  if grep -q "CONFIG_LOCALVERSION=" "$DEFCONFIG"; then
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-EXTREME++GAMING"/' "$DEFCONFIG"
  else
    echo 'CONFIG_LOCALVERSION="-EXTREME++GAMING"' >> "$DEFCONFIG"
  fi
  echo "✅ Kernel name set: EXTREME++GAMING"
fi
