#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
 EXTREME++GAMING — GPU OPP Patch
 Adreno 650 | SM8250-AC (Snapdragon 870) | POCO F4 (munch)
═══════════════════════════════════════════════════════════════

 Replaces the stock 3-entry GPU OPP table in kona-gpu.dtsi
 with a custom 10-frequency table optimised for thermals
 and battery life.

 STOCK TABLE (3 entries):
   480 MHz @ SVS_L1     ← removed (unnecessary heat)
   381 MHz @ SVS        ← removed
   290 MHz @ LOW_SVS    ← replaced

 NEW TABLE (10 entries, highest → lowest):
   670 MHz @ NOM        ← stock peak (gaming)
   587 MHz @ SVS_L2     ← heavy 3D / camera viewfinder
   525 MHz @ SVS_L1     ← moderate 3D gaming
   490 MHz @ SVS_L1     ← UI compositor transitions
   441 MHz @ SVS        ← 120Hz scrolling, video playback
   400 MHz @ SVS        ← standard 120Hz frame pacing
   305 MHz @ LOW_SVS    ← light UI, 1080p video
   250 MHz @ LOW_SVS    ← static reading, basic 60Hz idle
   200 MHz @ MIN_SVS    ← ambient display background render
   150 MHz @ MIN_SVS    ← deep idle, AOD, screen-off compositing

 Voltage levels use Qualcomm's RPMH regulator level macros.
 These are NOT raw millivolts — the PMIC translates them to
 actual silicon-safe voltage corners. All values are within
 Qualcomm's published safe operating range for Adreno 650.
═══════════════════════════════════════════════════════════════
"""
import sys
import re


def find_block_end(text, start_idx):
    """Find the position after the matching '};' for a DTS block."""
    depth = 0
    i = start_idx
    while i < len(text):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                # Consume optional whitespace + semicolon
                j = i + 1
                while j < len(text) and text[j] in ' \t\n':
                    j += 1
                if j < len(text) and text[j] == ';':
                    return j + 1
                return i + 1
        i += 1
    return -1


GPU_OPP_TABLE = """\tgpu_opp_table: gpu-opp-table {
\t\tcompatible = "operating-points-v2";

\t\t/* ═══ PEAK 3D: Intensive gaming, sustained max FPS ═══ */
\t\topp-670000000 {
\t\t\topp-hz = /bits/ 64 <670000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_NOM>;
\t\t};

\t\t/* ═══ HEAVY 3D: Camera viewfinder, 3D transitions ═══ */
\t\topp-587000000 {
\t\t\topp-hz = /bits/ 64 <587000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L2>;
\t\t};

\t\t/* ═══ MODERATE 3D: Medium gaming, live wallpapers ═══ */
\t\topp-525000000 {
\t\t\topp-hz = /bits/ 64 <525000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L1>;
\t\t};

\t\t/* ═══ ENHANCED 2D: Heavy UI compositor transitions ═══ */
\t\topp-490000000 {
\t\t\topp-hz = /bits/ 64 <490000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L1>;
\t\t};

\t\t/* ═══ SMOOTH 120HZ: Fluid scrolling, video playback ═══ */
\t\topp-441000000 {
\t\t\topp-hz = /bits/ 64 <441000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>;
\t\t};

\t\t/* ═══ STANDARD UI: 120Hz frame pacing, light 2D apps ═══ */
\t\topp-400000000 {
\t\t\topp-hz = /bits/ 64 <400000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>;
\t\t};

\t\t/* ═══ LIGHT UI: Basic scrolling, 1080p/4K video ═══ */
\t\topp-305000000 {
\t\t\topp-hz = /bits/ 64 <305000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};

\t\t/* ═══ LOW POWER: Static reading, basic 60Hz idle ═══ */
\t\topp-250000000 {
\t\t\topp-hz = /bits/ 64 <250000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
\t\t};

\t\t/* ═══ ULTRA-LOW: Background rendering, AOD prep ═══ */
\t\topp-200000000 {
\t\t\topp-hz = /bits/ 64 <200000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>;
\t\t};

\t\t/* ═══ DEEP IDLE: Ambient Display, screen-off compositing ═══ */
\t\topp-150000000 {
\t\t\topp-hz = /bits/ 64 <150000000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>;
\t\t};
\t};"""


def patch(path):
    text = open(path).read()

    # Check if already patched (has our full table)
    if '670000000' in text and '150000000' in text and '441000000' in text:
        print("✅ GPU OPP table already patched — skipping")
        return True

    # ── Find the gpu_opp_table block ──
    match = re.search(r'(\s*)gpu_opp_table:\s*gpu-opp-table\s*\{', text)
    if not match:
        print("ERROR: gpu_opp_table block not found in " + path, file=sys.stderr)
        return False

    block_start = match.start()
    # Find the opening brace
    brace_pos = text.index('{', match.start())
    block_end = find_block_end(text, brace_pos)

    if block_end == -1:
        print("ERROR: Could not find closing of gpu_opp_table block", file=sys.stderr)
        return False

    print(f"Found gpu_opp_table at chars {block_start}–{block_end}")
    print(f"Old table:\n{text[block_start:block_end][:200]}...")

    # ── Replace the entire block ──
    text = text[:block_start] + GPU_OPP_TABLE + text[block_end:]

    # ── Update initial-pwrlevel ──
    # 10 OPPs: index 0 = 670MHz (highest), index 9 = 150MHz (lowest)
    # Set default to index 6 = 305MHz (safe, efficient boot default)
    text = re.sub(
        r'qcom,initial-pwrlevel\s*=\s*<\d+>',
        'qcom,initial-pwrlevel = <6>',
        text
    )

    open(path, 'w').write(text)
    print("✅ GPU OPP table replaced: 10 frequencies (150–670 MHz)")
    print("✅ initial-pwrlevel set to 6 → boots at 305MHz")
    return True


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: apply-gpu-opp.py <path-to-kona-gpu.dtsi>")
        sys.exit(1)
    sys.exit(0 if patch(sys.argv[1]) else 1)
