#!/usr/bin/env python3
"""Repack a HyperOS boot/vendor_boot with a replacement kernel and DTB.

The stock images are used only as containers:
  boot.img        -> replace the kernel, preserve ramdisk + boot header
  vendor_boot.img -> replace the DTB, preserve vendor ramdisk + header,
                     then regenerate the vendor_boot AVB hash footer
  dtbo.img        -> copied unchanged

The output images keep the stock partition sizes so they can replace the
stock files directly.  The stock boot image used by these ports normally has
no AVB footer; the vbmeta image is expected to have verification disabled.
The vendor_boot footer is hash-only ("Algorithm: NONE") on the tested images,
so it can be regenerated without a private key.
"""

from __future__ import annotations

import argparse
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


BOOT_MAGIC = b"ANDROID!"
VENDOR_BOOT_MAGIC = b"VNDRBOOT"
PAGE_SIZE = 4096


def align(value: int, alignment: int) -> int:
    return (value + alignment - 1) // alignment * alignment


def parse_boot_header(data: bytes) -> tuple[int, int, int]:
    if data[:8] != BOOT_MAGIC:
        raise ValueError("boot.img: bad ANDROID! magic")
    kernel_size, ramdisk_size = struct.unpack_from("<II", data, 8)
    header_size = struct.unpack_from("<I", data, 20)[0]
    header_version = struct.unpack_from("<I", data, 40)[0]
    if header_version not in (3, 4):
        raise ValueError(f"boot.img: unsupported header version {header_version}")
    if header_size not in (1580, 1584):
        raise ValueError(f"boot.img: unexpected header size {header_size}")
    return kernel_size, ramdisk_size, header_size


def repack_boot(stock_path: Path, kernel_path: Path, out_path: Path) -> None:
    stock = stock_path.read_bytes()
    kernel = kernel_path.read_bytes()
    kernel_size, ramdisk_size, header_size = parse_boot_header(stock)

    header = bytearray(stock[:header_size])
    struct.pack_into("<I", header, 8, len(kernel))

    offset = header_size
    kernel_offset = align(offset, PAGE_SIZE)
    ramdisk_offset = align(kernel_offset + len(kernel), PAGE_SIZE)
    stock_ramdisk_offset = align(kernel_offset + kernel_size, PAGE_SIZE)
    content_end = align(ramdisk_offset + ramdisk_size, PAGE_SIZE)
    if content_end > len(stock):
        raise ValueError("boot.img: replacement kernel does not fit in the stock image")

    out = bytearray(len(stock))
    out[:header_size] = header
    out[kernel_offset:kernel_offset + len(kernel)] = kernel
    out[ramdisk_offset:ramdisk_offset + ramdisk_size] = stock[
        stock_ramdisk_offset:stock_ramdisk_offset + ramdisk_size
    ]
    out_path.write_bytes(out)


def parse_vendor_header(data: bytes) -> tuple[int, int, int, int]:
    if data[:8] != VENDOR_BOOT_MAGIC:
        raise ValueError("vendor_boot.img: bad VNDRBOOT magic")
    header_version = struct.unpack_from("<I", data, 8)[0]
    if header_version not in (3, 4):
        raise ValueError(f"vendor_boot.img: unsupported header version {header_version}")
    page_size = struct.unpack_from("<I", data, 12)[0]
    vendor_ramdisk_size = struct.unpack_from("<I", data, 24)[0]
    header_size = struct.unpack_from("<I", data, 2096)[0]
    dtb_size = struct.unpack_from("<I", data, 2100)[0]
    return vendor_ramdisk_size, dtb_size, page_size, header_size


def vendor_layout(data: bytes) -> tuple[int, int, int, int, int]:
    vendor_ramdisk_size, dtb_size, page_size, header_size = parse_vendor_header(data)
    ramdisk_offset = align(header_size, page_size)
    dtb_offset = align(ramdisk_offset + vendor_ramdisk_size, page_size)
    content_end = align(dtb_offset + dtb_size, page_size)
    return page_size, header_size, vendor_ramdisk_size, dtb_offset, content_end


def read_avb_footer_info(avbtool: str, image: Path) -> tuple[bool, dict[str, str], list[tuple[str, str]]]:
    proc = subprocess.run(
        [avbtool, "info_image", "--image", str(image)],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        return False, {}, []
    text = proc.stdout
    info: dict[str, str] = {}
    for key, pattern in {
        "salt": r"^\s*Salt:\s*([0-9a-fA-F]+)\s*$",
        "algorithm": r"^\s*Algorithm:\s*(\S+)\s*$",
        "partition": r"^\s*Partition Name:\s*(\S+)\s*$",
        "flags": r"^\s*Flags:\s*(\d+)\s*$",
        "rollback": r"^\s*Rollback Index:\s*(\d+)\s*$",
        "rollback_location": r"^\s*Rollback Index Location:\s*(\d+)\s*$",
    }.items():
        match = re.search(pattern, text, re.MULTILINE)
        if match:
            info[key] = match.group(1)

    props = re.findall(r"^\s*Prop:\s*(\S+)\s*->\s*'([^']*)'\s*$", text, re.MULTILINE)

    if info.get("algorithm", "").upper() not in ("", "NONE"):
        raise ValueError(
            "vendor_boot.img: AVB footer is signed; cannot regenerate it without the ROM signing key"
        )
    info.setdefault("partition", "vendor_boot")
    info.setdefault("flags", "0")
    info.setdefault("rollback", "0")
    info.setdefault("rollback_location", "0")
    info.setdefault("salt", "")
    return True, info, props


def repack_vendor_boot(
    stock_path: Path,
    dtb_path: Path,
    out_path: Path,
    avbtool: str,
) -> None:
    stock = stock_path.read_bytes()
    dtb = dtb_path.read_bytes()
    page_size, header_size, vendor_ramdisk_size, dtb_offset, content_end = vendor_layout(stock)
    if page_size not in (2048, 4096, 8192, 16384):
        raise ValueError(f"vendor_boot.img: unusual page size {page_size}")

    new_dtb_size = len(dtb)
    header = bytearray(stock[:header_size])
    struct.pack_into("<I", header, 2100, new_dtb_size)
    ramdisk = stock[
        align(header_size, page_size):align(header_size, page_size) + vendor_ramdisk_size
    ]

    dtb_offset = align(align(header_size, page_size) + vendor_ramdisk_size, page_size)
    content = bytearray(align(dtb_offset + new_dtb_size, page_size))
    content[:header_size] = header
    content[align(header_size, page_size):align(header_size, page_size) + vendor_ramdisk_size] = ramdisk
    content[dtb_offset:dtb_offset + new_dtb_size] = dtb

    has_avb, info, props = read_avb_footer_info(avbtool, stock_path)
    if has_avb:
        with tempfile.TemporaryDirectory(prefix="hyperos-vendor-boot-") as tmp:
            content_path = Path(tmp) / "vendor_boot"
            content_path.write_bytes(content)
            cmd = [
                avbtool,
                "add_hash_footer",
                "--image", str(content_path),
                "--partition_size", str(len(stock)),
                "--partition_name", info["partition"],
                "--hash_algorithm", "sha256",
                "--algorithm", "NONE",
                "--flags", info["flags"],
                "--rollback_index", info["rollback"],
                "--rollback_index_location", info["rollback_location"],
            ]
            if info["salt"]:
                cmd.extend(["--salt", info["salt"]])
            for key, val in props:
                cmd.extend(["--prop", f"{key}:{val}"])
            subprocess.run(cmd, check=True, text=True)
            shutil.copyfile(content_path, out_path)
    else:
        out = bytearray(len(stock))
        out[:len(content)] = content
        out_path.write_bytes(out)


def main() -> int:
    local_avbtool = Path(__file__).resolve().parent / "avbtool"
    default_avbtool = str(local_avbtool) if local_avbtool.is_file() else (shutil.which("avbtool") or "avbtool")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stock-dir", required=True, type=Path)
    parser.add_argument("--kernel", required=True, type=Path)
    parser.add_argument("--dtb", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--avbtool", default=default_avbtool)
    args = parser.parse_args()

    for name in ("boot.img", "vendor_boot.img", "dtbo.img"):
        if not (args.stock_dir / name).is_file():
            raise FileNotFoundError(args.stock_dir / name)
    if not args.kernel.is_file() or not args.dtb.is_file():
        raise FileNotFoundError("kernel or DTB input is missing")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    repack_boot(args.stock_dir / "boot.img", args.kernel, args.out_dir / "boot.img")
    repack_vendor_boot(
        args.stock_dir / "vendor_boot.img",
        args.dtb,
        args.out_dir / "vendor_boot.img",
        args.avbtool,
    )
    shutil.copyfile(args.stock_dir / "dtbo.img", args.out_dir / "dtbo.img")

    print(f"boot.img         {args.out_dir / 'boot.img'}")
    print(f"vendor_boot.img  {args.out_dir / 'vendor_boot.img'}")
    print(f"dtbo.img         {args.out_dir / 'dtbo.img'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise
