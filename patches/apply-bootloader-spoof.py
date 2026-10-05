import sys
import os
import re

# Kernel Source Path
kernel_src = sys.argv[1] if len(sys.argv) > 1 else "."

# Target Files for Spoofing
cmdline_file = os.path.join(kernel_src, "fs/proc/cmdline.c")

print(f"🔍 Looking for cmdline.c at: {cmdline_file}")

# ---------------------------------------------------------
# 1. Patching /proc/cmdline (The String Spoof)
# ---------------------------------------------------------
if os.path.exists(cmdline_file):
    with open(cmdline_file, "r") as f:
        content = f.read()

    # Ye C-code hook OS ko hamesha "Green" aur "Locked" strings dega
    spoof_hook = """
#include <linux/string.h>
#include <linux/slab.h>

static int cmdline_proc_show(struct seq_file *m, void *v)
{
    char *spoofed = kstrdup(saved_command_line, GFP_KERNEL);
    if (spoofed) {
        char *p;
        /* Spoof Bootloader State to Green (Locked) */
        while ((p = strstr(spoofed, "androidboot.verifiedbootstate=orange")) != NULL) {
            strncpy(p, "androidboot.verifiedbootstate=green ", 38);
        }
        /* Spoof Device State to Locked */
        while ((p = strstr(spoofed, "androidboot.vbmeta.device_state=unlocked")) != NULL) {
            strncpy(p, "androidboot.vbmeta.device_state=locked  ", 42);
        }
        /* Spoof Flash State to Locked */
        while ((p = strstr(spoofed, "androidboot.flash.locked=0")) != NULL) {
            strncpy(p, "androidboot.flash.locked=1", 26);
        }
        seq_puts(m, spoofed);
        kfree(spoofed);
    } else {
        seq_puts(m, saved_command_line);
    }
    seq_putc(m, '\\n');
    return 0;
}
"""
    # Original cmdline_proc_show() function ko naye spoofed function se replace karna
    patched_content = re.sub(
        r'static int cmdline_proc_show.*?return 0;\n}', 
        spoof_hook, 
        content, 
        flags=re.DOTALL
    )

    if patched_content != content:
        with open(cmdline_file, "w") as f:
            f.write(patched_content)
        print("✅ SUCCESS: cmdline.c successfully patched for Bootloader Spoofing!")
    else:
        print("⚠️ WARNING: Regex match failed in cmdline.c. Code might be structured differently.")
else:
    print("❌ ERROR: fs/proc/cmdline.c not found!")

