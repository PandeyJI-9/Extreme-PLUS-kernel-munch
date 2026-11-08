#!/usr/bin/env python3
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
"""
Keep the EXTREME++ identity visible without changing the stock HyperOS
UTS_RELEASE string.

Android vendor modules are matched against UTS_RELEASE (the kernel release),
so changing it is what caused the previous vendor-module/camera mismatch.
The EXTREME++ name is therefore injected into UTS_VERSION (uname -v, dmesg)
and linux_proc_banner (/proc/version) instead.
"""

from pathlib import Path


def patch_mkcompile_h() -> None:
    path = Path("scripts/mkcompile_h")
    if not path.exists():
        raise SystemExit("missing scripts/mkcompile_h")

    text = path.read_text()
    if 'UTS_VERSION="EXTREME++ #$VERSION"' in text:
        print("EXTREME++ branding already present in scripts/mkcompile_h")
        return

    old = 'UTS_VERSION="#$VERSION"'
    new = 'UTS_VERSION="EXTREME++ #$VERSION"'
    if old not in text:
        raise SystemExit("mkcompile_h UTS_VERSION pattern not found")

    path.write_text(text.replace(old, new, 1))
    print("Added EXTREME++ to UTS_VERSION (uname -v and dmesg)")


def patch_proc_banner() -> None:
    path = Path("init/version.c")
    if not path.exists():
        print("init/version.c not found; UTS_VERSION branding is still active")
        return

    text = path.read_text()
    if 'EXTREME++ %s version %s' in text:
        print("EXTREME++ branding already present in /proc/version banner")
        return

    old = 'const char linux_proc_banner[] =\n\t"%s version %s"'
    new = 'const char linux_proc_banner[] =\n\t"EXTREME++ %s version %s"'
    if old not in text:
        raise SystemExit("linux_proc_banner pattern not found")

    path.write_text(text.replace(old, new, 1))
    print("Added EXTREME++ to /proc/version banner")


def main() -> None:
    patch_mkcompile_h()
    patch_proc_banner()


if __name__ == "__main__":
    main()
