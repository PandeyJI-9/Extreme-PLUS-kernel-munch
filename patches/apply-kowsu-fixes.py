#!/usr/bin/env python3
"""
PROJECT EXTREME++ | Maintainer: PandeyJI-9
KowSU (KOWX712/KernelSU) Multi-Manager & Universal App-Profile Patcher

Fixes:
1. "Failed to update App Profile for <appname>" error:
   - Relaxes .perm_check on KSU_IOCTL_SET_APP_PROFILE and GET_APP_PROFILE to manager_or_root.
   - Allows only_manager() to succeed if caller is manager OR root (UID 0).
   - Allows app_profile version 2, 3, and 4 (normalizes to 4).
   - Auto-defaults empty selinux_domain to "u:r:su:s0" instead of failing validation.
2. Multi-Manager Crowning:
   - Multi-manager tracking array ksu_manager_appids[KSU_MAX_MANAGERS] so ALL installed managers
     (KowSU SuperManager, Official KernelSU, ReSukiSU, SukiSU Ultra, BakaSU) are crowned simultaneously.
   - Known manager package name verification and fallback in is_manager_apk().
   - maybe_manager_apk_dir() and crown_manager() recognize all known manager packages.
3. Linux 4.19 Kernel Compatibility:
   - copy_to_kernel_nofault / copy_from_kernel_nofault fallback for older kernels.
"""

import os
import sys

def patch_file(path, patches):
    if not os.path.exists(path):
        print(f"[-] File not found: {path}")
        return False

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    modified = False
    for target, replacement in patches:
        if target in content:
            content = content.replace(target, replacement)
            modified = True
        else:
            print(f"[!] Target substring not found in {path}: {target[:40]}...")

    if modified:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"[+] Successfully patched: {path}")
        return True
    return False

def main():
    print("[*] Applying KowSU Multi-Manager & Universal App-Profile Fixes...")

    # Find drivers/kernelsu directory (could be drivers/kernelsu, KernelSU/kernel, or kernel)
    base_dirs = ["drivers/kernelsu", "KernelSU/kernel", "kernel", "."]
    ksu_dir = None
    for b in base_dirs:
        if os.path.exists(os.path.join(b, "manager", "throne_tracker.c")):
            ksu_dir = b
            break

    if not ksu_dir:
        print("[-] Could not locate KernelSU directory!")
        return 1

    print(f"[*] Found KernelSU at: {ksu_dir}")

    # 1. Update manager_identity.h
    id_h = os.path.join(ksu_dir, "manager", "manager_identity.h")
    if os.path.exists(id_h):
        with open(id_h, "w", encoding="utf-8") as f:
            f.write('''#ifndef __KSU_H_MANAGER_IDENTITY
#define __KSU_H_MANAGER_IDENTITY

#include <linux/cred.h>
#include <linux/types.h>

#define KSU_INVALID_APPID -1
#define KSU_PER_USER_RANGE 100000
#define KSU_MAX_MANAGERS 8

#ifdef CONFIG_KSU_DISABLE_MANAGER
static inline bool ksu_is_manager_appid_valid(void)
{
    return true;
}

static inline bool is_manager(void)
{
    return current_uid().val == 0;
}

static inline bool is_uid_manager(uid_t uid)
{
    return uid == 0;
}

static inline uid_t ksu_get_manager_appid(void)
{
    return 0;
}

static inline void ksu_set_manager_appid(uid_t appid)
{
    (void)appid;
}

static inline void ksu_add_manager_appid(uid_t appid)
{
    (void)appid;
}

static inline void ksu_invalidate_manager_uid(void)
{
}
#else
extern uid_t ksu_manager_appid; // Primary manager
extern uid_t ksu_manager_appids[KSU_MAX_MANAGERS]; // Multi-manager array

static inline bool ksu_is_manager_appid_valid(void)
{
    int i;
    if (ksu_manager_appid != (uid_t)KSU_INVALID_APPID)
        return true;
    for (i = 0; i < KSU_MAX_MANAGERS; i++) {
        if (ksu_manager_appids[i] != (uid_t)KSU_INVALID_APPID)
            return true;
    }
    return false;
}

static inline bool is_manager(void)
{
    int i;
    uid_t appid = current_uid().val % KSU_PER_USER_RANGE;
    if (ksu_manager_appid == appid && appid != (uid_t)KSU_INVALID_APPID)
        return true;
    for (i = 0; i < KSU_MAX_MANAGERS; i++) {
        if (ksu_manager_appids[i] == appid && appid != (uid_t)KSU_INVALID_APPID)
            return true;
    }
    return false;
}

static inline bool is_uid_manager(uid_t uid)
{
    int i;
    uid_t appid = uid % KSU_PER_USER_RANGE;
    if (ksu_manager_appid == appid && appid != (uid_t)KSU_INVALID_APPID)
        return true;
    for (i = 0; i < KSU_MAX_MANAGERS; i++) {
        if (ksu_manager_appids[i] == appid && appid != (uid_t)KSU_INVALID_APPID)
            return true;
    }
    return false;
}

static inline uid_t ksu_get_manager_appid(void)
{
    return ksu_manager_appid;
}

static inline void ksu_set_manager_appid(uid_t appid)
{
    ksu_manager_appid = appid;
}

static inline void ksu_add_manager_appid(uid_t appid)
{
    int i;
    if (ksu_manager_appid == (uid_t)KSU_INVALID_APPID)
        ksu_manager_appid = appid;
    for (i = 0; i < KSU_MAX_MANAGERS; i++) {
        if (ksu_manager_appids[i] == appid)
            return;
        if (ksu_manager_appids[i] == (uid_t)KSU_INVALID_APPID) {
            ksu_manager_appids[i] = appid;
            return;
        }
    }
}

static inline void ksu_invalidate_manager_uid(void)
{
    int i;
    ksu_manager_appid = KSU_INVALID_APPID;
    for (i = 0; i < KSU_MAX_MANAGERS; i++) {
        ksu_manager_appids[i] = KSU_INVALID_APPID;
    }
}
#endif

#endif // __KSU_H_MANAGER_IDENTITY
''')
        print(f"[+] Replaced {id_h} with multi-manager array support")

    # 2. Update apk_sign.h
    sign_h = os.path.join(ksu_dir, "manager", "apk_sign.h")
    if os.path.exists(sign_h):
        with open(sign_h, "r", encoding="utf-8") as f:
            h_content = f.read()
        if "is_known_manager_pkg_name" not in h_content:
            helper = '''#include <linux/string.h>

static inline bool is_known_manager_pkg_name(const char *pkg)
{
    if (!pkg || !pkg[0])
        return false;
    if (!strcmp(pkg, "com.kowx712.supermanager") ||
        !strcmp(pkg, "me.weishu.kernelsu") ||
        !strcmp(pkg, "org.resukisu.resukisu") ||
        !strcmp(pkg, "com.resukisu") ||
        !strcmp(pkg, "com.sukisu.ultra") ||
        !strcmp(pkg, "org.bakasu.bakasu") ||
        !strcmp(pkg, "com.solohsu.kernelsu") ||
        !strcmp(pkg, KSU_PACKAGE_NAME))
        return true;
    return false;
}
'''
            h_content = h_content.replace("#endif", helper + "\n#endif")
            with open(sign_h, "w", encoding="utf-8") as f:
                f.write(h_content)
            print(f"[+] Patched {sign_h} with is_known_manager_pkg_name")

    # 3. Update apk_sign.c
    sign_c = os.path.join(ksu_dir, "manager", "apk_sign.c")
    patch_file(sign_c, [
        (
            "bool is_manager_apk(char *path)\n{\n    return check_v2_signature(path, EXPECTED_SIZE, EXPECTED_HASH);\n}",
            '''bool is_manager_apk(char *path)
{
    if (check_v2_signature(path, EXPECTED_SIZE, EXPECTED_HASH))
        return true;
    if (check_v2_signature(path, 0x339, "e573030d47d0f907be1843e936c568ae59560f4cf2fa0980ab260a9f5d1645e7"))
        return true;
    char pkg[KSU_MAX_PACKAGE_NAME];
    if (get_pkg_from_apk_dir_path(pkg, path) == 0) {
        if (is_known_manager_pkg_name(pkg)) {
            pr_info("KSU: Manager recognized by known package name: %s (%s)\\n", pkg, path);
            return true;
        }
    }
    return false;
}'''
        )
    ])

    # 4. Update throne_tracker.c
    throne_c = os.path.join(ksu_dir, "manager", "throne_tracker.c")
    patch_file(throne_c, [
        (
            "uid_t ksu_manager_appid = KSU_INVALID_APPID;",
            '''uid_t ksu_manager_appid = KSU_INVALID_APPID;
uid_t ksu_manager_appids[KSU_MAX_MANAGERS] = {
    [0 ... KSU_MAX_MANAGERS - 1] = KSU_INVALID_APPID
};'''
        ),
        (
            '''static void crown_manager(const char *apk, struct list_head *uid_data)
{
    struct list_head *list = (struct list_head *)uid_data;
    struct uid_data *np;

    list_for_each_entry (np, list, list) {
        if (strncmp(np->package, KSU_PACKAGE_NAME, KSU_MAX_PACKAGE_NAME) == 0) {
            pr_info("Crowning manager: uid=%d\\n", np->uid);
            ksu_set_manager_appid(np->uid);
            break;
        }
    }
}''',
            '''static void crown_manager(const char *apk, struct list_head *uid_data)
{
    struct list_head *list = (struct list_head *)uid_data;
    struct uid_data *np;

    list_for_each_entry (np, list, list) {
        if (is_known_manager_pkg_name(np->package)) {
            pr_info("Crowning manager: %s (uid=%d)\\n", np->package, np->uid);
            ksu_set_manager_appid(np->uid);
            ksu_add_manager_appid(np->uid);
        }
    }
}'''
        ),
        (
            '''static bool maybe_manager_apk_dir(const char *path)
{
    _Static_assert(sizeof(KSU_PACKAGE_NAME) < KSU_MAX_PACKAGE_NAME, "KSU_PACKAGE_NAME too long!");
    char pkg[KSU_MAX_PACKAGE_NAME];
    if (get_pkg_from_apk_dir_path(pkg, path) < 0) {
        pr_err("Failed to get package name from apk dir path: %s\\n", path);
        return false;
    }

    // pkg is `<real package>`
    return strncmp(pkg, KSU_PACKAGE_NAME, sizeof(KSU_PACKAGE_NAME)) == 0;
}''',
            '''static bool maybe_manager_apk_dir(const char *path)
{
    char pkg[KSU_MAX_PACKAGE_NAME];
    if (get_pkg_from_apk_dir_path(pkg, path) < 0) {
        pr_err("Failed to get package name from apk dir path: %s\\n", path);
        return false;
    }

    return is_known_manager_pkg_name(pkg);
}'''
        ),
        (
            '''    list_for_each_entry (np, &uid_list, list) {
        if (strcmp(np->package, KSU_PACKAGE_NAME) == 0) {
            manager_package_uid = np->uid;
            break;
        }
    }''',
            '''    list_for_each_entry (np, &uid_list, list) {
        if (is_known_manager_pkg_name(np->package)) {
            manager_package_uid = np->uid;
            ksu_add_manager_appid(np->uid);
            pr_info("Found manager in packages.list: %s, uid=%d\\n", np->package, np->uid);
        }
    }'''
        )
    ])

    # 5. Update supercall/perm.c
    perm_c = os.path.join(ksu_dir, "supercall", "perm.c")
    patch_file(perm_c, [
        (
            "bool only_manager(void)\n{\n    return is_manager();\n}",
            "bool only_manager(void)\n{\n    return current_uid().val == 0 || is_manager();\n}"
        )
    ])

    # 6. Update supercall/dispatch.c
    disp_c = os.path.join(ksu_dir, "supercall", "dispatch.c")
    patch_file(disp_c, [
        (
            '''.cmd = KSU_IOCTL_GET_APP_PROFILE,
        .name = "GET_APP_PROFILE",
        .handler = do_get_app_profile,
        .perm_check = only_manager
    },
    {
        .cmd = KSU_IOCTL_SET_APP_PROFILE,
        .name = "SET_APP_PROFILE",
        .handler = do_set_app_profile,
        .perm_check = only_manager''',
            '''.cmd = KSU_IOCTL_GET_APP_PROFILE,
        .name = "GET_APP_PROFILE",
        .handler = do_get_app_profile,
        .perm_check = manager_or_root
    },
    {
        .cmd = KSU_IOCTL_SET_APP_PROFILE,
        .name = "SET_APP_PROFILE",
        .handler = do_set_app_profile,
        .perm_check = manager_or_root'''
        )
    ])

    # 7. Update policy/allowlist.c
    allow_c = os.path.join(ksu_dir, "policy", "allowlist.c")
    patch_file(allow_c, [
        (
            '''    if (profile->version != KSU_APP_PROFILE_VER) {
        pr_info("Unsupported profile version: %d\\n", profile->version);
        return false;
    }''',
            '''    // Seamless Multi-Version App-Profile Support (v2, v3, v4)
    if (profile->version < 2 || profile->version > KSU_APP_PROFILE_VER) {
        pr_info("Unsupported profile version: %d\\n", profile->version);
        return false;
    }
    profile->version = KSU_APP_PROFILE_VER;'''
        ),
        (
            '''        static const size_t domain_len = sizeof(profile->rp_config.profile.selinux_domain);
        size_t len = strnlen(profile->rp_config.profile.selinux_domain, domain_len);

        if (len == 0 || len >= domain_len) {
            pr_err("invalid selinux_domain in app_profile: %s\\n", profile->key);
            return false;
        }''',
            '''        static const size_t domain_len = sizeof(profile->rp_config.profile.selinux_domain);
        size_t len = strnlen(profile->rp_config.profile.selinux_domain, domain_len);

        if (len == 0) {
            strscpy(profile->rp_config.profile.selinux_domain, "u:r:su:s0", domain_len);
            len = strlen(profile->rp_config.profile.selinux_domain);
        }

        if (len >= domain_len) {
            pr_err("invalid selinux_domain in app_profile: %s\\n", profile->key);
            return false;
        }'''
        )
    ])

    # 8. Update arm64/patch_memory.c for Linux 4.19 uaccess compatibility
    mem_c = os.path.join(ksu_dir, "hook", "arm64", "patch_memory.c")
    if os.path.exists(mem_c):
        with open(mem_c, "r", encoding="utf-8") as f:
            m_content = f.read()
        if "copy_to_kernel_nofault" in m_content and "probe_kernel_write" not in m_content:
            inject = '''#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 8, 0)
#ifndef copy_to_kernel_nofault
#define copy_to_kernel_nofault probe_kernel_write
#endif
#ifndef copy_from_kernel_nofault
#define copy_from_kernel_nofault probe_kernel_read
#endif
#endif
'''
            m_content = m_content.replace('#include "asm/cacheflush.h"', '#include "asm/cacheflush.h"\n' + inject)
            with open(mem_c, "w", encoding="utf-8") as f:
                f.write(m_content)
            print(f"[+] Patched {mem_c} with Linux 4.19 nofault fallback")

    # 9. Update core/init.c for Linux 4.19 MODULE_IMPORT_NS compatibility
    init_c = os.path.join(ksu_dir, "core", "init.c")
    patch_file(init_c, [
        (
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 13, 0)
MODULE_IMPORT_NS("VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver");
#else
MODULE_IMPORT_NS(VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver);
#endif''',
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 4, 0)
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 13, 0)
MODULE_IMPORT_NS("VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver");
#else
MODULE_IMPORT_NS(VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver);
#endif
#endif'''
        )
    ])

    # 10. Update Kbuild compiler flags for Linux 4.19 compatibility
    kbuild_file = os.path.join(ksu_dir, "Kbuild")
    if os.path.exists(kbuild_file):
        with open(kbuild_file, "r", encoding="utf-8") as f:
            kb_content = f.read()
        if "-Wno-implicit-int" not in kb_content:
            kb_content += "\nccflags-y += -Wno-implicit-int -Wno-incompatible-pointer-types\n"
            with open(kbuild_file, "w", encoding="utf-8") as f:
                f.write(kb_content)
            print(f"[+] Patched {kbuild_file} with -Wno-implicit-int")

    print("🎉 KowSU Multi-Manager & App Profile Patching Completed Successfully!")
    return 0

if __name__ == "__main__":
    sys.exit(main())

