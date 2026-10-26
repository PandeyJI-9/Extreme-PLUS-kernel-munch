#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# Device: POCO F4 (munch) | Targets: HyperOS 4 / HyperOS & AOSP
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

    # Hook task_is_critical() into throttle_direct_reclaim() WITHOUT adding a
    # statement before the local declarations (-Wdeclaration-after-statement).
    # Preferred: swap the stock kernel-thread early-out's condition. It exists as
    #   if (current->flags & PF_KTHREAD)                                  (older)
    #   if ((current->flags & PF_KTHREAD) || !strcmp(..., ULMK_MAGIC))    (this tree)
    # so match on the common "(current->flags & PF_KTHREAD)" part only.
    func_idx = content.find(target_func)
    func_end = content.find("\n}\n", func_idx)
    body = content[func_idx:func_end]
    stock = "(current->flags & PF_KTHREAD)"
    if stock in body:
        body = body.replace(stock, "task_is_critical(current)", 1)
        content = content[:func_idx] + body + content[func_end:]
    else:
        # Fallback: insert right after the last local declaration.
        decl_idx = body.find("pgdat = NULL;")
        if decl_idx == -1:
            print("⚠️ [VMScan Anti-Stutter] no hook point found in throttle_direct_reclaim - patch NOT applied")
            return False
        eol = func_idx + body.find("\n", decl_idx)
        content = (content[:eol] +
                   "\n\n\tif (task_is_critical(current))\n\t\treturn false;" +
                   content[eol:])

    with open(path, "w") as f:
        f.write(content)

    print("✅ [VMScan Anti-Stutter] Successfully patched mm/vmscan.c (C90 declaration-safe): Critical processes bypass reclaim throttle!")
    return True

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "mm/vmscan.c"
    success = patch_vmscan(target)
    sys.exit(0 if success else 1)
