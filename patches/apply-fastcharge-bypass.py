#!/usr/bin/env python3
"""
PROJECT EXTREME++ | Maintainer: PandeyJI-9
Device: POCO F4 (munch) | Target: HyperOS ONLY
Universal Fast Charging, 67W Mi Turbo Handshake & Dynamic Thermal Safety Guard Patcher

1. Universal Fast Charging (PD / PPS / QC 3.0/4.0) Unlock:
   - pd_policy_manager_munch.c: min_adapter_volt_required -> 8500, min_adapter_curr_required -> 1500, bms_digest -> true
   - smb5-lib-munch.c: default PD fallback ICL -> 3.0A (3000000 uA), pd_verifed -> true, unvote PD_VERIFED_VOTER
   - qpnp-smb5-munch.c: expose 6.0A (6000000 uA) for fastcharge mode & rerun APSD on plug-in
2. HyperOS 67W Mi Turbo Authentication & Charge Pump Handshake:
   - Complete bypass of DS28E16 authenticity check in pd_policy_manager
   - True bypass charging (modes 0, 1, 2) for N0Kontzzz Kernel Manager (NKM)
3. Battery Health & Dynamic Thermal Safety Guard:
   - Dynamic C-level step-chg-jeita throttling:
     * < 38°C: Full 12.4A (12400000 uA / 67W Max Turbo)
     * 38°C - 40°C: Step-down to 9.0A (9000000 uA / ~45W)
     * 40°C - 42°C: Step-down to 6.5A (6500000 uA / ~33W safe throttle)
     * 42°C - 45°C: Step-down to 4.5A (4500000 uA / ~22W)
     * 45°C - 48°C: Step-down to 3.0A (3000000 uA / ~15W)
     * > 48°C: Emergency cool-down to 1.5A (1500000 uA)
   - jeita-step-cfg-munch.dtsi updated with matching temperature curves
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

        # 1. Bypass DS28E16 authenticity check -> return true
        pattern = r"(static bool pd_get_bms_digest_verified\(struct usbpd_pm \*pdpm\)\s*\{)(.*?)(^\})"
        replacement = r"\1\n\treturn true;\n\3"
        content, count1 = re.subn(pattern, replacement, content, flags=re.DOTALL | re.MULTILINE)
        if count1 > 0:
            print(f"✅ [67W Fast Charge] Patched pd_get_bms_digest_verified -> return true in {path}")

        # 2. Lower min adapter volt and current for third-party PPS chargers
        # Allows 3.3V-11V PPS chargers (Samsung 25W/45W, Anker, Baseus, GaN 33W/65W)
        content = re.sub(
            r"(\.min_adapter_volt_required\s*=\s*)\d+,",
            r"\g<1>8500,",
            content
        )
        content = re.sub(
            r"(\.min_adapter_curr_required\s*=\s*)\d+,",
            r"\g<1>1500,",
            content
        )
        print(f"✅ [PPS Fast Charge] Patched min adapter requirements (8.5V, 1.5A) in {path}")

        with open(path, "w") as f:
            f.write(content)

def patch_qpnp_smb5():
    paths = [
        "drivers/power/supply/qcom/qpnp-smb5-munch.c",
        "drivers/power/supply/qcom/qpnp-smb5.c"
    ]
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, "r") as f:
            content = f.read()

        # 1. Add rerun APSD to ensure proper charger detection
        if "smblib_rerun_apsd_if_required(chg);" not in content:
            target = "if (chg->chg_param.smb_version == PMI632_SUBTYPE) {"
            replacement = "smblib_rerun_apsd_if_required(chg);\n\tif (chg->chg_param.smb_version == PMI632_SUBTYPE) {"
            content = content.replace(target, replacement, 1)
            print(f"✅ [67W Fast Charge] Injected smblib_rerun_apsd_if_required in {path}")

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
            print(f"✅ [67W Fast Charge] Expose 6.0A (6000000 uA) for 67W in {path}")

        with open(path, "w") as f:
            f.write(content)

def patch_smb5_lib_headers():
    paths = [
        "drivers/power/supply/qcom/smb5-lib-munch.h",
        "drivers/power/supply/qcom/smb5-lib.h"
    ]
    for path_h in paths:
        if not os.path.exists(path_h):
            continue
        with open(path_h, "r") as f:
            h_content = f.read()
        if "BYPASS_VOTER" not in h_content:
            target = '#define THERMAL_DAEMON_VOTER\t\t"THERMAL_DAEMON_VOTER"'
            if target not in h_content:
                target = '#define THERMAL_DAEMON_VOTER'
            h_content = h_content.replace(target, target + '\n#define BYPASS_VOTER\t\t\t"BYPASS_VOTER"')
            with open(path_h, "w") as f:
                f.write(h_content)
            print(f"✅ [Bypass Charge] Added BYPASS_VOTER to {path_h}")

def patch_smb5_lib_c():
    paths = [
        "drivers/power/supply/qcom/smb5-lib-munch.c",
        "drivers/power/supply/qcom/smb5-lib.c"
    ]
    for path_c in paths:
        if not os.path.exists(path_c):
            continue
        with open(path_c, "r") as f:
            c_content = f.read()

        # 1. Global bypass_charging variable
        if "static int bypass_charging = 0;" not in c_content:
            target_var = "static bool first_boot_flag;"
            if target_var in c_content:
                c_content = c_content.replace(target_var, target_var + "\nstatic int bypass_charging = 0;")
            else:
                c_content = "static int bypass_charging = 0;\n" + c_content

        # 2. Update smblib_get_prop_input_suspend for NKM (Use lambda to prevent escape mangling)
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
        c_content = re.sub(old_get, lambda m: new_get, c_content, flags=re.DOTALL)

        # 3. Update smblib_set_prop_input_suspend (modes 0, 1, 2) (Use lambda to prevent escape mangling)
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
        c_content = re.sub(old_set, lambda m: new_set, c_content, flags=re.DOTALL)

        # 4. Thermal setting work bypass reset
        if "if (bypass_charging)\n\t\tchg->pps_thermal_level = 0;" not in c_content:
            target_work = "struct smb_charger *chg = container_of(work, struct smb_charger,\n\t\t\tthermal_setting_work.work);"
            c_content = c_content.replace(target_work, target_work + "\n\n\tif (bypass_charging)\n\t\tchg->pps_thermal_level = 0;")

        # 5. Universal PD / Third-Party Fast Charging Unlock
        # In smblib_update_usb_type when pd_active is true:
        # Instead of restricting to USBIN_100MA until userspace votes, start at 3.0A (3000000 uA)
        # and mark pd_verifed = true so PD_VERIFED_VOTER is unvoted.
        old_pd_icl = r"vote\(chg->usb_icl_votable,\s*PD_VOTER,\s*true,\s*USBIN_100MA\);"
        new_pd_icl = "vote(chg->usb_icl_votable, PD_VOTER, true, 3000000);\n\t\tchg->pd_verifed = true;"
        if re.search(old_pd_icl, c_content):
            c_content = re.sub(old_pd_icl, lambda m: new_pd_icl, c_content, count=1)
            print(f"✅ [PD Fast Charge] Raised default PD ICL to 3.0A (3000000 uA) in {path_c}")

        old_pd_unverified = r"if\s*\(!chg->pd_verifed\)\s*\{\s*rc = vote\(chg->fcc_votable,\s*PD_VERIFED_VOTER,\s*true,\s*PD_UNVERIFED_CURRENT\);\s*if \(rc < 0\)\s*smblib_err\(.*?\);\s*\}\s*else\s*\{\s*vote\(chg->fcc_votable,\s*PD_VERIFED_VOTER,\s*false,\s*0\);\s*\}"
        new_pd_unverified = "vote(chg->fcc_votable, PD_VERIFED_VOTER, false, 0);"
        if re.search(old_pd_unverified, c_content, flags=re.DOTALL):
            c_content = re.sub(old_pd_unverified, lambda m: new_pd_unverified, c_content, count=1, flags=re.DOTALL)
            print(f"✅ [PD Fast Charge] Unvoted PD_VERIFED_VOTER restrictions in {path_c}")

        with open(path_c, "w") as f:
            f.write(c_content)
        print(f"✅ [Bypass & PD Charge] Patched {path_c}")

def patch_step_chg_jeita():
    paths = [
        "drivers/power/supply/qcom/step-chg-jeita-munch.c",
        "drivers/power/supply/qcom/step-chg-jeita.c"
    ]
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, "r") as f:
            content = f.read()

        guard_code = """\t/* PROJECT EXTREME++: Dynamic Battery Health & Thermal Safety Guard */
\tif (fcc_ua > 0) {
\t\tif (temp >= 480) {
\t\t\tfcc_ua = min(fcc_ua, 1500000); /* > 48°C: Emergency cool-down (1.5A) */
\t\t} else if (temp >= 450) {
\t\t\tfcc_ua = min(fcc_ua, 3000000); /* 45°C - 48°C: Low thermal throttle (3.0A) */
\t\t} else if (temp >= 420) {
\t\t\tfcc_ua = min(fcc_ua, 4500000); /* 42°C - 45°C: Medium thermal throttle (4.5A) */
\t\t} else if (temp >= 400) {
\t\t\tfcc_ua = min(fcc_ua, 6500000); /* 40°C - 42°C: Safe step-down throttle (6.5A / ~33W) */
\t\t} else if (temp >= 380) {
\t\t\tfcc_ua = min(fcc_ua, 9000000); /* 38°C - 40°C: Moderate step-down (9.0A / ~45W) */
\t\t}
\t}"""

        target = "if (rc < 0)\n\t\tfcc_ua = 0;"
        if "PROJECT EXTREME++: Dynamic Battery Health" not in content and target in content:
            content = content.replace(target, target + "\n\n" + guard_code, 1)
            with open(path, "w") as f:
                f.write(content)
            print(f"✅ [Thermal Guard] Injected dynamic battery thermal safety guard in {path}")
        else:
            print(f"ℹ️ [Thermal Guard] Already patched or target not found in {path}")

def patch_jeita_dtsi():
    paths = [
        "arch/arm64/boot/dts/vendor/qcom/jeita-step-cfg-munch.dtsi",
        "arch/arm64/boot/dts/vendor/qcom/jeita-step-cfg.dtsi"
    ]
    for path in paths:
        if not os.path.exists(path):
            continue
        with open(path, "r") as f:
            content = f.read()

        new_ranges = """\tqcom,jeita-fcc-ranges = <(-100)  0  1000000
\t\t\t\t1   50   2200000
\t\t\t\t51  100  3080000
\t\t\t\t101 150  5280000
\t\t\t\t151 380  12400000
\t\t\t\t381 400  9000000
\t\t\t\t401 420  6500000
\t\t\t\t421 450  4500000
\t\t\t\t451 480  3000000
\t\t\t\t481 580  1500000>;"""

        pattern = r"qcom,jeita-fcc-ranges\s*=\s*<[^>]+>;"
        if re.search(pattern, content):
            content = re.sub(pattern, lambda m: new_ranges.strip(), content)
            with open(path, "w") as f:
                f.write(content)
            print(f"✅ [Thermal Guard] Updated jeita-fcc-ranges thermal curve in {path}")

if __name__ == "__main__":
    print("🚀 Running PROJECT EXTREME++ Power & Charging Subsystem Patcher...")
    patch_pd_policy_manager()
    patch_qpnp_smb5()
    patch_smb5_lib_headers()
    patch_smb5_lib_c()
    patch_step_chg_jeita()
    patch_jeita_dtsi()
    print("✨ Power subsystem & charging thermal patches complete.")
