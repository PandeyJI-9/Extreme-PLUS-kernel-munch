<div align="center">

# ⚡ Extreme-PLUS Zero-Heat Kernel ⚡
### For POCO F4 / Redmi K40S (munch)

[![Build Status](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/actions/workflows/builder.yml/badge.svg)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/actions)
[![KernelSU Supported](https://img.shields.io/badge/KernelSU-Supported-success?logo=android)](https://kernelsu.org/)
[![Proton Clang](https://img.shields.io/badge/Compiled_with-Proton_Clang-blue?logo=c%2B%2B)](https://github.com/kdrag0n/proton-clang)
[![License](https://img.shields.io/badge/License-GPL_v2-red.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

*A heavily optimized, cloud-compiled custom kernel designed to deliver maximum UI smoothness and exceptional battery life by strictly taming the Snapdragon 870's thermals.*

</div>

---

## 🎯 The "Zero-Heat" Philosophy

The Snapdragon 870 (SM8250) is incredibly powerful, but its stock frequency scaling often leads to unnecessary battery drain and heat during simple tasks like UI scrolling and video playback. 

**Extreme-PLUS** addresses this by introducing specialized hardware-level patches directly into the device tree (DTS/DTSI). We don't rely on software modules—these are hardcoded limits that force the SoC to run cooler during idle, while preserving full HyperOS 3 capability.

## ✨ Key Features & Hardware Tuning

### 🎮 GPU (Adreno 650)
* **Custom 150MHz Idle State:** Inserted a new 150MHz Operating Performance Point (OPP) into `kona-gpu.dtsi`.
* **Deep Undervolting:** The 150MHz state runs exclusively at the `MIN_SVS` hardware voltage level.
* **Result:** Up to **30% reduction in GPU power consumption** during idle, reading, and light UI rendering.

### 🏎️ CPU (Kryo 585)
* **Prime Core Capped:** Downclocked the power-hungry CPU7 (Prime Core) maximum frequency from 3.187GHz to exactly **3.0GHz**.
* **Thermals over Benchmarks:** Eliminates the extreme heat generated during peak sustained loads.
* **Stock Efficiency:** CPU0-3 (Silver) and CPU4-6 (Gold) remain untouched to preserve multi-core responsiveness and battery efficiency.

### ⚙️ Core Enhancements
* **Compiled with Proton Clang:** Utilizes kdrag0n's highly optimized toolchain for superior code generation.
* **AnyKernel3 Powered:** Flashes safely over any ROM without modifying your ramdisk.
* **KernelSU (rKSU) Ready:** Root access baked directly into the kernel level (optional via CI builds).
* **100% Stock Compatible:** Display drivers (60/90/120Hz), Haptics, Sensors, and Fast Charging logics are strictly untouched to ensure flawless HyperOS compatibility.

---

## 📥 Download & Installation

All builds are fully automated via GitHub Actions. **Do not flash this if you are not on a supported device (munch).**

### Step 1: Download
Head over to the [Releases](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/releases) page and download the latest `.zip` file.

### Step 2: Flash via Recovery
1. Reboot your device into a custom recovery (TWRP / OrangeFox).
2. *(Optional but recommended)* Backup your current `boot`, `dtbo`, and `vendor_boot` partitions.
3. Locate the `Extreme-PLUS-ZeroHeat-munch-*.zip` and swipe to flash.
4. Wipe Dalvik / ART Cache.
5. Reboot to System.

---

## 🏗️ Automated CI/CD Architecture

This repository contains **0 bytes of local kernel source code**. 
It utilizes a state-of-the-art GitHub Actions architecture to:
1. Fetch the raw upstream kernel source dynamically.
2. Inject Python-based `.patch` logic into the device tree on-the-fly.
3. Build the kernel inside GitHub's high-performance cloud runners.
4. Package the output using AnyKernel3 and automatically publish a GitHub Release.

---

## 🤝 Credits & Acknowledgments

* [**AstideLabs**](https://github.com/AstideLabs/android_kernel_xiaomi_sm8250) - For the incredibly stable upstream kernel source.
* [**osm0sis**](https://github.com/osm0sis/AnyKernel3) - For AnyKernel3.
* [**kdrag0n**](https://github.com/kdrag0n/proton-clang) - For the Proton Clang toolchain.
* [**tiann & rKSU**](https://github.com/tiann/KernelSU) - For KernelSU.

---

<details>
<summary><strong>⚠️ Disclaimer</strong></summary>
<br>

```text
#include <std_disclaimer.h>
/*
 * Your warranty is now void.
 *
 * I am not responsible for bricked devices, dead SD cards,
 * thermonuclear war, or you getting fired because the alarm app failed.
 * Please do some research if you have any concerns about features included
 * in this kernel before flashing it! YOU are choosing to make these modifications.
 */
```
</details>
