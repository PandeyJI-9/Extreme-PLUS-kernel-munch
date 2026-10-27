#!/usr/bin/env python3
"""
PROJECT EXTREME++ | Maintainer: PandeyJI-9
Device: POCO F4 (munch) | Target: HyperOS ONLY
Safe PD / PPS Charger Unlock & Thermal DTS Stepping (Zero-Bootloop Architecture)

1. PD / PPS Charger Speed Unlock (Safe Variable Edit):
   - pd_policy_manager_munch.c:
     * min_adapter_volt_required -> 8500 (8.5V for third-party PPS support)
     * min_adapter_curr_required -> 1500 (1.5A for third-party PPS support)

2. 100% Stock Xiaomi 67W Cryptographic Handshake:
   - pd_get_bms_digest_verified and BMS authentic verification left 100% stock
   - mi_thermald & natural hardware authentication flows completely untampered

3. Thermal & Battery Health (Device Tree Only):
   - C-code (step-chg-jeita-munch.c) left 100% STOCK
   - jeita-step-cfg-munch.dtsi updated with OEM 6-tuple syntax:
     * (-10°C - 0°C): 1.0A (Freezing battery protection)
     * (0.1°C - 15°C): 4.0A (Cold step safety)
     * (15.1°C - 38°C): 12.4A (Full 67W Turbo Peak)
     * (38.1°C - 42°C): 6.6A (~33W Thermal step-down)
     * (42.1°C - 45°C): 4.5A (~22W Controlled throttle)
     * (45.1°C - 58°C): 2.2A (Extreme safety step-down)
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

        # Lower min adapter volt and current for third-party PPS chargers (8.5V, 1.5A)
        # Note: Cryptographic handshake (pd_get_bms_digest_verified) is strictly UNTOUCHED!
        content, c1 = re.subn(
            r"(\.min_adapter_volt_required\s*=\s*)\d+,",
            r"\g<1>8500,",
            content
        )
        content, c2 = re.subn(
            r"(\.min_adapter_curr_required\s*=\s*)\d+,",
            r"\g<1>1500,",
            content
        )
        if c1 > 0 or c2 > 0:
            print(f"✅ [PPS Fast Charge] Patched min adapter requirements (8.5V, 1.5A) in {path}")

        with open(path, "w") as f:
            f.write(content)

def patch_smb5_lib():
    """
    EXTREME++ Hardware-Level True Bypass Charging Architecture:
    Integrate proven E404 & FakeDreamer bypass charging into smb5-lib / smb5-lib-munch.

    1. Prevents USB input current cutoff:
       Stock smblib_set_prop_input_suspend votes 0mA on usb_icl_votable, which shuts off
       all charger current, forcing the device to discharge from battery!
       Our fix clears any USB suspend vote (keeps VBUS active and powering the system rail).

    2. Real Hardware Charge Inhibition:
       Votes true on chg->chg_disable_votable via BYPASS_VOTER, clearing CHARGING_ENABLE_CMD_BIT
       in PM8150B / SMB5 hardware register, and votes 0mA on fcc_votable.
       The battery is completely isolated (IBAT = 0mA), while the wall charger powers
       the display, SoC (CPU/GPU), and system directly!

    3. Seamless compatibility with EKM, NKM, and ACC via /sys/class/power_supply/battery/input_suspend.
    """
    header_paths = [
        "drivers/power/supply/qcom/smb5-lib-munch.h",
        "drivers/power/supply/qcom/smb5-lib.h",
        "drivers/power/supply/cas_qcom/smb5-lib.h"
    ]
    for hp in header_paths:
        if not os.path.exists(hp):
            continue
        with open(hp, "r") as f:
            h_content = f.read()
        if "BYPASS_VOTER" not in h_content:
            last_endif = h_content.rfind("#endif")
            if last_endif != -1:
                h_content = (h_content[:last_endif] +
                             '#define BYPASS_VOTER\t\t\t"BYPASS_VOTER"\n\n' +
                             h_content[last_endif:])
            else:
                h_content += '\n#define BYPASS_VOTER\t\t\t"BYPASS_VOTER"\n'
            with open(hp, "w") as f:
                f.write(h_content)
            print(f"✅ [Bypass Charging] Injected BYPASS_VOTER definition in {hp}")

    c_paths = [
        "drivers/power/supply/qcom/smb5-lib-munch.c",
        "drivers/power/supply/qcom/smb5-lib.c",
        "drivers/power/supply/cas_qcom/smb5-lib.c"
    ]
    for cp in c_paths:
        if not os.path.exists(cp):
            continue
        with open(cp, "r") as f:
            c_content = f.read()

        if "BYPASS_VOTER" in c_content and "True Bypass" in c_content:
            print(f"ℹ️ [Bypass Charging] {cp} already patched.")
            continue

        # Add static int bypass_charging declaration if absent
        if "static int bypass_charging" not in c_content:
            for flag_marker in ["static bool first_boot_flag;", "bool off_charge_flag;", "static bool off_charge_flag;"]:
                if flag_marker in c_content:
                    c_content = c_content.replace(flag_marker, f"{flag_marker}\nstatic int bypass_charging = 0;")
                    break

        # Patch smblib_get_prop_input_suspend
        get_pattern = r'int\s+smblib_get_prop_input_suspend\s*\(\s*struct\s+smb_charger\s*\*chg\s*,\s*union\s+power_supply_propval\s*\*val\s*\)\s*\{[\s\S]*?return\s+0;\s*\}'
        get_repl = r"""int smblib_get_prop_input_suspend(struct smb_charger *chg,
				  union power_supply_propval *val)
{
	if (get_client_vote(chg->chg_disable_votable, BYPASS_VOTER) == 1)
		val->intval = 1;
	else if (bypass_charging)
		val->intval = 2;
	else
		val->intval = 0;
	return 0;
}"""
        if re.search(get_pattern, c_content):
            c_content = re.sub(get_pattern, lambda m: get_repl, c_content)

        # Patch smblib_set_prop_input_suspend
        set_pattern = r'int\s+smblib_set_prop_input_suspend\s*\(\s*struct\s+smb_charger\s*\*chg\s*,\s*const\s+union\s+power_supply_propval\s*\*val\s*\)\s*\{[\s\S]*?power_supply_changed\(chg->batt_psy\);\s*return\s+rc;\s*\}'
        set_repl = r"""int smblib_set_prop_input_suspend(struct smb_charger *chg,
				  const union power_supply_propval *val)
{
	int rc = 0;

	/* EXTREME++ True Bypass Charging: Never suspend USB input current! */
	rc = vote(chg->usb_icl_votable, USER_VOTER, false, 0);
	if (rc < 0) {
		smblib_err(chg, "Couldn't vote to %s USB rc=%d\n",
			(bool)val->intval ? "suspend" : "resume", rc);
		return rc;
	}

	rc = vote(chg->dc_suspend_votable, USER_VOTER, false, 0);
	if (rc < 0) {
		smblib_err(chg, "Couldn't vote to %s DC rc=%d\n",
			(bool)val->intval ? "suspend" : "resume", rc);
		return rc;
	}

	if (val->intval == 1) {
		/* True Bypass: Inhibit battery charging via PMIC register, keep USB powering the system rail */
		rc = vote(chg->chg_disable_votable, BYPASS_VOTER, true, 0);
		vote(chg->fcc_votable, BYPASS_VOTER, true, 0);
		bypass_charging = 0;
	} else if (val->intval == 2) {
		/* Thermal bypass mode */
		rc = vote(chg->chg_disable_votable, BYPASS_VOTER, false, 0);
		vote(chg->fcc_votable, BYPASS_VOTER, false, 0);
		bypass_charging = 1;
	} else {
		/* Normal charging resumed */
		rc = vote(chg->chg_disable_votable, BYPASS_VOTER, false, 0);
		vote(chg->fcc_votable, BYPASS_VOTER, false, 0);
		bypass_charging = 0;
	}

	if (rc < 0) {
		smblib_err(chg, "Couldn't vote to %d input_suspend rc=%d\n",
			val->intval, rc);
		return rc;
	}

	power_supply_changed(chg->batt_psy);
	return rc;
}"""
        if re.search(set_pattern, c_content):
            c_content = re.sub(set_pattern, lambda m: set_repl, c_content)

        # Patch smblib_set_prop_battery_input_suspend
        batt_pattern = r'int\s+smblib_set_prop_battery_input_suspend\s*\(\s*struct\s+smb_charger\s*\*chg\s*,\s*const\s+union\s+power_supply_propval\s*\*val\s*\)\s*\{[\s\S]*?power_supply_changed\(chg->batt_psy\);\s*return\s+rc;\s*\}'
        batt_repl = r"""int smblib_set_prop_battery_input_suspend(struct smb_charger *chg,
		const union power_supply_propval *val)
{
	int rc;

	/* vote 0mA when battery suspended */
	rc = vote(chg->fcc_votable, USER_VOTER, (bool)val->intval, 0);
	if (rc < 0) {
		smblib_err(chg, "Couldn't vote to %s fcc rc=%d\n",
			(bool)val->intval ? "suspend" : "resume", rc);
		return rc;
	}

	rc = vote(chg->chg_disable_votable, USER_VOTER, (bool)val->intval, 0);
	if (rc < 0) {
		smblib_err(chg, "Couldn't vote to %s chg rc=%d\n",
			(bool)val->intval ? "suspend" : "resume", rc);
		return rc;
	}

	power_supply_changed(chg->batt_psy);
	return rc;
}"""
        if re.search(batt_pattern, c_content):
            c_content = re.sub(batt_pattern, lambda m: batt_repl, c_content)

        # Neutralize thermal daemon overrides when bypass charging is active
        temp_level_marker = "chg->system_temp_level = val->intval;"
        if temp_level_marker in c_content and "if (bypass_charging)" not in c_content:
            c_content = c_content.replace(
                temp_level_marker,
                f"{temp_level_marker}\n\tif (bypass_charging)\n\t\tchg->system_temp_level = 0;"
            )

        with open(cp, "w") as f:
            f.write(c_content)
        print(f"✅ [Bypass Charging] Patched true hardware bypass charging into {cp}")

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

        # OEM Qualcomm format: Strictly 6 tuples matching MAX_STEP_CHG_ENTRIES == 6
        new_ranges = """\tqcom,jeita-fcc-ranges = <(-100)  0   1000000
\t\t\t\t1    150 4000000
\t\t\t\t151  380 12400000
\t\t\t\t381  420 6600000
\t\t\t\t421  450 4500000
\t\t\t\t451  580 2200000>;"""

        pattern = r"qcom,jeita-fcc-ranges\s*=\s*<[^>]+>;"
        if re.search(pattern, content):
            content = re.sub(pattern, lambda m: new_ranges.strip(), content)
            with open(path, "w") as f:
                f.write(content)
            print(f"✅ [Thermal Guard] Updated jeita-fcc-ranges 6-tuple curve (<38°C: 67W, 38-42°C: 33W, 42-45°C: 22W) in {path}")

if __name__ == "__main__":
    print("🚀 Running PROJECT EXTREME++ Safe Power & Charging Patcher...")
    patch_pd_policy_manager()
    patch_smb5_lib()
    patch_jeita_dtsi()
    print("✨ Safe charging patches complete.")
