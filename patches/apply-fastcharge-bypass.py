#!/usr/bin/env python3
"""
PROJECT EXTREME+ V2: 67W Fast Charging & True Bypass Charging Patcher
Applies proven SenseiiX (fusionX_sm8250) power subsystem patches for POCO F4 (munch):
1. pd_policy_manager_munch.c & pd_policy_manager.c: Bypass DS28E16 authenticity check -> Full 67W Flash Charge
2. qpnp-smb5.c: Expose 6.0A (6000000 uA) for fastcharge mode & rerun APSD on plug-in
3. smb5-lib.c & smb5-lib.h: Implement true bypass charging strictly aligned with N0Kontzzz Kernel Manager (NKM) architecture
"""

import os
import re

def patch_pd_policy_manager():
    paths = [
        "drivers/power/supply/ti/pd_policy_manager_munch.c",
        "drivers/power/supply/ti/pd_policy_manager.c"
    ]
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, "r") as f:
            content = f.read()

        # Replace pd_get_bms_digest_verified body to return true
        pattern = r"(static bool pd_get_bms_digest_verified\(struct usbpd_pm \*pdpm\)\s*\{)(.*?)(^\})"
        replacement = r"\1\n\treturn true;\n\3"
        new_content, count = re.subn(pattern, replacement, content, flags=re.DOTALL | re.MULTILINE)
        if count > 0:
            with open(path, "w") as f:
                f.write(new_content)
            print(f"✅ [67W Fast Charge] Patched pd_get_bms_digest_verified -> return true in {path}")
        else:
            print(f"ℹ️ [67W Fast Charge] Already patched or pattern not found in {path}")

def patch_qpnp_smb5():
    path = "drivers/power/supply/qcom/qpnp-smb5.c"
    if not os.path.exists(path):
        return
    with open(path, "r") as f:
        content = f.read()

    # 1. Add rerun APSD to ensure proper charger detection
    if "smblib_rerun_apsd_if_required(chg);" not in content:
        target = "if (chg->chg_param.smb_version == PMI632_SUBTYPE) {"
        replacement = "smblib_rerun_apsd_if_required(chg);\n\tif (chg->chg_param.smb_version == PMI632_SUBTYPE) {"
        content = content.replace(target, replacement, 1)
        print("✅ [67W Fast Charge] Injected smblib_rerun_apsd_if_required in qpnp-smb5.c")

    # 2. Expose 6.0A for fast charging in smb5_usb_get_prop
    if "POWER_SUPPLY_PROP_CURRENT_MAX:" in content and "6000000" not in content:
        old_prop = """\tcase POWER_SUPPLY_PROP_CURRENT_MAX:
\t\trc = smblib_get_prop_input_current_max(chg, val);
\t\tbreak;"""
        new_prop = """\tcase POWER_SUPPLY_PROP_CURRENT_MAX:
\t\tif (smblib_get_fastcharge_mode(chg))
\t\t\tval->intval = 6000000; /* 6.0A = 67W Turbo Charge */
\t\telse
\t\t\trc = smblib_get_prop_input_current_max(chg, val);
\t\tbreak;"""
        content = content.replace(old_prop, new_prop, 1)
        print("✅ [67W Fast Charge] Expose 6.0A (6000000 uA) for 67W in qpnp-smb5.c")

    with open(path, "w") as f:
        f.write(content)

def patch_smb5_lib():
    path_h = "drivers/power/supply/qcom/smb5-lib.h"
    path_c = "drivers/power/supply/qcom/smb5-lib.c"

    # 1. Update smb5-lib.h with BYPASS_VOTER
    if os.path.exists(path_h):
        with open(path_h, "r") as f:
            h_content = f.read()
        if "BYPASS_VOTER" not in h_content:
            target = '#define THERMAL_FCC_OVERRIDE_VOTER  "THERMAL_FCC_OVERRIDE_VOTER"'
            if target not in h_content:
                target = '#define THERMAL_DAEMON_VOTER'
            h_content = h_content.replace(target, target + '\n#define BYPASS_VOTER\t\t\t"BYPASS_VOTER"')
            with open(path_h, "w") as f:
                f.write(h_content)
            print("✅ [Bypass Charge] Added BYPASS_VOTER to smb5-lib.h")

    # 2. Update smb5-lib.c
    if os.path.exists(path_c):
        with open(path_c, "r") as f:
            c_content = f.read()

        if "static int bypass_charging = 0;" not in c_content:
            target_var = "static bool first_boot_flag;"
            if target_var in c_content:
                c_content = c_content.replace(target_var, target_var + "\nstatic int bypass_charging = 0;")
            else:
                c_content = "static int bypass_charging = 0;\n" + c_content

        # Update smblib_get_prop_input_suspend (N0Kontzzz Kernel Manager expects 1 for Active, 0 for Inactive)
        old_get = r"int smblib_get_prop_input_suspend\(struct smb_charger \*chg,\s*union power_supply_propval \*val\)\s*\{.*?\n\}"
        new_get = """int smblib_get_prop_input_suspend(struct smb_charger *chg,
\t\t\t\t  union power_supply_propval *val)
{
\tif ((get_client_vote(chg->chg_disable_votable, BYPASS_VOTER) == 1) || bypass_charging) {
\t\tval->intval = 1;
\t} else {
\t\tval->intval = 0;
\t}
\treturn 0;
}"""
        c_content = re.sub(old_get, new_get, c_content, flags=re.DOTALL)

        # Update smblib_set_prop_input_suspend (Accepts 1 or 2 to engage Bypass mode, 0 to disable)
        old_set = r"int smblib_set_prop_input_suspend\(struct smb_charger \*chg,\s*const union power_supply_propval \*val\)\s*\{.*?\n\}"
        new_set = """int smblib_set_prop_input_suspend(struct smb_charger *chg,
\t\t\t\t  const union power_supply_propval *val)
{
\tint rc;

\trc = vote(chg->usb_icl_votable, USER_VOTER, false, 0);
\trc = vote(chg->dc_suspend_votable, USER_VOTER, false, 0);

\tif (val->intval == 1 || val->intval == 2) {
\t\trc = vote(chg->chg_disable_votable, BYPASS_VOTER, 1, 0);
\t\tbypass_charging = 1;
\t} else {
\t\trc = vote(chg->chg_disable_votable, BYPASS_VOTER, 0, 0);
\t\tbypass_charging = 0;
\t}

\tif (rc < 0) {
\t\tsmblib_err(chg, "Couldn't vote to %d input_suspend rc=%d\\n",
\t\t\tval->intval, rc);
\t\treturn rc;
\t}

\tpower_supply_changed(chg->batt_psy);
\treturn rc;
}"""
        c_content = re.sub(old_set, new_set, c_content, flags=re.DOTALL)

        # Therm setting work bypass reset
        if "if (bypass_charging)\n\t\tchg->pps_thermal_level = 0;" not in c_content:
            target_work = "struct smb_charger *chg = container_of(work, struct smb_charger,\n\t\t\tthermal_setting_work.work);"
            c_content = c_content.replace(target_work, target_work + "\n\n\tif (bypass_charging)\n\t\tchg->pps_thermal_level = 0;")

        with open(path_c, "w") as f:
            f.write(c_content)
        print("✅ [Bypass Charge] Patched input_suspend (modes 0, 1, 2) in smb5-lib.c")

if __name__ == "__main__":
    patch_pd_policy_manager()
    patch_qpnp_smb5()
    patch_smb5_lib()
    print("✨ Power subsystem patches complete.")
