import re

with open("patches/apply-gpu-opp.py", "r") as f:
    text = f.read()

def replace_uv(text, freq, new_level):
    pattern = r'(<' + freq + r'>;\n\s*opp-microvolt = )<[^>]+>;'
    return re.sub(pattern, r'\g<1><' + new_level + r'>; /* FakeDreamer UV */', text)

text = replace_uv(text, '670000000', 'RPMH_REGULATOR_LEVEL_SVS_L2')
text = replace_uv(text, '587000000', 'RPMH_REGULATOR_LEVEL_SVS_L1')
text = replace_uv(text, '525000000', 'RPMH_REGULATOR_LEVEL_SVS')
text = replace_uv(text, '490000000', 'RPMH_REGULATOR_LEVEL_SVS')
text = replace_uv(text, '441000000', 'RPMH_REGULATOR_LEVEL_LOW_SVS')
text = replace_uv(text, '400000000', 'RPMH_REGULATOR_LEVEL_LOW_SVS')
text = replace_uv(text, '305000000', 'RPMH_REGULATOR_LEVEL_MIN_SVS')

with open("patches/apply-gpu-opp.py", "w") as f:
    f.write(text)
