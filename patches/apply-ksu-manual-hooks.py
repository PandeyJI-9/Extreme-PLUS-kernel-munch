#!/usr/bin/env python3
# ==============================================================================
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
# KernelSU manual-hook port for the susfs-free ("NoSuSFS") kernel variant.
#
# The AstideLabs base only wires KernelSU up through the SuSFS inline hook, so
# a build with CONFIG_KSU_SUSFS=n has no usable hook and would link/root-fail.
# ReSukiSU still hard-errors on the tracepoint hook for non-GKI 4.19, which
# leaves the manual hook (CONFIG_KSU_MANUAL_HOOK) as the only susfs-free path.
#
# This ports the required manual hook call sites, following the ReSukiSU
# manual-integrate reference for 4.19:
#   fs/stat.c        ksu_handle_stat + ksu_handle_newfstat_ret/fstat64_ret
#   fs/open.c        ksu_handle_faccessat
#   fs/exec.c        ksu_handle_execveat + ksu_handle_post_execveat
#   kernel/reboot.c  ksu_handle_sys_reboot
#
# Everything is wrapped in CONFIG_KSU_MANUAL_HOOK, so SuSFS builds are
# byte-for-byte unaffected.
# ==============================================================================
import os
import sys

MARK = "EXTREME++ KSU MANUAL HOOK"


def patch_file(path: str, edits) -> int:
    if not os.path.exists(path):
        print(f"❌ [KSU MANUAL HOOK] missing {path}")
        return 1

    with open(path) as f:
        text = f.read()

    if MARK in text:
        print(f"ℹ️ [KSU MANUAL HOOK] {path} already patched")
        return 0

    for old, new in edits:
        if text.count(old) != 1:
            print(f"❌ [KSU MANUAL HOOK] anchor not found exactly once in {path}: {old.splitlines()[0][:70]}")
            return 1
        text = text.replace(old, new, 1)

    with open(path, "w") as f:
        f.write(text)

    print(f"✅ [KSU MANUAL HOOK] patched {path}")
    return 0


STAT_EXTERNS = f"""/* {MARK}: required by CONFIG_KSU_MANUAL_HOOK */
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_stat(int *dfd, const char __user **filename_user,
			   int *flags);
extern void ksu_handle_newfstat_ret(unsigned int *fd,
				    struct stat __user **statbuf_ptr);
#if defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_COMPAT_STAT64)
extern void ksu_handle_fstat64_ret(unsigned long *fd,
				   struct stat64 __user **statbuf_ptr);
#endif
#endif

"""


def patch_stat(src: str) -> int:
    path = os.path.join(src, "fs/stat.c")
    edits = [
        # externs before the first hooked syscall
        (
            "SYSCALL_DEFINE4(newfstatat, int, dfd, const char __user *, filename,",
            STAT_EXTERNS + "SYSCALL_DEFINE4(newfstatat, int, dfd, const char __user *, filename,",
        ),
        # newfstatat(): lookup hook on the user pointer, before vfs_fstatat
        (
            """SYSCALL_DEFINE4(newfstatat, int, dfd, const char __user *, filename,
		struct stat __user *, statbuf, int, flag)
{
	struct kstat stat;
	int error;

	error = vfs_fstatat(dfd, filename, &stat, flag);""",
            """SYSCALL_DEFINE4(newfstatat, int, dfd, const char __user *, filename,
		struct stat __user *, statbuf, int, flag)
{
	struct kstat stat;
	int error;

#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_stat(&dfd, &filename, &flag);
#endif
	error = vfs_fstatat(dfd, filename, &stat, flag);""",
        ),
        # newfstat(): return-value hook so init.rc size spoofing works
        (
            """SYSCALL_DEFINE2(newfstat, unsigned int, fd, struct stat __user *, statbuf)
{
	struct kstat stat;
	int error = vfs_fstat(fd, &stat);

	if (!error)
		error = cp_new_stat(&stat, statbuf);

	return error;
}""",
            """SYSCALL_DEFINE2(newfstat, unsigned int, fd, struct stat __user *, statbuf)
{
	struct kstat stat;
	int error = vfs_fstat(fd, &stat);

	if (!error)
		error = cp_new_stat(&stat, statbuf);

#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_newfstat_ret(&fd, &statbuf);
#endif
	return error;
}""",
        ),
        # fstat64(): 32-bit su
        (
            """SYSCALL_DEFINE2(fstat64, unsigned long, fd, struct stat64 __user *, statbuf)
{
	struct kstat stat;
	int error = vfs_fstat(fd, &stat);

	if (!error)
		error = cp_new_stat64(&stat, statbuf);

	return error;
}""",
            """SYSCALL_DEFINE2(fstat64, unsigned long, fd, struct stat64 __user *, statbuf)
{
	struct kstat stat;
	int error = vfs_fstat(fd, &stat);

	if (!error)
		error = cp_new_stat64(&stat, statbuf);

#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_fstat64_ret(&fd, &statbuf);
#endif
	return error;
}""",
        ),
        # fstatat64(): 32-bit path lookup hook
        (
            """SYSCALL_DEFINE4(fstatat64, int, dfd, const char __user *, filename,
		struct stat64 __user *, statbuf, int, flag)
{
	struct kstat stat;
	int error;

	error = vfs_fstatat(dfd, filename, &stat, flag);""",
            """SYSCALL_DEFINE4(fstatat64, int, dfd, const char __user *, filename,
		struct stat64 __user *, statbuf, int, flag)
{
	struct kstat stat;
	int error;

#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_stat(&dfd, &filename, &flag);
#endif
	error = vfs_fstatat(dfd, filename, &stat, flag);""",
        ),
    ]
    return patch_file(path, edits)


OPEN_EXTERNS = f"""/* {MARK}: required by CONFIG_KSU_MANUAL_HOOK */
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,
				int *mode, int *flags);
#endif

"""


def patch_open(src: str) -> int:
    path = os.path.join(src, "fs/open.c")
    edits = [
        (
            "SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename, int, mode)\n{\n\treturn do_faccessat(dfd, filename, mode);\n}",
            OPEN_EXTERNS
            + "SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename, int, mode)\n{\n#ifdef CONFIG_KSU_MANUAL_HOOK\n\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n#endif\n\treturn do_faccessat(dfd, filename, mode);\n}",
        ),
    ]
    return patch_file(path, edits)


EXEC_EXTERNS = f"""/* {MARK}: required by CONFIG_KSU_MANUAL_HOOK */
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr,
			       void *argv, void *envp, int *flags);
__attribute__((hot))
extern int ksu_handle_post_execveat(int *fd, struct filename **filename_ptr,
				    void *argv, void *envp, int *flags,
				    int *retval);
#endif

"""


def patch_exec(src: str) -> int:
    path = os.path.join(src, "fs/exec.c")
    old = """static int do_execveat_common(int fd, struct filename *filename,
			      struct user_arg_ptr argv,
			      struct user_arg_ptr envp,
			      int flags)
{
	return __do_execve_file(fd, filename, argv, envp, flags, NULL);
}"""
    new = (
        EXEC_EXTERNS
        + """static int do_execveat_common(int fd, struct filename *filename,
			      struct user_arg_ptr argv,
			      struct user_arg_ptr envp,
			      int flags)
{
#ifdef CONFIG_KSU_MANUAL_HOOK
	int retval;

	ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);
	retval = __do_execve_file(fd, filename, argv, envp, flags, NULL);
	ksu_handle_post_execveat(&fd, &filename, &argv, &envp, &flags, &retval);
	return retval;
#else
	return __do_execve_file(fd, filename, argv, envp, flags, NULL);
#endif
}"""
    )
    return patch_file(path, [(old, new)])


def patch_reboot(src: str) -> int:
    path = os.path.join(src, "kernel/reboot.c")
    if not os.path.exists(path):
        print(f"❌ [KSU MANUAL HOOK] missing {path}")
        return 1

    with open(path) as f:
        text = f.read()

    guard = "#ifdef CONFIG_KSU_SUSFS"
    extern = "extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);"
    call = "ksu_handle_sys_reboot(magic1, magic2, cmd, &arg);"

    if MARK in text:
        print(f"ℹ️ [KSU MANUAL HOOK] {path} already patched")
        return 0

    replaced = 0
    for anchor in (extern, call):
        idx = text.find(anchor)
        if idx == -1:
            print(f"❌ [KSU MANUAL HOOK] reboot hook anchor missing: {anchor[:40]}")
            return 1
        guard_idx = text.rfind(guard, 0, idx)
        if guard_idx == -1 or text[guard_idx:idx].count("#endif"):
            print("❌ [KSU MANUAL HOOK] sys_reboot hook is not wrapped in CONFIG_KSU_SUSFS")
            return 1
        text = (
            text[:guard_idx]
            + f"/* {MARK} */\n#if defined(CONFIG_KSU_SUSFS) || defined(CONFIG_KSU_MANUAL_HOOK)"
            + text[guard_idx + len(guard):]
        )
        replaced += 1

    with open(path, "w") as f:
        f.write(text)

    print(f"✅ [KSU MANUAL HOOK] patched {path} ({replaced} guards)")
    return 0


def patch_read_write(src: str) -> int:
    """The init.rc read hook only exists in the tracepoint/susfs KSU builds.

    The base guards the call sites with CONFIG_KSU, which leaves manual-hook
    builds referencing ksu_is_init_rc_hook_enabled, a symbol that is not
    defined there (link error).  The manual hook uses the LSM init-rc hook
    instead, so the syscall hook must be compiled out.
    """
    path = os.path.join(src, "fs/read_write.c")
    edits = [
        (
            """#ifdef CONFIG_KSU
extern struct static_key_true ksu_is_init_rc_hook_enabled;
extern __attribute__((cold)) int ksu_handle_sys_read(unsigned int fd);
#endif""",
            """/* EXTREME++ KSU MANUAL HOOK: only the susfs/tracepoint builds define this */
#ifdef CONFIG_KSU_SUSFS
extern struct static_key_true ksu_is_init_rc_hook_enabled;
extern __attribute__((cold)) int ksu_handle_sys_read(unsigned int fd);
#endif""",
        ),
        (
            """#ifdef CONFIG_KSU
	if (static_branch_unlikely(&ksu_is_init_rc_hook_enabled))
		ksu_handle_sys_read(fd);
#endif""",
            """#ifdef CONFIG_KSU_SUSFS
	if (static_branch_unlikely(&ksu_is_init_rc_hook_enabled))
		ksu_handle_sys_read(fd);
#endif""",
        ),
    ]
    return patch_file(path, edits)


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else "."
    for fn in (patch_stat, patch_open, patch_exec, patch_reboot, patch_read_write):
        if fn(src) != 0:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
