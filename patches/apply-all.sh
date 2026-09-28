#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  EXTREME++GAMING — Master Patch Script
#  SM8250-AC (Snapdragon 870) | POCO F4 (munch)
# ═══════════════════════════════════════════════════════════════
#
#  Usage:  bash apply-all.sh <kernel-source-dir>
#
#  Applies:
#    [1] GPU OPP Table   → 10 custom frequencies (150–670 MHz)
#    [2] CPU Prime Cap   → CPU7 max 3187 → 3000 MHz
#    [3] Kernel Name     → CONFIG_LOCALVERSION="-EXTREME++GAMING"
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

KERNEL_SRC="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║     EXTREME++GAMING  Kernel Patcher       ║"
echo "  ║     SM8250-AC  |  POCO F4  (munch)        ║"
echo "  ╚═══════════════════════════════════════════╝"
echo ""

# ── [1/3] GPU OPP Table ──────────────────────────────────────
echo "━━━ [1/3] Patching GPU OPP Table (Adreno 650) ━━━"
python3 "${SCRIPT_DIR}/apply-gpu-opp.py" \
  "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi"
echo ""

# ── [2/3] CPU Prime Core Cap ─────────────────────────────────
echo "━━━ [2/3] Patching CPU Prime Core Cap ━━━"
python3 "${SCRIPT_DIR}/apply-cpu-cap.py" \
  "${KERNEL_SRC}/arch/arm64/boot/dts/vendor/qcom/kona.dtsi"
echo ""

# ── [3/3] Kernel Name ────────────────────────────────────────
echo "━━━ [3/3] Setting kernel version string ━━━"
DEFCONFIG="${KERNEL_SRC}/arch/arm64/configs/munch_defconfig"
if [ -f "$DEFCONFIG" ]; then
  if grep -q "CONFIG_LOCALVERSION=" "$DEFCONFIG"; then
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-EXTREME++GAMING"/' "$DEFCONFIG"
  else
    echo 'CONFIG_LOCALVERSION="-EXTREME++GAMING"' >> "$DEFCONFIG"
  fi
  echo "✅ Kernel name set: EXTREME++GAMING"
else
  echo "⚠️  Defconfig not found at: $DEFCONFIG"
fi

echo ""
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║    ✅  All patches applied successfully!  ║"
echo "  ╚═══════════════════════════════════════════╝"
echo ""
