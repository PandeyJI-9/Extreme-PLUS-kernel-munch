<div align="center">

# ⚡ EXTREME++ GAMING KERNEL ⚡
### Next-Gen Engineered Performance & Thermal Perfection for POCO F4 (munch / munch-in)
**Official HyperOS Flagship Custom Kernel | Android 14 — 17**

[![Build Status](https://img.shields.io/github/actions/workflow/status/PandeyJI-9/Extreme-PLUS-kernel-munch/build.yml?branch=main&style=for-the-badge&logo=github&label=Build%20%26%20Release&color=00c853)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/actions)
[![Kernel Version](https://img.shields.io/badge/Linux_Kernel-4.19.xxx_Non--GKI-007acc?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch)
[![Device](https://img.shields.io/badge/POCO_F4-munch%20%2F%20munch--in-ff6f00?style=for-the-badge&logo=xiaomi&logoColor=white)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch)
[![SoC](https://img.shields.io/badge/Snapdragon_870-SM8250--AC%20(Kona%20v2.1)-red?style=for-the-badge&logo=qualcomm&logoColor=white)](https://www.qualcomm.com/products/application/smartphones/snapdragon-8-series-mobile-platforms/snapdragon-870-5g-mobile-platform)
[![Compatibility](https://img.shields.io/badge/HyperOS-1.0%20%7C%202.0%20%7C%203.0%20%7C%204.0-success?style=for-the-badge&logo=android&logoColor=white)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch)
[![Root](https://img.shields.io/badge/Root-ReSukiSU%20%2B%20SuSFS-9c27b0?style=for-the-badge&logo=android&logoColor=white)](https://github.com/ReSukiSU/ReSukiSU)
[![Telegram](https://img.shields.io/badge/Community-Telegram_Support-29b6f6?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Extremeplus_Support)

<br>

> *"Engineered at the silicon driver level: Maximum Sustained Gaming Performance with Zero Thermal Penalty."*

</div>

---

## 📖 Overview

**EXTREME++ GAMING** is a bespoke, ultra-optimized custom kernel specifically engineered for the **POCO F4 / Redmi K40S (codename: munch / munch-in)** powered by the **Qualcomm Snapdragon 870 5G (SM8250-AC / Kona v2.1)**.

While OEM stock kernels suffer from aggressive thermal throttling, unoptimized voltage tables, lazy frequency governors, and user-space bloatware intervention, **EXTREME++** breaks through hardware bottlenecks. By modifying kernel C drivers natively, injecting granular 10-step GPU voltage tables, and enforcing hard kernel-space locks, this kernel guarantees smooth 120 FPS sustained gaming, instant touch reaction, and exceptional battery conservation.

---

## 📱 ROM & Android Compatibility Matrix

EXTREME++ Kernel is built with **OS-independent C-driver locks** that guarantee native boot and undervolt enforcement across all major HyperOS iterations:

| ROM / OS Family | Supported Generations | Android Base | Status | Technical Details |
| :--- | :--- | :---: | :---: | :--- |
| **Xiaomi HyperOS** | **HyperOS 1.0, 2.0, 3.0, 4.0** | **Android 14, 15, 16, 17** | 🟢 **100% Fully Working** | Seamless out-of-the-box boot. Native C-level hooks in `adreno.c` bypass stock DTBO overrides and neutralize Joyose thermal traps. |
| **MIUI** | MIUI 13, MIUI 14 | Android 12, 13 | 🟡 **Bootable (Untested)** | Architecture preserves standard split_boot; may boot properly on MIUI but is not actively tested or officially validated. |
| **AOSP / Custom ROMs** | LineageOS, EvolutionX, PixelOS, etc. | Android 14+ | ⏳ **In Active Development** | *For AOSP users: I will work soon on AOSP!* A dedicated AOSP branch with customized defconfig and ramdisk logic is coming soon. |

> [!TIP]
> **All HyperOS versions (1.0, 2.0, 3.0, 4.0) on Android 14, 15, 16, and 17 are 100% tested and verified!** Whether you are on early HyperOS 1 or cutting-edge HyperOS 4, the kernel boots flawlessly and maintains all hardware optimizations.
> 
> [!NOTE]
> **MIUI Notice:** This kernel is heavily tuned for modern HyperOS core subsystems (MIGT, MIHW, RTMM, MILLET). While it might boot on legacy MIUI 13/14, testing is up to the user.
> 
> [!IMPORTANT]
> **AOSP Users:** A dedicated AOSP build is currently in the pipeline and will be released in our [Telegram Support Group](https://t.me/Extremeplus_Support).

---

## 🚀 Key Highlights & "Under the Hood" Engineering

### 🏎️ 1. CPU Frequency Mastery (Zero Heat Architecture)
* **Hardware-Level 2.84 GHz Prime Cap:** Snapdragon 870's Prime Core (Kryo 585 / Cortex-A77) stock table includes a power-inefficient 3.187 GHz turbo frequency that generates severe heat spikes and forces thermal throttling.
  * Injected a native C89-compliant hardware break in [`drivers/cpufreq/qcom-cpufreq-hw.c`](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch) and locked `qcom,freq-domain-max-freq = <2841600>` in `kona.dtsi`.
  * **Result:** Eliminates overheating at the silicon level while delivering 100% stable peak performance.
* **Instant Touch Schedutil Governor:**
  * Configured `tunables->up_rate_limit_us = 0` in [`kernel/sched/cpufreq_schedutil.c`](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch).
  * Eliminates governor ramp-up lag: the instant your finger touches the screen, CPU cores instantly scale to peak speed for a zero-stutter 120Hz display refresh.
* **Zero Heat Policy:** 100% stock hardware TSENS thermal-engine and safety trip points are preserved. Zero danger of hardware degradation.

---

### 🎮 2. GPU Hardcore Overrides (Adreno 650 Undervolting & C Locks)
* **FakeDreamer 10-Step OPP Undervolting (150 MHz – 670 MHz):**
  * Replaced the crude stock 3-frequency layout with a precision 10-step Operating Performance Point (OPP) table across all Kona speed-bins.
  * Mapped directly to Qualcomm RPMh voltage rails:

```text
╔════════════════════════════════════════════════════════════════════════════════════╗
║ Level │ Frequency │ RPMh Voltage Rail │ Workload & Purpose                         ║
╠═══════╪═══════════╪═══════════════════╪════════════════════════════════════════════╣
║   0   │  670 MHz  │  SVS_L2 (224)     │ 🔴 Max Gaming (BGMI 90/120FPS, Genshin)    ║
║   1   │  587 MHz  │  SVS_L1 (192)     │ 🟠 Heavy 3D load, Camera Viewfinder        ║
║   2   │  525 MHz  │  SVS (128)        │ 🟡 Smooth Gaming & Heavy Rendering         ║
║   3   │  490 MHz  │  SVS (128)        │ 🟡 Fluid 120Hz App Switching Animations    ║
║   4   │  441 MHz  │  LOW_SVS (64)     │ 🟢 Social Feeds (Instagram, Twitter, 120Hz)║
║   5   │  400 MHz  │  LOW_SVS (64)     │ 🟢 General 2D & UI Frame Pacing            ║
║   6   │  305 MHz  │  MIN_SVS (48)     │ 🔵 Default Wakeup & 4K/60FPS Video Playback║
║   7   │  250 MHz  │  LOW_SVS (64)     │ 🔵 Static Content & E-book Reading (60Hz)  ║
║   8   │  200 MHz  │  MIN_SVS (48)     │ ⚪ Ultra-Low Background Rendering          ║
║   9   │  150 MHz  │  MIN_SVS (48)     │ ⚪ Deep Idle Screen-Off Compositing        ║
║  10   │    0 MHz  │  OFF (0)          │ 💤 Power Rail Collapsed (Sleep)            ║
╚═══════╧═══════════╧═══════════════════╧════════════════════════════════════════════╝
```

* **C-Level Kernel Driver Enforcement (`drivers/gpu/msm/adreno.c`):**
  * Solved the **HyperOS 3/4 DTBO Overlay Trap**: When users flash via Franco Kernel Manager (FKM) or recoveries that do not update the `dtbo` partition, the bootloader overlays stock Xiaomi DTBO.
  * Injected native C routine `adreno_enforce_extreme_pwrlevels()` in `adreno.c`: hardcodes all 10 power levels into kernel memory and registers them with `dev_pm_opp_add()`. DTBO overlays are safely bypassed.
* **Joyose & mi_thermald User-Space Blocker (`drivers/gpu/msm/kgsl_pwrctrl.c`):**
  * Intercepts and neutralizes user-space attempts to throttle GPU via `/sys/class/kgsl/kgsl-3d0/max_pwrlevel`, `min_pwrlevel`, and Xiaomi's `/sys/kernel/gpu/gpu_min_clock` / `gpu_max_clock`.
  * Joyose cannot lock your GPU to stock 305 MHz or prevent deep idle at 150 MHz!
* **KGSL & GMU Expansion:**
  * Upgraded `KGSL_MAX_PWRLEVELS = 16` and synchronized with `MAX_GX_LEVELS = 16` in `kgsl_gmu_core.h` for seamless firmware handshakes.

---

### 🧠 3. Memory & Responsiveness (Zero Stutter on 6GB & 8GB RAM)
* **ZRAM with ZSTD Compression:** Upgraded swap compression from legacy LZ4 to modern **ZSTD** (`CONFIG_ZRAM_DEF_COMP_ZSTD=y`). Provides higher compression ratios with ultra-fast decompression speed.
* **Aggressive Multitasking Tuning:**
  * Configured `vm_swappiness = 100` in [`mm/vmscan.c`](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch).
  * Tuned `sysctl_vfs_cache_pressure = 100` in [`fs/dcache.c`](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch).
  * Keeps background apps alive in memory without triggering aggressive LMK (Low Memory Killer) stutters.

---

### 🛡️ 4. Root & Complete Stealth (ReSukiSU + SuSFS)
* **Non-GKI 4.19 Architecture:** Fully tailored for Snapdragon 870 legacy 4.19 kernel structure.
* **Integrated SuSFS v1.5.5:** Completely hides root, mounts, KProbes, and hooks.
* **Integrity Bypass:** Seamlessly passes Google Play Integrity (Device + Basic), runs Banking Apps (Google Pay, PhonePe, PayTM, Banking), and games with anti-cheat engines without detection.

---

### 📦 5. Packaging & Anti-Bootloop Safety
* **AstideLabs Concatenated Multi-DTB:** Packs all compiled Kona DTBs into `anykernel/dtb` to ensure flawless bootloader matching.
* **AnyKernel3 `split_boot` Method:** Flashes kernel image and DTB directly into the boot partition while leaving the stock HyperOS ramdisk byte-for-byte untouched.
* **Kernel Signature:** Custom string `-EXTREME++GAMING_Hyperos` embedded in `uname -r`.

---

## 📥 Installation Guide

> [!IMPORTANT]
> **Prerequisites:**
> - Device: **POCO F4 / Redmi K40S (munch / munch-in)**
> - ROM: **HyperOS 1.0, 2.0, 3.0, 4.0 (Android 14 — 17)**
> - Always take a backup of your `boot` and `dtbo` partitions before flashing!

### Method 1: Custom Recovery (TWRP / OrangeFox) — *Recommended*
1. Download the latest `EXTREME++GAMING_Hyperos_munch_*.zip` from **[Releases](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/releases)**.
2. Boot into **TWRP** or **OrangeFox** recovery.
3. Tap **Install** → Select the kernel ZIP.
4. Swipe to confirm flash (AnyKernel3 will automatically pack `Image`, `dtb`, and `dtbo.img`).
5. *(Optional)* Wipe Dalvik / ART Cache.
6. Reboot to System.

### Method 2: Kernel Managers (FKM / SmartPack)
1. Open Franco Kernel Manager (FKM) or SmartPack Kernel Manager.
2. Select **Manual Flasher** → Choose downloaded kernel ZIP.
3. Flash and reboot.
*(Our C-level driver locks guarantee that 10-step GPU UV works even with FKM boot-only flashes!)*

---

## 🔍 Verification After Boot

Open Termux or an ADB shell and run:

```bash
# 1. Verify Kernel Name
uname -r
# Output should show: 4.19.xxx-EXTREME++GAMING_Hyperos

# 2. Verify 10-Step GPU Frequencies
cat /sys/class/kgsl/kgsl-3d0/gpu_available_frequencies
# Output: 670000000 587000000 525000000 490000000 441600000 400000000 305000000 250000000 200000000 150000000

# 3. Verify CPU Prime Core 2.84 GHz Cap
cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq
# Output: 2841600
```

---

## ⚙️ Automated CI/CD Build Pipeline

This repository is powered by fully automated **GitHub Actions**:
- **Toolchain:** ZyC-Clang 16.0.6 (LLD linker, ccache acceleration).
- **Anti-Crash Swap Memory:** 10GB virtual SSD swap allocation to prevent clang compiler OOM aborts.
- **Auto-Release Management:** Automated GitHub Release creation with rich markdown release logs and automated older-release cleanup.
- **Telegram Webhook:** Instant notification with flashable ZIP dispatched to the Telegram channel on successful builds.

---

## 🤝 Community & Support

Need assistance, benchmark discussions, or want to share feedback?

- 💬 **Telegram Support Group:** [@Extremeplus_Support](https://t.me/Extremeplus_Support)
- 👨‍💻 **Maintainer:** [@pandey_ji_8](https://t.me/pandey_ji_8)

---

## 🏆 Credits & Acknowledgements

* **[Ayush Pandey JI (@pandey_ji_8)](https://t.me/pandey_ji_8)** — Lead Developer & Architect of EXTREME++ Kernel.
* **[FakeDreamer](https://github.com)** — GPU 10-step RPMh voltage UV logic & inspiration.
* **[rsuntk / ReSukiSU](https://github.com/ReSukiSU)** — Next-generation Non-GKI 4.19 KernelSU implementation.
* **[AstideLabs](https://github.com/AstideLabs)** — Upstream SM8250 Linux 4.19 kernel base & AnyKernel3 tree.
* **[osm0sis](https://github.com/osm0sis)** — AnyKernel3 backend flasher script.

---

<details>
<summary><strong>📜 Disclaimer</strong></summary>

```c
/*
 * Your warranty is now void.
 * I am not responsible for bricked devices, dead SD cards, thermonuclear war,
 * or you getting fired because the alarm app failed. Please do some research
 * if you have any concerns about features included in this KERNEL before flashing it!
 * YOU are choosing to make these modifications.
 */
```
</details>

<div align="center">
<b>Made with ❤️ for POCO F4 (munch) Enthusiasts</b>
</div>
