#!/bin/bash
# 'set -euo pipefail' HATA DIYA HAI taaki silent crash hoke build stock na ban jaye!
KERNEL_SRC="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "━━━ [1/4] Patching GPU OPP Table (Adreno 650) ━━━"
python3 "${SCRIPT_DIR}/apply-gpu-opp.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi" || echo "⚠️ GPU Script issue, continuing build..."
echo ""

echo "━━━ [2/4] Patching CPU Prime Core Cap ━━━"
python3 "${SCRIPT_DIR}/apply-cpu-cap.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi" || echo "⚠️ CPU Script issue, continuing build..."
echo ""

echo "━━━ [3/4] Patching EAS Energy Model ━━━"
python3 "${SCRIPT_DIR}/apply-eas-tuning.py" "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi" || echo "⚠️ EAS Script issue, continuing build..."
echo ""

echo "━━━ [4/4] Forcing EXTREME++ Name & ROOT (SukiSU) in ALL munch configs ━━━"
# Dev script jo bhi config use kare, hum sabme Root ghusa denge!
find "${KERNEL_SRC}/arch/arm64/configs" "${KERNEL_SRC}/arch/arm64/configs/vendor" -type f -name "*munch*" 2>/dev/null | while read -r DEFCONFIG; do
  echo "💉 Injecting into: $DEFCONFIG"
  
  # Set Kernel Name
  if grep -q "CONFIG_LOCALVERSION=" "$DEFCONFIG"; then
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-EXTREME++HyperOS"/' "$DEFCONFIG"
  else
    echo 'CONFIG_LOCALVERSION="-EXTREME++HyperOS"' >> "$DEFCONFIG"
  fi

  # Force SukiSU Root
  sed -i '/CONFIG_KSU/d' "$DEFCONFIG" || true
  echo "CONFIG_KSU=y" >> "$DEFCONFIG"
  echo "CONFIG_KSU_SUSFS=y" >> "$DEFCONFIG"
done

echo "✅ Kernel name & Root forced successfully!"
exit 0
