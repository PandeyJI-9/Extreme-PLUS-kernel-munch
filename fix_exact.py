import sys
text = open("patches/apply-gpu-opp.py").read()

replacements = {
    "opp-hz = /bits/ 64 <670000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_NOM>;": "opp-hz = /bits/ 64 <670000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L2>; /* FakeDreamer UV */",
    "opp-hz = /bits/ 64 <587000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L2>;": "opp-hz = /bits/ 64 <587000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L1>; /* FakeDreamer UV */",
    "opp-hz = /bits/ 64 <525000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L1>;": "opp-hz = /bits/ 64 <525000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>; /* FakeDreamer UV */",
    "opp-hz = /bits/ 64 <490000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS_L1>;": "opp-hz = /bits/ 64 <490000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>; /* FakeDreamer UV */",
    "opp-hz = /bits/ 64 <441000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>;": "opp-hz = /bits/ 64 <441000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>; /* FakeDreamer UV */",
    "opp-hz = /bits/ 64 <400000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_SVS>;": "opp-hz = /bits/ 64 <400000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>; /* FakeDreamer UV */",
    "opp-hz = /bits/ 64 <305000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_LOW_SVS>;": "opp-hz = /bits/ 64 <305000000>;\n\t\t\topp-microvolt = <RPMH_REGULATOR_LEVEL_MIN_SVS>; /* FakeDreamer UV */",
}

for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)
    else:
        print(f"Failed to find: {old}")

open("patches/apply-gpu-opp.py", "w").write(text)
