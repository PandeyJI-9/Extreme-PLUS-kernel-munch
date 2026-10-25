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

        # 2. Clang-Safe helper function (injected OUTSIDE / ABOVE cmdline_proc_show)
        helper_func = """/* EXTREME++: Bounded, buffer-safe cmdline token replacement engine (Clang-Safe) */
static void spoof_cmdline_token(char *str, const char *orig, const char *rep)
{
\tchar *p;
\tsize_t orig_len, rep_len;

\tif (!str || !orig || !rep)
\t\treturn;

\torig_len = strlen(orig);
\trep_len = strlen(rep);
\tif (orig_len == 0 || rep_len > orig_len)
\t\treturn;

\twhile ((p = strstr(str, orig)) != NULL) {
\t\tmemcpy(p, rep, rep_len);
\t\tif (orig_len > rep_len) {
\t\t\tmemmove(p + rep_len, p + orig_len, strlen(p + orig_len) + 1);
\t\t}
\t}
}

"""

        # 3. Clean C89 show function with zero trailing spaces
        spoofed_show = helper_func + """static int cmdline_proc_show(struct seq_file *m, void *v)
{
\tchar *spoofed;

\t/* 🚨 CRITICAL SAFETY GUARD: Do not spoof PID 1 (init/AVB) or ueventd */
\tif (current->pid == 1 || !strcmp(current->comm, "init") || !strcmp(current->comm, "ueventd")) {
\t\tseq_puts(m, saved_command_line);
\t\tseq_putc(m, '\\n');
\t\treturn 0;
\t}

\tspoofed = kstrdup(saved_command_line, GFP_KERNEL);
\tif (spoofed) {
\t\tspoof_cmdline_token(spoofed, "androidboot.verifiedbootstate=orange", "androidboot.verifiedbootstate=green");
\t\tspoof_cmdline_token(spoofed, "androidboot.verifiedbootstate=yellow", "androidboot.verifiedbootstate=green");
\t\tspoof_cmdline_token(spoofed, "androidboot.vbmeta.device_state=unlocked", "androidboot.vbmeta.device_state=locked");
\t\tspoof_cmdline_token(spoofed, "androidboot.flash.locked=0", "androidboot.flash.locked=1");
\t\tspoof_cmdline_token(spoofed, "androidboot.bootloader.locked=0", "androidboot.bootloader.locked=1");
\t\tseq_puts(m, spoofed);
\t\tkfree(spoofed);
\t} else {
\t\tseq_puts(m, saved_command_line);
\t}
\tseq_putc(m, '\\n');
\treturn 0;
}"""

        target_pattern = """static int cmdline_proc_show(struct seq_file *m, void *v)
{
\tseq_puts(m, saved_command_line);
\tseq_putc(m, '\\n');
\treturn 0;
}"""

        fallback_pattern = "seq_puts(m, saved_command_line);"

        if target_pattern in content:
            patched_content = content.replace(target_pattern, spoofed_show, 1)
            with open(cmdline_file, "w") as f:
                f.write(patched_content)
            print("✅ SUCCESS: cmdline.c successfully patched with Clang-Safe memmove engine!")
        elif fallback_pattern in content:
            # Fallback in case seq_putc formatting differs
            func_sig = "static int cmdline_proc_show(struct seq_file *m, void *v)"
            if func_sig in content:
                content = content.replace(func_sig, helper_func + func_sig, 1)
            
            spoof_inner = """\t{
\t\tchar *spoofed;
\t\t/* 🚨 CRITICAL SAFETY GUARD: Do not spoof PID 1 (init/AVB) or ueventd */
\t\tif (current->pid == 1 || !strcmp(current->comm, "init") || !strcmp(current->comm, "ueventd")) {
\t\t\tseq_puts(m, saved_command_line);
\t\t\tseq_putc(m, '\\n');
\t\t\treturn 0;
\t\t}

\t\tspoofed = kstrdup(saved_command_line, GFP_KERNEL);
\t\tif (spoofed) {
\t\t\tspoof_cmdline_token(spoofed, "androidboot.verifiedbootstate=orange", "androidboot.verifiedbootstate=green");
\t\t\tspoof_cmdline_token(spoofed, "androidboot.verifiedbootstate=yellow", "androidboot.verifiedbootstate=green");
\t\t\tspoof_cmdline_token(spoofed, "androidboot.vbmeta.device_state=unlocked", "androidboot.vbmeta.device_state=locked");
\t\t\tspoof_cmdline_token(spoofed, "androidboot.flash.locked=0", "androidboot.flash.locked=1");
\t\t\tspoof_cmdline_token(spoofed, "androidboot.bootloader.locked=0", "androidboot.bootloader.locked=1");
\t\t\tseq_puts(m, spoofed);
\t\t\tkfree(spoofed);
\t\t} else {
\t\t\tseq_puts(m, saved_command_line);
\t\t}
\t}"""
            patched_content = content.replace(fallback_pattern, spoof_inner, 1)
            with open(cmdline_file, "w") as f:
                f.write(patched_content)
            print("✅ SUCCESS: cmdline.c patched using fallback pattern with Clang-Safe helper!")
        else:
            print("⚠️ WARNING: Target needle not found in cmdline.c.")
else:
    print("❌ ERROR: fs/proc/cmdline.c not found!")

