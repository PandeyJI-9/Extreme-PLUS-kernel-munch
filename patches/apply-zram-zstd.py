#!/usr/bin/env python3
# PROJECT EXTREME++ | Maintainer: PandeyJI-9
"""
Switch ZRAM's default compressor to ZSTD and expose a safe compression-level
tunable.

Level 3 is the standard ZSTD ratio/speed sweet spot. The runtime tunable lets
a rooted user lower it to 1 if a specific workload needs less CPU time, or
raise it for more memory savings:

    /sys/module/zstd/parameters/compression_level

LZO remains compiled because some stock vendor modules may import its symbols;
it is no longer the default ZRAM compressor.
"""

from pathlib import Path
import re

MARK = "EXTREME++ ZRAM ZSTD"


def patch_zstd_driver() -> None:
    path = Path("crypto/zstd.c")
    if not path.exists():
        raise SystemExit("missing crypto/zstd.c")

    text = path.read_text()
    if MARK in text:
        print("ZRAM ZSTD patch already applied")
        return

    text, replacements = re.subn(
        r"#define\s+ZSTD_DEF_LEVEL\s+1\b",
        "#define ZSTD_DEF_LEVEL\t3",
        text,
        count=1,
    )
    if replacements != 1:
        raise SystemExit("crypto/zstd.c ZSTD_DEF_LEVEL pattern not found")

    old = (
        "static zstd_parameters zstd_params(void)\n"
        "{\n"
        "\treturn zstd_get_params(ZSTD_DEF_LEVEL, PAGE_SIZE);\n"
        "}\n"
    )
    new = f"""/* {MARK}: level 3 is the default ratio/speed sweet spot.
 * The level is exposed as
 * /sys/module/zstd/parameters/compression_level for runtime tuning.
 */
static int zstd_level = ZSTD_DEF_LEVEL;
module_param_named(compression_level, zstd_level, int, 0644);
MODULE_PARM_DESC(compression_level, "ZSTD compression level (1-22)");

static zstd_parameters zstd_params(void)
{{
\tint level = zstd_level;

\tif (level < 1)
\t\tlevel = 1;
\telse if (level > 22)
\t\tlevel = 22;

\treturn zstd_get_params(level, PAGE_SIZE);
}}
"""
    if old not in text:
        raise SystemExit("crypto/zstd.c zstd_params() pattern not found")

    path.write_text(text.replace(old, new, 1))
    print("Set ZSTD default level 3 and added compression_level sysfs tunable")


def patch_zram_kconfig() -> None:
    path = Path("drivers/block/zram/Kconfig")
    if not path.exists():
        raise SystemExit("missing drivers/block/zram/Kconfig")

    text = path.read_text()
    if 'default ZRAM_DEF_COMP_ZSTD\n' in text:
        print("ZRAM Kconfig already defaults to ZSTD")
        return

    old = '\tdefault ZRAM_DEF_COMP_LZORLE\n'
    new = '\tdefault ZRAM_DEF_COMP_ZSTD\n'
    if old not in text:
        raise SystemExit("ZRAM Kconfig default-compressor pattern not found")

    path.write_text(text.replace(old, new, 1))
    print("Changed the ZRAM Kconfig default compressor to ZSTD")


def main() -> None:
    patch_zstd_driver()
    patch_zram_kconfig()


if __name__ == "__main__":
    main()
