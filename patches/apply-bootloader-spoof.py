#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Target: HyperOS ONLY
# Safe Bootloader Lock Spoof (fs/proc/cmdline.c with PID-1 AVB Guard)
# ==============================================================================
import sys
import os

kernel_src = sys.argv[1] if len(sys.argv) > 1 else "."

# -------------------------------------------------------------
# Patch fs/proc/cmdline.c (Universal /proc/cmdline Spoof)
# -------------------------------------------------------------
# ARCHITECTURAL DESIGN FOR ZERO-BOOTLOOP:
# 1. Early Boot (PID 1 init & ueventd): MUST receive genuine saved_command_line
#    so Android init & fs_mgr_avb can mount system/vendor partitions without
#    failing AVB cryptographic verification on an unlocked bootloader.
# 2. Post-Boot Processes (apps, Play Integrity, banking apps, shells):
#    Receive spoofed command line (verifiedbootstate=green, device_state=locked,
#    flash.locked=1, bootloader.locked=1) with zero detection and zero bootloop!
# -------------------------------------------------------------
cmdline_file = os.path.join(kernel_src, "fs/proc/cmdline.c")
print(f"🔍 Looking for cmdline.c at: {cmdline_file}")

if os.path.exists(cmdline_file):
    with open(cmdline_file, "r") as f:
        content = f.read()

    if "/* 🚨 CRITICAL SAFETY GUARD: Do not spoof PID 1" in content:
        print("ℹ️ cmdline.c already patched with PID-1 AVB Guard.")
    else:
        # Include required headers for current task (PID/comm) & memory routines
        headers = []
        if "#include <linux/sched.h>" not in content:
            headers.append("#include <linux/sched.h>")
        if "#include <linux/slab.h>" not in content:
            headers.append("#include <linux/slab.h>")
        if "#include <linux/string.h>" not in content:
            headers.append("#include <linux/string.h>")
        if headers:
            content = "\n".join(headers) + "\n" + content

        spoof_block = """\t{
\t\tchar *spoofed;
\t\t/* 🚨 CRITICAL SAFETY GUARD: Do not spoof PID 1 (init/AVB) or ueventd */
\t\tif (current->pid == 1 || strcmp(current->comm, "init") == 0 || strcmp(current->comm, "ueventd") == 0) {
\t\t\tseq_puts(m, saved_command_line);
\t\t\tseq_putc(m, '\\n');
\t\t\treturn 0;
\t\t}

\t\tspoofed = kstrdup(saved_command_line, GFP_KERNEL);
\t\tif (spoofed) {
\t\t\tchar *p;
\t\t\twhile ((p = strstr(spoofed, "androidboot.verifiedbootstate=orange")) != NULL) {
\t\t\t\tmemcpy(p + 30, "green ", 6);
\t\t\t}
\t\t\twhile ((p = strstr(spoofed, "androidboot.verifiedbootstate=yellow")) != NULL) {
\t\t\t\tmemcpy(p + 30, "green ", 6);
\t\t\t}
\t\t\twhile ((p = strstr(spoofed, "androidboot.vbmeta.device_state=unlocked")) != NULL) {
\t\t\t\tmemcpy(p + 31, "locked  ", 8);
\t\t\t}
\t\t\twhile ((p = strstr(spoofed, "androidboot.flash.locked=0")) != NULL) {
\t\t\t\tp[25] = '1';
\t\t\t}
\t\t\twhile ((p = strstr(spoofed, "androidboot.bootloader.locked=0")) != NULL) {
\t\t\t\tp[30] = '1';
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
            print("✅ SUCCESS: cmdline.c successfully patched with PID-1 AVB Guard!")
        else:
            print("⚠️ WARNING: Target needle not found in cmdline.c.")
else:
    print("❌ ERROR: fs/proc/cmdline.c not found!")

