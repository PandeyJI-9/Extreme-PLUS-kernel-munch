#!/usr/bin/env python3
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
"""
Keep EXTREME++ in UTS_RELEASE (uname -r) while preserving the stock vendor
module ABI release in VERMAGIC_STRING.

Android's module loader compares a module's vermagic against VERMAGIC_STRING.
For modules that carry CRC versions, the release prefix is ignored; for older
modules without CRC data, this stock fallback keeps the exact release match.
"""

from pathlib import Path
import os
import re

MARK = "EXTREME_VENDOR_UTS_RELEASE"
DEFAULT_STOCK_RELEASE = "4.19.325-zyndong-perf-g7e817c4ca270"
DEFINE_RE = re.compile(r'(#define\s+EXTREME_VENDOR_UTS_RELEASE\s+")[^"]*(")')


def main() -> None:
    stock_release = (os.environ.get("EXTREME_VENDOR_RELEASE") or DEFAULT_STOCK_RELEASE).strip()
    path = Path("include/linux/vermagic.h")
    if not path.exists():
        raise SystemExit("missing include/linux/vermagic.h")

    text = path.read_text()
    old = '\tUTS_RELEASE " "'
    new = f'\t{MARK} " "'

    if MARK in text:
        original = text
        text, changed = DEFINE_RE.subn(rf'\g<1>{stock_release}\g<2>', text, count=1)
        if changed == 0:
            raise SystemExit(f"{MARK} block found without a parseable define")
        text = text.replace(old, new, 1)
        if f'{MARK} " "' not in text:
            raise SystemExit("VERMAGIC_STRING does not reference the stock release")
        if text != original:
            path.write_text(text)
        print(f"EXTREME++ stock-vermagic compatibility active: {stock_release}")
        return

    if "#define VERMAGIC_STRING" not in text:
        raise SystemExit("VERMAGIC_STRING definition not found")

    marker = (
        f"/* {MARK}: stock vendor-module ABI release. EXTREME++ branding lives in\n"
        f" * UTS_RELEASE (uname -r); this fallback keeps non-CRC vendor modules loading.\n"
        f" */\n"
        f'#define {MARK} "{stock_release}"\n\n'
    )
    text = text.replace("#define VERMAGIC_STRING", marker + "#define VERMAGIC_STRING", 1)

    if old not in text:
        raise SystemExit("VERMAGIC_STRING UTS_RELEASE entry not found")

    text = text.replace(old, new, 1)
    path.write_text(text)
    print(f"Pinned vendor-module vermagic to stock release: {stock_release}")


if __name__ == "__main__":
    main()
