<div align="center">

<img src="https://img.shields.io/badge/EXTREME++-GAMING-ff6600?style=for-the-badge&logo=android&logoColor=white" alt="EXTREME++GAMING" width="400"/>

# ⚡ EXTREME++GAMING Kernel
### POCO F4 / Redmi K40S — Snapdragon 870 (SM8250-AC)

[![Build](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/actions/workflows/master_pipeline.yml/badge.svg)](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/actions)
[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-success?logo=android)](https://kernelsu.org/)
[![Proton Clang](https://img.shields.io/badge/Toolchain-Proton_Clang-blue?logo=llvm)](https://github.com/kdrag0n/proton-clang)
[![License](https://img.shields.io/badge/License-GPL_v2-red.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Telegram](https://img.shields.io/badge/Support-Telegram-26A5E4?logo=telegram)](https://t.me/)

*A precision-tuned custom kernel built for the Snapdragon 870, delivering ultra-smooth UI performance while keeping thermals and battery drain at absolute minimum.*

---

**`uname -r` → `5.4.xxx-EXTREME++GAMING`**

</div>

---

## 🎯 Design Philosophy

The Snapdragon 870 is a powerhouse, but stock frequency scaling wastes battery and generates unnecessary heat during everyday tasks like YouTube, Instagram, and WhatsApp. **EXTREME++GAMING** fixes this with precision hardware-level patches:

- 🎮 **GPU peaks at stock 670 MHz** — zero compromise on gaming performance
- 🔋 **GPU idles at 150 MHz** — massive battery savings during reading, YouTube, AOD
- 🧊 **CPU Prime Core capped at 3.0 GHz** — reduced heat with zero perceptible performance loss
- 📱 **Display, Haptics, Sensors, Charging** — 100% stock, fully HyperOS 3 compatible

---

## 🎮 GPU Frequency Table — Adreno 650

> **10 custom Operating Performance Points (OPPs)** — 7 more granular steps than stock.

```
╔═══════════╦══════════════╦═══════════════════════════════════════════╗
║ Frequency ║ Voltage      ║ Workload                                  ║
╠═══════════╬══════════════╬═══════════════════════════════════════════╣
║  670 MHz  ║ NOM          ║ 🔴 Peak 3D: Genshin, BGMI max FPS        ║
║  587 MHz  ║ SVS_L2       ║ 🟠 Heavy 3D: Camera viewfinder, 3D apps  ║
║  525 MHz  ║ SVS_L1       ║ 🟡 Moderate 3D: Medium gaming             ║
║  490 MHz  ║ SVS_L1       ║ 🟡 UI transitions: App open/close anim    ║
║  441 MHz  ║ SVS          ║ 🟢 120Hz scrolling: Instagram, Twitter    ║
║  400 MHz  ║ SVS          ║ 🟢 Standard 120Hz: Frame pacing, light 2D ║
║  305 MHz  ║ LOW_SVS      ║ 🔵 Light UI: 1080p/4K video playback     ║
║  250 MHz  ║ LOW_SVS      ║ 🔵 Low power: Static reading, 60Hz idle  ║
║  200 MHz  ║ MIN_SVS      ║ ⚪ Ultra-low: Background rendering, AOD   ║
║  150 MHz  ║ MIN_SVS      ║ ⚪ Deep idle: Screen-off compositing       ║
╚═══════════╩══════════════╩═══════════════════════════════════════════╝
```

**Stock had only 3 steps** (480, 381, 290 MHz). Our 10-step table gives the GPU governor much finer control — it can pick the exact right frequency for each workload instead of jumping between coarse steps.

---

## 🏎️ CPU Frequency Table — Kryo 585

### LITTLE Cluster (Cores 0–3 | Efficiency)
```
300 → 403 → 518 → 614 → 691 → 787 → 883 → 979 →
1075 → 1171 → 1248 → 1344 → 1420 → 1516 → 1612 → 1708 → 1804 MHz

├── 300–614 MHz   Deep idle, screen-off audio, sensor monitoring
├── 691–1171 MHz  Background sync, push notifications
└── 1248–1804 MHz OS housekeeping, active downloads
```

### GOLD Cluster (Cores 4–6 | Performance)
```
710 → 825 → 940 → 1056 → 1171 → 1286 → 1382 → 1478 →
1574 → 1670 → 1766 → 1862 → 1958 → 2054 → 2150 → 2246 → 2342 → 2419 MHz

├── 710–1286 MHz   Static UI display, basic menu navigation
├── 1382–1958 MHz  120Hz display frame pacing, fluid scrolling
└── 2054–2419 MHz  Sustained multitasking, camera ISP processing
```

### PRIME Core (Core 7 | Burst/Heavy Load) — ⚡ Capped at 3000 MHz
```
844 → 960 → 1075 → 1190 → 1305 → 1401 → 1516 → 1632 → 1747 →
1862 → 1977 → 2073 → 2169 → 2265 → 2361 → 2457 → 2553 → 2649 → 2745 → 2841 → 3000 MHz

├── 844–1516 MHz   Parking states alongside Gold cores
├── 1632–2457 MHz  Burst mitigation (prevents UI micro-stutters)
└── 2553–3000 MHz  Cold app launches, heavy 3D threads, touch boost
```

> **Stock Prime max:** 3187 MHz → **Patched:** 3000 MHz  
> This 187 MHz reduction eliminates the extreme heat spike at peak load while being imperceptible in real-world usage.

---

## 📥 Download & Flash

### Step 1: Download
Go to **[Releases](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/releases)** → download the latest `.zip`.

### Step 2: Flash
1. Reboot into **TWRP / OrangeFox** recovery
2. *(Recommended)* Backup `boot` and `dtbo` partitions
3. Flash `EXTREME++GAMING-munch-*.zip`
4. Wipe **Dalvik / ART Cache**
5. Reboot

### Step 3: Verify
After booting, open a terminal emulator and run:
```bash
uname -r
# Should show: 5.4.xxx-EXTREME++GAMING
```

---

## 🏗️ CI/CD Architecture

This repo contains **zero kernel source code**. Everything is cloud-compiled:

```
┌─────────────────────────────────────────────────────┐
│  Your GitHub Repo (this repo)                       │
│  ├── .github/workflows/   ← Build automation        │
│  ├── patches/             ← GPU/CPU/Name patches     │
│  └── README.md                                       │
└──────────────────┬──────────────────────────────────┘
                   │ workflow_dispatch (manual trigger)
                   ▼
┌─────────────────────────────────────────────────────┐
│  GitHub Actions Runner (Ubuntu, 7GB RAM, 2 cores)   │
│  1. git clone AstideLabs kernel (shallow)            │
│  2. Run patches/apply-all.sh                         │
│  3. Compile with Proton Clang                        │
│  4. Package with AnyKernel3                          │
│  5. Upload ZIP → GitHub Release                      │
└─────────────────────────────────────────────────────┘
```

### Available Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| 🔨 **Builder** | Full kernel build → flashable ZIP | Manual |
| 🧪 **Tester** | Fast CI: defconfig + DTB compile | Manual |
| 🔍 **Verifier** | Confirms patches in compiled DT | Manual |
| 🚀 **Releaser** | Sync upstream + KSU + Release | Manual |

---

## 📂 Repository Structure

```
.github/workflows/
├── builder.yml             Full kernel build pipeline
├── tester.yml              Fast defconfig + DTB check
├── verifier.yml            Patch verification
└── releaser_and_sync.yml   Upstream sync + release

patches/
├── apply-gpu-opp.py        GPU 10-frequency OPP table patch
├── apply-cpu-cap.py        CPU Prime Core 3.0GHz cap
└── apply-all.sh            Master patch orchestrator
```

---

## 🤝 Credits

| Project | Contribution |
|---------|-------------|
| [AstideLabs](https://github.com/AstideLabs/android_kernel_xiaomi_sm8250) | Upstream kernel source |
| [osm0sis](https://github.com/osm0sis/AnyKernel3) | AnyKernel3 flashable ZIP framework |
| [kdrag0n](https://github.com/kdrag0n/proton-clang) | Proton Clang toolchain |
| [tiann](https://github.com/tiann/KernelSU) | KernelSU root solution |

---

<details>
<summary><strong>⚠️ Disclaimer</strong></summary>
<br>

```c
#include <std_disclaimer.h>
/*
 * Your warranty is now void.
 *
 * I am not responsible for bricked devices, dead SD cards,
 * thermonuclear war, or you getting fired because the alarm
 * app failed. Please do some research if you have any concerns
 * about features included in this kernel before flashing it!
 * YOU are choosing to make these modifications.
 */
```
</details>

<div align="center">

---

**Built with ❤️ by [PandeyJI-9](https://github.com/PandeyJI-9)**

</div>
