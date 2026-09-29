import sys
lines = open("patches/apply-gpu-opp.py").read().split('\n')
new_lines = []

for i, line in enumerate(lines):
    if "opp-670000000 {" in lines[i-2] and "opp-microvolt" in line:
        line = "\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L2>; /* FakeDreamer UV */"
    elif "opp-587000000 {" in lines[i-2] and "opp-microvolt" in line:
        line = "\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L1>; /* FakeDreamer UV */"
    elif "opp-525000000 {" in lines[i-2] and "opp-microvolt" in line:
        line = "\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>; /* FakeDreamer UV */"
    elif "opp-490000000 {" in lines[i-2] and "opp-microvolt" in line:
        line = "\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>; /* FakeDreamer UV */"
    elif "opp-441000000 {" in lines[i-2] and "opp-microvolt" in line:
        line = "\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>; /* FakeDreamer UV */"
    elif "opp-400000000 {" in lines[i-2] and "opp-microvolt" in line:
        line = "\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>; /* FakeDreamer UV */"
    elif "opp-305000000 {" in lines[i-2] and "opp-microvolt" in line:
        line = "\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>; /* FakeDreamer UV */"
    
    new_lines.append(line)

open("patches/apply-gpu-opp.py", "w").write('\n'.join(new_lines))
