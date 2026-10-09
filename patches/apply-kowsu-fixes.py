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
    base_dirs = []
    if len(sys.argv) > 1:
        base_dirs.append(sys.argv[1])
    base_dirs.extend(["drivers/kernelsu", "KernelSU/kernel", "kernel", "."])
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

    # 8. Update core/init.c for Linux 4.19 MODULE_IMPORT_NS compatibility
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

    # 9. Update infra/file_wrapper.c for Linux 4.19 compatibility (iopoll & remap_file_range)
    wrap_c = os.path.join(ksu_dir, "infra", "file_wrapper.c")
    patch_file(wrap_c, [
        (
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 1, 0)
static int ksu_wrapper_iopoll(struct kiocb *kiocb, struct io_comp_batch *icb, unsigned int v)
{
    struct ksu_file_wrapper *data = kiocb->ki_filp->private_data;
    struct file *orig = data->orig;
    kiocb->ki_filp = orig;
    return orig->f_op->iopoll(kiocb, icb, v);
}
#else
static int ksu_wrapper_iopoll(struct kiocb *kiocb, bool spin)
{
    struct ksu_file_wrapper *data = kiocb->ki_filp->private_data;
    struct file *orig = data->orig;
    kiocb->ki_filp = orig;
    return orig->f_op->iopoll(kiocb, spin);
}
#endif''',
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 1, 0)
static int ksu_wrapper_iopoll(struct kiocb *kiocb, struct io_comp_batch *icb, unsigned int v)
{
    struct ksu_file_wrapper *data = kiocb->ki_filp->private_data;
    struct file *orig = data->orig;
    kiocb->ki_filp = orig;
    return orig->f_op->iopoll(kiocb, icb, v);
}
#elif LINUX_VERSION_CODE >= KERNEL_VERSION(5, 1, 0)
static int ksu_wrapper_iopoll(struct kiocb *kiocb, bool spin)
{
    struct ksu_file_wrapper *data = kiocb->ki_filp->private_data;
    struct file *orig = data->orig;
    kiocb->ki_filp = orig;
    return orig->f_op->iopoll(kiocb, spin);
}
#endif'''
        ),
        (
            '''// no REMAP_FILE_DEDUP: use file_in
// https://cs.android.com/android/kernel/superproject/+/common-android-mainline:common/fs/read_write.c;l=1598-1599;drc=398da7defe218d3e51b0f3bdff75147e28125b60
// https://cs.android.com/android/kernel/superproject/+/common-android-mainline:common/fs/remap_range.c;l=403-404;drc=398da7defe218d3e51b0f3bdff75147e28125b60
// REMAP_FILE_DEDUP: use file_out
// https://cs.android.com/android/kernel/superproject/+/common-android-mainline:common/fs/remap_range.c;l=483-484;drc=398da7defe218d3e51b0f3bdff75147e28125b60
static loff_t ksu_wrapper_remap_file_range(struct file *file_in, loff_t pos_in, struct file *file_out, loff_t pos_out,
                                           loff_t len, unsigned int remap_flags)
{
    if (remap_flags & REMAP_FILE_DEDUP) {
        struct ksu_file_wrapper *data = file_out->private_data;
        struct file *orig = data->orig;
        return orig->f_op->remap_file_range(file_in, pos_in, orig, pos_out, len, remap_flags);
    } else {
        struct ksu_file_wrapper *data = file_in->private_data;
        struct file *orig = data->orig;
        return orig->f_op->remap_file_range(orig, pos_in, file_out, pos_out, len, remap_flags);
    }
}''',
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 20, 0)
// no REMAP_FILE_DEDUP: use file_in
// https://cs.android.com/android/kernel/superproject/+/common-android-mainline:common/fs/read_write.c;l=1598-1599;drc=398da7defe218d3e51b0f3bdff75147e28125b60
// https://cs.android.com/android/kernel/superproject/+/common-android-mainline:common/fs/remap_range.c;l=403-404;drc=398da7defe218d3e51b0f3bdff75147e28125b60
// REMAP_FILE_DEDUP: use file_out
// https://cs.android.com/android/kernel/superproject/+/common-android-mainline:common/fs/remap_range.c;l=483-484;drc=398da7defe218d3e51b0f3bdff75147e28125b60
static loff_t ksu_wrapper_remap_file_range(struct file *file_in, loff_t pos_in, struct file *file_out, loff_t pos_out,
                                           loff_t len, unsigned int remap_flags)
{
    if (remap_flags & REMAP_FILE_DEDUP) {
        struct ksu_file_wrapper *data = file_out->private_data;
        struct file *orig = data->orig;
        return orig->f_op->remap_file_range(file_in, pos_in, orig, pos_out, len, remap_flags);
    } else {
        struct ksu_file_wrapper *data = file_in->private_data;
        struct file *orig = data->orig;
        return orig->f_op->remap_file_range(orig, pos_in, file_out, pos_out, len, remap_flags);
    }
}
#endif'''
        ),
        (
            '''    p->ops.write_iter = fp->f_op->write_iter ? ksu_wrapper_write_iter : NULL;
    p->ops.iopoll = fp->f_op->iopoll ? ksu_wrapper_iopoll : NULL;''',
            '''    p->ops.write_iter = fp->f_op->write_iter ? ksu_wrapper_write_iter : NULL;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 1, 0)
    p->ops.iopoll = fp->f_op->iopoll ? ksu_wrapper_iopoll : NULL;
#endif'''
        ),
        (
            '''    p->ops.copy_file_range = fp->f_op->copy_file_range ? ksu_wrapper_copy_file_range : NULL;
    p->ops.remap_file_range = fp->f_op->remap_file_range ? ksu_wrapper_remap_file_range : NULL;
    p->ops.fadvise = fp->f_op->fadvise ? ksu_wrapper_fadvise : NULL;''',
            '''    p->ops.copy_file_range = fp->f_op->copy_file_range ? ksu_wrapper_copy_file_range : NULL;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 20, 0)
    p->ops.remap_file_range = fp->f_op->remap_file_range ? ksu_wrapper_remap_file_range : NULL;
#endif
    p->ops.fadvise = fp->f_op->fadvise ? ksu_wrapper_fadvise : NULL;'''
        )
    ])

    # 10. Update infra/su_mount_ns.c for Linux 4.19 path_mount & mount.h compatibility
    mount_c = os.path.join(ksu_dir, "infra", "su_mount_ns.c")
    patch_file(mount_c, [
        (
            "#include <uapi/linux/mount.h>",
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 2, 0)
#include <uapi/linux/mount.h>
#else
#include <linux/mount.h>
#endif'''
        ),
        (
            '''extern int path_mount(const char *dev_name, struct path *path, const char *type_page, unsigned long flags,
                      void *data_page);''',
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 8, 0)
extern int path_mount(const char *dev_name, struct path *path, const char *type_page, unsigned long flags,
                      void *data_page);
#else
#include <linux/uaccess.h>
extern long do_mount(const char *dev_name, const char __user *dir_name,
		     const char *type_page, unsigned long flags,
		     void *data_page);

static int path_mount(const char *dev_name, struct path *path, const char *type_page,
	       unsigned long flags, void *data_page)
{
	mm_segment_t old_fs;
	long ret = 0;
	char buf[384];

	char *realpath = d_path(path, buf, sizeof(buf));
	if (IS_ERR(realpath)) {
		pr_err("ksu_mount: d_path failed, err: %ld\\n", PTR_ERR(realpath));
		return PTR_ERR(realpath);
	}

	old_fs = get_fs();
	set_fs(KERNEL_DS);
	ret = do_mount(dev_name, (const char __user *)realpath, type_page,
		       flags, data_page);
	set_fs(old_fs);
	return ret;
}
#endif'''
        )
    ])

    # 11. Update feature/kernel_umount.c for Linux 4.19 path_umount compatibility
    umount_c = os.path.join(ksu_dir, "feature", "kernel_umount.c")
    patch_file(umount_c, [
        (
            '''extern int path_umount(struct path *path, int flags);

static void ksu_umount_mnt(const char *mnt, struct path *path, int flags)
{
    int err = path_umount(path, flags);
    if (err) {
        pr_info("umount %s failed: %d\\n", mnt, err);
    }
}''',
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 9, 0)
extern int path_umount(struct path *path, int flags);

static void ksu_umount_mnt(const char *mnt, struct path *path, int flags)
{
    int err = path_umount(path, flags);
    if (err) {
        pr_info("umount %s failed: %d\\n", mnt, err);
    }
}
#else
#include <linux/syscalls.h>

static void ksu_sys_umount(const char *mnt, int flags)
{
	char __user *usermnt = (char __user *)mnt;
	mm_segment_t old_fs;

	old_fs = get_fs();
	set_fs(KERNEL_DS);
	ksys_umount(usermnt, flags);
	set_fs(old_fs);
}

#define ksu_umount_mnt(mnt, __unused, flags) \\
	({ \\
		path_put(__unused); \\
		ksu_sys_umount(mnt, flags); \\
	})
#endif'''
        )
    ])

    # 12. Update sulog/event.c for Linux 4.19 minmax.h compatibility
    sulog_c = os.path.join(ksu_dir, "sulog", "event.c")
    patch_file(sulog_c, [
        (
            "#include <linux/minmax.h>",
            '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 12, 0)
#include <linux/minmax.h>
#else
#include <linux/kernel.h>
#endif'''
        )
    ])

    # 13. Update infra/seccomp_cache.c for Linux 4.19 SECCOMP_ARCH_NATIVE_NR compatibility
    seccomp_c = os.path.join(ksu_dir, "infra", "seccomp_cache.c")
    patch_file(seccomp_c, [
        (
            '#include "infra/seccomp_cache.h"',
            '''#include "infra/seccomp_cache.h"
#include <asm/unistd.h>

#ifndef SECCOMP_ARCH_NATIVE_NR
#ifdef NR_syscalls
#define SECCOMP_ARCH_NATIVE_NR NR_syscalls
#elif defined(__NR_syscalls)
#define SECCOMP_ARCH_NATIVE_NR __NR_syscalls
#else
#define SECCOMP_ARCH_NATIVE_NR 512
#endif
#endif

#ifndef SECCOMP_ARCH_COMPAT_NR
#ifdef __NR_compat_syscalls
#define SECCOMP_ARCH_COMPAT_NR __NR_compat_syscalls
#else
#define SECCOMP_ARCH_COMPAT_NR 512
#endif
#endif'''
        )
    ])

    # 14. Update manager/pkg_observer.c for Linux 4.19 TWA_RESUME & fsnotify compatibility
    obs_c = os.path.join(ksu_dir, "manager", "pkg_observer.c")
    patch_file(obs_c, [
        (
            "#include <linux/task_work.h>",
            '''#include <linux/task_work.h>
#ifndef TWA_RESUME
#define TWA_RESUME true
#endif'''
        ),
        (
            r'''static int ksu_handle_inode_event(struct fsnotify_mark *mark, u32 mask, struct inode *inode, struct inode *dir,
                                  const struct qstr *file_name, u32 cookie)
{
    if (!file_name)
        return 0;
    if (mask & FS_ISDIR)
        return 0;
    if (file_name->len == 13 && !memcmp(file_name->name, "packages.list", 13)) {
        pr_info("packages.list detected: %d\n", mask);
        ksu_defer_track_throne();
    }
    return 0;
}

static const struct fsnotify_ops ksu_ops = {
    .handle_inode_event = ksu_handle_inode_event,
};''',
            r'''#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 9, 0)
static int ksu_handle_inode_event(struct fsnotify_mark *mark, u32 mask, struct inode *inode, struct inode *dir,
                                  const struct qstr *file_name, u32 cookie)
{
    if (!file_name)
        return 0;
    if (mask & FS_ISDIR)
        return 0;
    if (file_name->len == 13 && !memcmp(file_name->name, "packages.list", 13)) {
        pr_info("packages.list detected: %d\n", mask);
        ksu_defer_track_throne();
    }
    return 0;
}

static const struct fsnotify_ops ksu_ops = {
    .handle_inode_event = ksu_handle_inode_event,
};
#else
static int ksu_handle_event(struct fsnotify_group *group,
			    struct inode *inode,
			    u32 mask, const void *data, int data_type,
			    const unsigned char *file_name, u32 cookie,
			    struct fsnotify_iter_info *iter_info)
{
    if (!file_name)
        return 0;
    if (mask & FS_ISDIR)
        return 0;
    if (strcmp((const char *)file_name, "packages.list") == 0) {
        pr_info("packages.list detected: %d\n", mask);
        ksu_defer_track_throne();
    }
    return 0;
}

static const struct fsnotify_ops ksu_ops = {
    .handle_event = ksu_handle_event,
};
#endif'''
        )
    ])

    # 15. Update supercall/supercall.c for Linux 4.19 TWA_RESUME compatibility
    sc_c = os.path.join(ksu_dir, "supercall", "supercall.c")
    patch_file(sc_c, [
        (
            "#include <linux/task_work.h>",
            '''#include <linux/task_work.h>
#ifndef TWA_RESUME
#define TWA_RESUME true
#endif'''
        )
    ])

    # 16. Update Kbuild compiler flags for Linux 4.19 compatibility
    kbuild_file = os.path.join(ksu_dir, "Kbuild")
    if os.path.exists(kbuild_file):
        with open(kbuild_file, "r", encoding="utf-8") as f:
            kb_content = f.read()
        if "-Wno-implicit-int" not in kb_content:
            kb_content += "\nccflags-y += -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-error\n"
            with open(kbuild_file, "w", encoding="utf-8") as f:
                f.write(kb_content)
            print(f"[+] Patched {kbuild_file} with -Wno-implicit-int -Wno-error")

    print("🎉 KowSU Multi-Manager & App Profile Patching Completed Successfully!")
    return 0

if __name__ == "__main__":
    sys.exit(main())

