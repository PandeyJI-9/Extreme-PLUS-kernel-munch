#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Target: HyperOS ONLY
# Universal Bootloader Lock Spoof (cmdline.c & drivers/of/kobj.c)
# ==============================================================================
import sys
import os

kernel_src = sys.argv[1] if len(sys.argv) > 1 else "."

# -------------------------------------------------------------
# 1. Patch fs/proc/cmdline.c (Universal /proc/cmdline Spoof)
# -------------------------------------------------------------
cmdline_file = os.path.join(kernel_src, "fs/proc/cmdline.c")
print(f"🔍 Looking for cmdline.c at: {cmdline_file}")

if os.path.exists(cmdline_file):
    with open(cmdline_file, "r") as f:
        content = f.read()

    if "/* EXTREME+: Universal Bootloader Lock Spoof */" in content:
        print("ℹ️ cmdline.c already patched with Universal Bootloader Lock Spoof.")
    else:
        # Include required headers if not present
        if "#include <linux/slab.h>" not in content:
            content = "#include <linux/slab.h>\n#include <linux/string.h>\n" + content

        spoof_block = """\t{
\t\t/* EXTREME+: Universal Bootloader Lock Spoof (Includes PID 1 init) */
\t\tchar *spoofed = kstrdup(saved_command_line, GFP_KERNEL);
\t\tif (spoofed) {
\t\t\tchar *p;
\t\t\twhile ((p = strstr(spoofed, "androidboot.verifiedbootstate=orange")) != NULL) {
\t\t\t\tmemcpy(p, "androidboot.verifiedbootstate=green ", 36);
\t\t\t}
\t\t\twhile ((p = strstr(spoofed, "androidboot.verifiedbootstate=yellow")) != NULL) {
\t\t\t\tmemcpy(p, "androidboot.verifiedbootstate=green ", 36);
\t\t\t}
\t\t\twhile ((p = strstr(spoofed, "androidboot.vbmeta.device_state=unlocked")) != NULL) {
\t\t\t\tmemcpy(p, "androidboot.vbmeta.device_state=locked  ", 40);
\t\t\t}
\t\t\twhile ((p = strstr(spoofed, "androidboot.flash.locked=0")) != NULL) {
\t\t\t\tmemcpy(p, "androidboot.flash.locked=1", 26);
\t\t\t}
\t\t\twhile ((p = strstr(spoofed, "androidboot.bootloader.locked=0")) != NULL) {
\t\t\t\tmemcpy(p, "androidboot.bootloader.locked=1", 31);
\t\t\t}
\t\t\tseq_puts(m, spoofed);
\t\t\tkfree(spoofed);
\t\t} else {
\t\t\tseq_puts(m, saved_command_line);
\t\t}
\t}"""

        target_needle = "seq_puts(m, saved_command_line);"
        if target_needle in content:
            patched_content = content.replace(target_needle, spoof_block, 1)
            with open(cmdline_file, "w") as f:
                f.write(patched_content)
            print("✅ SUCCESS: cmdline.c successfully patched with Universal Bootloader Lock Spoof!")
        else:
            print("⚠️ WARNING: Target needle not found in cmdline.c.")
else:
    print("❌ ERROR: fs/proc/cmdline.c not found!")

# -------------------------------------------------------------
# 2. Patch drivers/of/kobj.c (Device Tree sysfs/procfs node spoof)
# Spoofs /proc/device-tree/firmware/android/ nodes seen by init & apps
# -------------------------------------------------------------
kobj_file = os.path.join(kernel_src, "drivers/of/kobj.c")
print(f"🔍 Looking for drivers/of/kobj.c at: {kobj_file}")

if os.path.exists(kobj_file):
    with open(kobj_file, "r") as f:
        kcontent = f.read()

    if "/* EXTREME+: Device Tree Bootloader Lock Spoof */" in kcontent:
        print("ℹ️ drivers/of/kobj.c already patched.")
    else:
        target_kobj = """static ssize_t of_node_property_read(struct file *filp, struct kobject *kobj,
\t\t\t\tstruct bin_attribute *bin_attr, char *buf,
\t\t\t\tloff_t offset, size_t count)
{
\tstruct property *pp = container_of(bin_attr, struct property, attr);
\treturn memory_read_from_buffer(buf, count, &offset, pp->value, pp->length);
}"""

        replacement_kobj = """static ssize_t of_node_property_read(struct file *filp, struct kobject *kobj,
\t\t\t\tstruct bin_attribute *bin_attr, char *buf,
\t\t\t\tloff_t offset, size_t count)
{
\tstruct property *pp = container_of(bin_attr, struct property, attr);
\t/* EXTREME+: Device Tree Bootloader Lock Spoof */
\tif (pp && pp->name) {
\t\tif (!strcmp(pp->name, "verifiedbootstate")) {
\t\t\tconst char *val = "green";
\t\t\treturn memory_read_from_buffer(buf, count, &offset, val, 6);
\t\t}
\t\tif (!strcmp(pp->name, "device_state")) {
\t\t\tconst char *val = "locked";
\t\t\treturn memory_read_from_buffer(buf, count, &offset, val, 7);
\t\t}
\t\tif (!strcmp(pp->name, "flash_locked") || !strcmp(pp->name, "flash.locked")) {
\t\t\tconst char *val = "1";
\t\t\treturn memory_read_from_buffer(buf, count, &offset, val, 2);
\t\t}
\t}
\treturn memory_read_from_buffer(buf, count, &offset, pp->value, pp->length);
}"""

        if target_kobj in kcontent:
            kcontent = kcontent.replace(target_kobj, replacement_kobj, 1)
            with open(kobj_file, "w") as f:
                f.write(kcontent)
            print("✅ SUCCESS: drivers/of/kobj.c successfully patched for Device Tree Lock Spoof!")
        else:
            print("⚠️ WARNING: Target function of_node_property_read not found in drivers/of/kobj.c.")
else:
    print("ℹ️ drivers/of/kobj.c not found at target path.")
