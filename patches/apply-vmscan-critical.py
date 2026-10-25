#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Target: HyperOS ONLY
# mm/vmscan: Skip Direct Reclaim Throttle for Critical Tasks (SurfaceFlinger)
# Reference: Android Common Kernel commit 0e36eb2f & 3c20b9e9 (Google ACK Anti-Stutter Fix)
# ==============================================================================
import os
import sys

def patch_vmscan(path="mm/vmscan.c"):
    if not os.path.exists(path):
        print(f"⚠️ [VMScan Anti-Stutter] {path} not found, skipping...")
        return True

    with open(path, "r") as f:
        content = f.read()

    if "task_is_critical" in content:
        print("ℹ️ [VMScan Anti-Stutter] mm/vmscan.c already patched with task_is_critical.")
        return True

    helper_code = """#include <linux/sched/rt.h>
/* EXTREME++: Skip reclaim throttle for critical UI/Render tasks (SurfaceFlinger & Composer) */
static inline bool task_is_critical(struct task_struct *task)
{
\tif (task->flags & PF_KTHREAD)
\t\treturn true;
\tif (rt_task(task))
\t\treturn true;
\tif (task->signal && task->signal->oom_score_adj <= -900)
\t\treturn true;
\treturn false;
}

"""

    target_func = "static bool throttle_direct_reclaim(gfp_t gfp_mask, struct zonelist *zonelist,"
    if target_func not in content:
        print("⚠️ [VMScan Anti-Stutter] throttle_direct_reclaim signature not found in mm/vmscan.c")
        return False

    # Insert helper before throttle_direct_reclaim
    content = content.replace(target_func, helper_code + target_func, 1)

    # Insert skip check inside throttle_direct_reclaim right after opening brace
    func_idx = content.find(target_func)
    brace_idx = content.find("{", func_idx)
    if brace_idx == -1:
        print("⚠️ [VMScan Anti-Stutter] Could not locate opening brace for throttle_direct_reclaim")
        return False

    skip_check = "\n\tif (task_is_critical(current))\n\t\treturn false;\n"
    content = content[:brace_idx + 1] + skip_check + content[brace_idx + 1:]

    with open(path, "w") as f:
        f.write(content)

    print("✅ [VMScan Anti-Stutter] Successfully patched mm/vmscan.c: Critical processes (SurfaceFlinger) bypass reclaim throttle!")
    return True

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "mm/vmscan.c"
    success = patch_vmscan(target)
    sys.exit(0 if success else 1)
