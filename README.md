<div align="center">

# ⚡ PROJECT EXTREME++ (BMW EDITION) ⚡
### Ultimate Silicon-Level Performance & Thermal Architecture for POCO F4 / Redmi K40S (`munch` / `munch-in`)
**Linux 4.19.325-cip135-st19 · Qualcomm Snapdragon 870 5G (`SM8250-AC`) · Dual Target (HyperOS & AOSP)**

[![Build Status](https://img.shields.io/github/actions/workflow/status/PandeyJI-9/Extreme-PLUS-kernel-munch/build.yml?branch=main&style=for-the-badge&logo=github&label=Build%20%26%20Release&color=00c853)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/actions)
[![Kernel Version](https://img.shields.io/badge/Linux_Kernel-4.19.325--cip135--st19-007acc?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch)
[![Device](https://img.shields.io/badge/POCO_F4-munch%20%2F%20munch--in-ff6f00?style=for-the-badge&logo=xiaomi&logoColor=white)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch)
[![SoC](https://img.shields.io/badge/Snapdragon_870-SM8250--AC%20(Kona%20v2.1)-red?style=for-the-badge&logo=qualcomm&logoColor=white)](https://www.qualcomm.com/products/application/smartphones/snapdragon-8-series-mobile-platforms/snapdragon-870-5g-mobile-platform)
[![Target Matrix](https://img.shields.io/badge/Targets-HyperOS%201.0--4.0%20%7C%20AOSP%2013--17-success?style=for-the-badge&logo=android&logoColor=white)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch)
[![Root Support](https://img.shields.io/badge/Root-KowSU%20%2F%20ReSukiSU%20%2B%20SuSFS%20v2.3.0-9c27b0?style=for-the-badge&logo=android&logoColor=white)](https://github.com/ReSukiSU/ReSukiSU)
[![Companion App](https://img.shields.io/badge/Companion_App-EKM_v2.1.0-e91e63?style=for-the-badge&logo=android&logoColor=white)](https://github.com/PandeyJI-9/extreme-kernel-manager)
[![Community](https://img.shields.io/badge/Community-Telegram_Support-29b6f6?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Extremeplus_Support)

<br>

> *"Tune the silicon to its absolute peak efficiency — do not fight it. Deliver sustained 120 FPS gaming, ice-cold thermals, and lightning-fast touch response without sacrificing battery life."*

</div>

---

## 📌 Project Overview & Development Status

**PROJECT EXTREME++ (BMW Edition)** is a custom kernel crafted specifically for the **POCO F4 / Redmi K40S (`munch` / `munch-in`)** powered by the **Qualcomm Snapdragon 870 5G (`SM8250-AC / Kona v2.1`)**. 

Built upon the rock-solid **AstideLabs SM8250 Linux 4.19 LTS** foundation, EXTREME++ tackles real-world mobile bottlenecks: UI micro-stutters, gaming thermal throttling, memory compaction latency, and GPU power draw.

| Attribute | Specification |
| :--- | :--- |
| **Project Status** | 🟢 **Official Stable · Production Ready (Daily Driver)** |
| **Linux Kernel Base** | AstideLabs SM8250 4.19 (`4.19.325-cip135-st19`) |
| **Built-in Boot Governor** | `extreme+` (Active from boot, zero laggy service scripts) |
| **Official Companion App** | **[Extreme Kernel Manager (EKM)](https://github.com/PandeyJI-9/extreme-kernel-manager)** (BMW M-Power UI & Live Control) |
| **Default ZRAM Compressor** | **ZSTD Level 3** (High-efficiency dynamic workspace) |
| **GPU Subsystem** | FakeDreamer 7-Stage OPP Table + Deep Undervolting (`msm-adreno-tz`) |
| **Peak Prime CPU Clock** | **3.19 GHz Monster Peak** (`3187200` kHz) |
| **Root Integration** | KowSU / ReSukiSU Multi-Manager + SuSFS v2.3.0 Kernel Stealth |

---

## 🎯 Dual-Target Architecture: HyperOS & AOSP

EXTREME++ delivers first-class support for both stock and custom firmware ecosystems through dedicated AnyKernel3 packages:

```
                          ┌─────────────────────────────┐
                          │   PROJECT EXTREME++ CORE    │
                          │ Linux 4.19 · SM8250 · 3.19G │
                          └──────────────┬──────────────┘
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 ▼                                               ▼
   ┌───────────────────────────┐                   ┌───────────────────────────┐
   │     HYPEROS EDITION       │                   │       AOSP EDITION        │
   │  HyperOS 1.0 – 4.0        │                   │    Android 13 – 17        │
   │  (Android 14 – 17)        │                   │ (A15, A16, A17 Verified)  │
   ├───────────────────────────┤                   ├───────────────────────────┤
   │ • Full Xiaomi MIGT & MIHW │                   │ • Pure, unbloated tree    │
   │ • RTMM & Task Turbo Path  │                   │ • Zero Xiaomi vendor spam │
   │ • Millet Dual-ABI Engine  │                   │ • ReKernel support        │
   │ • Display & Thermal Sync  │                   │ • Maximum AOSP smoothness │
   └───────────────────────────┘                   └───────────────────────────┘
```

* 🟢 **Xiaomi HyperOS (HyperOS 1.0 — 4.0 | Android 14 — 17):**
  Features full Xiaomi vendor subsystem integration: MIGT, MIHW, RTMM, and our custom Millet Dual-ABI Netlink compatibility engine. Preserves OEM display calibration, game turbo hooks, and battery authentication.
* ⚡ **AOSP / Custom ROMs (Android 13 — 17 | A15, A16 & A17 Tested):**
  Running silky smooth! Xiaomi proprietary background daemons are cleanly compiled out, eliminating logcat spam, wakelocks, and battery drain on LineageOS, crDroid, Evolution X, PixelOS, and all modern AOSP-based ROMs.

---

## 🏎️ Key Features & Silicon Engineering

### 1. 🧠 Custom EXTREME+ CPUFreq Governor & EKM Profiles
EXTREME++ features our proprietary **`extreme+`** governor (`CONFIG_CPU_FREQ_GOV_EXTREME_PLUS=y`), designed to provide instant touch responsiveness while maintaining sustained gaming framerates.

* **Rock-Solid Foundation:** Unlike experimental governors that cause panics, `extreme+` is built upon Qualcomm's battle-tested **CAF WALT Schedutil** engine. It does not fight Energy Aware Scheduling (EAS); it evaluates runqueue utilization directly per tick.
* **Boot Default:** Configured as the built-in default (`CONFIG_CPU_FREQ_DEFAULT_GOV_EXTREME_PLUS=y`). Active from the very first second of boot without requiring `/data/adb/service.d` scripts (eliminating POCO logo delays).
* **Zero Frequency Floor Locking:** Cores are never locked to an artificial minimum. Little cores drop freely to 300 MHz / idle, preventing idle battery drain.
* **Zero Panic Architecture:** All dangerous `BUG_ON` and `WARN_ON_ONCE` checks are replaced with silent safety guards, ensuring 100% crash-proof operation even under extreme CPU frequency shifts.

#### 🎛️ Dynamic Profile Ceiling Table
Control profiles on-the-fly via `/sys/kernel/extreme_profile` or `/sys/kernel/profile`:

| Profile | Sysfs Value | Prime Core (CPU 7) | Gold Cluster (CPU 4-6) | Little Cluster (CPU 0-3) | Characteristics |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **Gaming** | `0` *(Default)* | **3.19 GHz** (`3187200` kHz) | **2.42 GHz** (`2419200` kHz) | Stock Range | Zero touch latency, max clock headroom, locked 120 FPS |
| **Balanced** | `1` | **2.84 GHz** (`2841600` kHz) | **2.25 GHz** (`2246400` kHz) | Stock Range | Daily driver sweet-spot, optimal thermal efficiency |
| **Battery** | `2` | **2.42 GHz** (`2419200` kHz) | **1.96 GHz** (`1958400` kHz) | Stock Range | Power-saving ceiling for multi-day battery endurance |

```bash
# Switch profiles instantly via Root / Termux:
echo 0 > /sys/kernel/extreme_profile   # Gaming (3.19 GHz Peak)
echo 1 > /sys/kernel/extreme_profile   # Balanced (2.84 GHz Peak)
echo 2 > /sys/kernel/extreme_profile   # Battery (2.42 GHz Peak)

# Named aliases work too!
echo gaming > /sys/kernel/profile
echo balanced > /sys/kernel/profile
echo battery > /sys/kernel/profile
```

> [!TIP]
> **Prefer a graphical interface?** Use our official **[Extreme Kernel Manager (EKM)](https://github.com/PandeyJI-9/extreme-kernel-manager)** Android app for 1-click profile switching, live BMW M-Power frequency monitoring, and POCO F4 AMOLED DC Dimming!

---

### 2. 🎮 Adreno 650 GPU: FakeDreamer 7-Stage OPP & Deep Undervolt
Our GPU architecture integrates the renowned **FakeDreamer Adreno 650 OPP table** via device tree, delivering exceptional efficiency and sustained graphics performance.

| Frequency | RPMh Voltage Level | Voltage Code | Target Workload |
| :---: | :---: | :---: | :--- |
| **670 MHz** | `SVS_L2` | 225 | Peak gaming & heavy 3D rendering |
| **587 MHz** | `SVS_L1` | 129 | Sustained high-refresh gaming (sweet-spot) |
| **510 MHz** | `SVS` | 66 | Efficient graphics processing |
| **400 MHz** | `LOW_SVS` | 1 | Smooth UI compositing & video playback |
| **330 MHz** | `LOW_SVS` | 1 | Light composition & media streaming |
| **205 MHz** | `MIN_SVS` | 1 | Low-power static display & ambient refresh |
| **150 MHz** | `MIN_SVS` | 1 | Deep idle floor (lowest power state) |

* **Native Hardware DVFS:** Preserves Qualcomm's proprietary **`msm-adreno-tz`** (TrustZone) governor for hardware-level voltage/frequency scaling.
* **DDR Bus Tier 11:** The top three performance frequencies automatically command bus bandwidth tier 11, ensuring memory pipelines never starve during intensive gaming.
* **Cooler Gaming:** Surgical voltage stepping lowers chassis temperatures by **3°C to 5°C** under sustained gameplay without dropping a single frame.

---

### 3. 💾 Next-Gen Memory: ZSTD Level-3 ZRAM & Anti-Stutter VM
* **Default ZSTD ZRAM (Level 3):** Replaces legacy LZO/LZ4 with high-compression **ZSTD (Level 3)**. Delivers **30% — 40% higher compression ratios**, effectively turning 6 GB / 8 GB of physical RAM into a seamless 10 GB+ multitasking powerhouse.
* **Dynamic Workspace Allocation:** Kernel workspaces are pre-allocated for Level 3 maximum compression, allowing safe runtime tuning via `/sys/module/zstd/parameters/compression_level`.
* **Google ACK Critical VMScan Bypass:** Backported from modern Android Common Kernel (`mm/vmscan.c`). Critical real-time tasks (`oom_score_adj <= -900` and RT threads like **SurfaceFlinger** and audio composers) bypass direct-reclaim throttling sleeps. **Zero frame drops or UI freezes during intense memory compaction.**

---

### 4. 🔋 Intelligent Charging, Hardware Bypass & Thermal Safety
* **🎮 Hardware Bypass Charging:** Play games while plugged in without heating up the battery! Exposed through the battery `input_suspend` interface; system power is drawn directly from the charger rail while battery charging is inhibited.
* **⚡ Universal Fast Charge (PD / PPS):** Relaxed handshake thresholds (8.5V / 1.5A) unlock fast charging on third-party Power Delivery (PD) and Programmable Power Supply (PPS) adapters.
* **🔒 100% Stock Xiaomi 67W Mi Turbo Handshake:** Preserves authentic battery BMS digest verification and `mi_thermald` cryptographic handshakes. Genuine 67W Turbo charging works out-of-the-box.
* **🛡️ JEITA Multi-Stage Thermal Stepping:** Device-tree-calibrated thermal curve protects battery health:
  * `< 0°C`: 1.0A safety floor
  * `0.1°C – 15°C`: 4.0A cold step
  * `15.1°C – 38°C`: **12.4A (Full 67W Turbo Peak)**
  * `38.1°C – 42°C`: 6.6A (~33W Thermal step-down)
  * `42.1°C – 45°C`: 4.5A (~22W Controlled throttle)
  * `> 45°C`: 2.2A Emergency safety step-down

---

### 5. 🌐 Low-Latency Gaming Networking & I/O
* **TCP BBR Congestion Control:** Native **Google BBR** (`CONFIG_TCP_CONG_BBR=y`, `CONFIG_DEFAULT_BBR=y`) enabled as default TCP congestion control for minimum gaming ping and packet loss recovery.
* **FQ & FQ-CoDel Packet Pacing:** Prevents bufferbloat on congested Wi-Fi and 5G cellular networks.
* **Storage I/O Overhead Reduction:** Disabled redundant I/O statistics and entropy accounting on block devices (`/sys/block/*/queue/iostats = 0`) for maximum raw NVMe/UFS 3.1 throughput.

---

### 6. 📱 Millet Dual-ABI Netlink Engine (HyperOS Standby Fix)
* **Eliminates 9-Second Crash Loop:** Solves the notorious Xiaomi `millet_monitor` crash loop (`src_port 2 invalid! need len 160 len 96`) by dynamically parsing both modern 160-byte (HyperOS 2/4) and legacy 96-byte (MIUI) Netlink frames.
* **Real Deep Sleep:** Allows background apps to freeze properly, eliminating overnight standby battery drain on Xiaomi HyperOS.
* **AOSP Cleanliness:** Millet is cleanly compiled out on AOSP builds for zero overhead.

---

### 7. 🛡️ Multi-Manager Root & Kernel Stealth (SuSFS v2.3.0)
* **KowSU / ReSukiSU Multi-Manager:** Compatible with official KernelSU, ReSukiSU, and KowSU manager applications.
* **SuSFS v2.3.0 Full Integration:** Complete kernel-level stealth including path hiding, mount hiding, kstat spoofing, open redirect, and SUS map support.
* **Bootloader Command-Line Spoofing:** Patches `/proc/cmdline` for normal post-boot processes (`androidboot.verifiedbootstate=green`, `androidboot.flash.locked=1`) while providing genuine cmdline to PID 1 (`init`) and `ueventd` for safe AVB partition mounting.
* **Available Root Flavors:**
  * `ksu_susfs` — KowSU / ReSukiSU + SuSFS v2.3.0 (Maximum root & stealth)
  * `ksu_no_susfs` — Standard Clean KernelSU (No SuSFS stealth hooks)
  * `noroot` — Pure Clean Non-Root Kernel (Ideal for banking apps / zero root)

---

## 📥 Downloads & Official Companion App

### 1. 🚀 EXTREME++ Kernel (AnyKernel3 ZIPs)
You can download the flashable AnyKernel3 ZIP through either of the following two channels:

| Method | Source | Best For |
| :--- | :--- | :--- |
| **Option 1** | 📦 **[GitHub Releases](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/releases)** | Official tagged releases & milestone builds |
| **Option 2** | 🚀 **[Telegram Support Group (@Extremeplus_Support)](https://t.me/Extremeplus_Support)** | **Recommended!** Fastest updates, latest release builds, direct drops, changelogs, and instant support from PandeyJi |

> [!IMPORTANT]
> Always download the ZIP that matches your installed ROM:
> * **HyperOS Users:** Flash `EXTREME++_HyperOS_*.zip`
> * **AOSP Users:** Flash `EXTREME++_AOSP_*.zip`
> 
> *Never flash the Raw Images ZIP (`.img`/`dtb`). Raw images are developer artifacts, not flashable AnyKernel packages.*

---

### 2. 📱 Extreme Kernel Manager (EKM Companion App)
The official open-source companion app designed exclusively for EXTREME++ on POCO F4 (`munch`), built with pure Kotlin, BMW M-Power aesthetics, and zero battery overhead.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       EXTREME KERNEL MANAGER (EKM)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  ⚡ Live Kernel Handshake      │  Direct sync with /sys/kernel/extreme_profile│
│  🏎️ BMW M-Power Dashboard     │  Real-time 3.19 GHz, GPU & Schedtune metrics│
│  🎛️ 1-Click Profile Engine    │  Instant Gaming / Balanced / Battery switch │
│  🌙 Munch AMOLED DC Dimming   │  Hardware flicker reduction + QS Tile       │
│  🔒 Pure Root Security        │  Safe execution on KernelSU, APatch & Magisk│
└─────────────────────────────────────────────────────────────────────────────┘
```

| Resource | Link | Notes |
| :--- | :--- | :--- |
| **Official Repository** | 🐙 **[PandeyJI-9/extreme-kernel-manager](https://github.com/PandeyJI-9/extreme-kernel-manager)** | Full open-source Kotlin project & docs |
| **Latest Release (Always Updated)** | ⚡ **[Download Latest EKM APK](https://github.com/PandeyJI-9/extreme-kernel-manager/releases/latest)** | Direct access to the newest stable APK release |
| **Latest Stable Tag (v2.1.0)** | 🏷️ **[EKM v2.1.0 Release Notes](https://github.com/PandeyJI-9/extreme-kernel-manager/releases/tag/v2.1.0)** | BMW M-Power UI, Munch AMOLED DC Dimming, R8 optimized |

---

## 📲 Installation Guide

### Via Custom Recovery (OrangeFox / TWRP)
1. Download the correct AnyKernel3 ZIP (`HyperOS` or `AOSP`).
2. Boot your POCO F4 into **OrangeFox** or **TWRP Recovery**.
3. *(Optional but Recommended)* Create a backup of your existing `boot` and `vendor_boot` partitions.
4. Go to **Install**, select the AnyKernel ZIP, and swipe to flash.
5. Reboot to System.

### Via Kernel Flasher App (FKM / Franco / SmartPack)
1. Open your preferred Kernel Flasher app (with Root access).
2. Select **Flash Kernel / AnyKernel ZIP**.
3. Choose the downloaded AnyKernel ZIP and confirm flash.
4. Reboot the device.

### 🧹 What the Installer Does Automatically:
* Writes the compiled kernel `Image` to the active **boot** partition.
* Injects the matching FakeDreamer Adreno 650 undervolted `dtb` into the active **vendor_boot** partition.
* **Auto-Purges Legacy Scripts:** Automatically scans and cleans outdated conflicting `/data/adb/service.d` and `post-fs-data.d` scripts from older builds, eliminating POCO logo hangs and bootloops.

---

## 🔍 Post-Boot Verification (Termux / ADB)

Verify your active silicon tuning after boot:

```bash
# 1. Check Kernel Release Name
uname -r
# Expected (HyperOS): 4.19.325-cip135-st19-Extreme++Gaming-HyperOS-BMW-...
# Expected (AOSP):    4.19.325-cip135-st19-Extreme++Gaming-AOSP-BMW-...

# 2. Verify Active Governor (Should be extreme+ on all clusters)
for p in /sys/devices/system/cpu/cpufreq/policy*; do
  echo "${p##*/}: $(cat "$p/scaling_governor")"
done

# 3. Verify Active Profile (0 = Gaming, 1 = Balanced, 2 = Battery)
cat /sys/kernel/extreme_profile

# 4. Verify ZRAM Compressor (Should be [zstd])
cat /sys/block/zram0/comp_algorithm

# 5. Verify FakeDreamer GPU Frequencies (150 MHz to 670 MHz)
cat /sys/class/kgsl/kgsl-3d0/gpu_available_frequencies
```

---

## 🤝 Community & Support

* 💬 **Official Telegram Community:** [@Extremeplus_Support](https://t.me/Extremeplus_Support) *(Join for chat, instant help, ROM feedback & discussions)*
* 👨‍💻 **Lead Developer & Maintainer:** **Ayush Pandey JI** ([@pandey_ji_8](https://t.me/pandey_ji_8))
* 🐞 **Bug Reports & Issues:**
  * 🚀 **Telegram Group (Fastest & Easiest):** Seedha [@Extremeplus_Support](https://t.me/Extremeplus_Support) me issue ya kernel log drop karo — koi GitHub account banane ki jhanjhat nahi!
  * 🌐 **GitHub Issues:** [Create an Issue](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/issues) agar structured developer-level tracking chahiye.

---

## 🏆 Credits & Acknowledgments

* **AYUSH PANDEY** — Lead architect, developer, and maintainer of PROJECT EXTREME++.
* **AstideLabs** — Solid SM8250 Linux 4.19 kernel source foundation.
* **FakeDreamer / re-noroi** — Adreno 650 RPMh voltage stepping and undervolt tables.
* **ReSukiSU, KowSU & KOWX712** — Non-GKI multi-manager root and SuSFS v2.3.0 stealth implementation.
* **osm0sis** — AnyKernel3 flashing backend.
* **Google ACK Team** — Upstream Android Common Kernel anti-stutter optimizations.

---

<details>
<summary><strong>📜 Disclaimer</strong></summary>

```c
/*
 * Your warranty is now void.
 * I am not responsible for bricked devices, dead SD cards, thermonuclear war,
 * or your alarm failing to wake you up.
 *
 * Flashing a custom kernel is YOUR choice. Make backups and flash responsibly.
 */
```

</details>

<div align="center">
<b>PROJECT EXTREME++ · Engineered with Passion for the POCO F4 Community 🚀🏎️</b>
</div>
