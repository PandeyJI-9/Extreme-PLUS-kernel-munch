#!/usr/bin/env python3
import sys
import re

def find_block_end(text, start_idx):
    depth = 0
    i = start_idx
    while i < len(text):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
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

def patch(path):
    try:
        with open(path, 'r') as f:
            text = f.read()
    except FileNotFoundError:
        print(f"⚠️️ ERROR: File not found -> {path}")
        return True

    if '670000000' in text and '150000000' in text:
        print("✅ GPU OPP table already patched — skipping")
        return True

    match = re.search(r'(\s*)gpu_opp_table:\s*gpu-opp-table\s*\{', text)
    if not match:
        print("⚠️ ERROR: gpu_opp_table block not found in " + path)
        return True

    block_start = match.start()
    brace_pos = text.index('{', match.start())
    block_end = find_block_end(text, brace_pos)

    if block_end == -1:
        print("⚠️ ERROR: Could not find closing of gpu_opp_table block")
        return True

    text = text[:block_start] + GPU_OPP_TABLE + text[block_end:]
    text = re.sub(r'qcom,initial-pwrlevel\s*=\s*<\d+>', 'qcom,initial-pwrlevel = <6>', text)

    with open(path, 'w') as f:
        f.write(text)
        
    print("✅ GPU OPP table replaced: 10 frequencies (150–670 MHz)")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(0)
    sys.exit(0 if patch(sys.argv[1]) else 0)
