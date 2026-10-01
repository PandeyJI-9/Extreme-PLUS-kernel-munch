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
\t\topp-441600000 {
\t\t\topp-hz = /bits/ 64 <441600000>;
\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;
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

    if '670000000' in text and '150000000' in text and '441600000' in text:
        print("✅ GPU OPP table already patched — skipping")
        return True

    table_v1_pattern = r'(\s*)gpu_opp_table:\s*gpu-opp-table\s*\{'
    table_v2_pattern = r'(\s*)gpu_opp_table_v2:\s*gpu-opp-table_v2\s*\{'

    match1 = re.search(table_v1_pattern, text)
    if match1:
        brace_pos = text.index('{', match1.start())
        block_end = find_block_end(text, brace_pos)
        if block_end != -1:
            text = text[:match1.start()] + GPU_OPP_TABLE + text[block_end:]
            print("✅ Replaced gpu_opp_table in " + path)

    match2 = re.search(table_v2_pattern, text)
    if match2:
        brace_pos = text.index('{', match2.start())
        block_end = find_block_end(text, brace_pos)
        if block_end != -1:
            opp_v2 = GPU_OPP_TABLE.replace("gpu_opp_table: gpu-opp-table", "gpu_opp_table_v2: gpu-opp-table_v2")
            text = text[:match2.start()] + opp_v2 + text[block_end:]
            print("✅ Replaced gpu_opp_table_v2 in " + path)

    text = re.sub(r'qcom,initial-pwrlevel\s*=\s*<\d+>', 'qcom,initial-pwrlevel = <6>', text)

    with open(path, 'w') as f:
        f.write(text)
        
    print("✅ GPU OPP patching completed for: " + path)
    return True

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) >= 2 else "arch/arm64/boot/dts/vendor/qcom/kona-gpu.dtsi"
    sys.exit(0 if patch(target) else 1)
