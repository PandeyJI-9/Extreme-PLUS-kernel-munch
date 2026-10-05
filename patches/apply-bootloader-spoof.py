import sys
import os

kernel_src = sys.argv[1] if len(sys.argv) > 1 else "."
cmdline_file = os.path.join(kernel_src, "fs/proc/cmdline.c")

print(f"🔍 Looking for cmdline.c at: {cmdline_file}")

if os.path.exists(cmdline_file):
    with open(cmdline_file, "r") as f:
        content = f.read()

    if "/* 🚨 CRITICAL SAFETY GUARD: Do not spoof PID 1" in content:
        print("ℹ️ cmdline.c already patched with PID-1 AVB Guard.")
        sys.exit(0)

    # Required headers for our hook
    if "#include <linux/sched.h>" not in content:
        content = "#include <linux/sched.h>\n#include <linux/slab.h>\n#include <linux/string.h>\n" + content

    spoof_block = """\t{
\t\tchar *spoofed;
\t\t/* 🚨 CRITICAL SAFETY GUARD: Do not spoof PID 1 (init/AVB) */
\t\tif (current->pid == 1 || strcmp(current->comm, "init") == 0 || strcmp(current->comm, "ueventd") == 0) {
\t\t\tseq_puts(m, saved_command_line);
\t\t\tseq_putc(m, '\\n');
\t\t\treturn 0;
\t\t}

\t\tspoofed = kstrdup(saved_command_line, GFP_KERNEL);
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
        print("✅ SUCCESS: cmdline.c successfully patched with PID-1 AVB Guard!")
    else:
        print("⚠️ WARNING: Target needle not found in cmdline.c.")
else:
    print("❌ ERROR: fs/proc/cmdline.c not found!")
