<div align="center">

# ⚡ EXTREME++ Gaming Kernel ⚡
### For POCO F4 (munch) | HyperOS 3 Optimized

*A custom kernel designed for extreme gaming performance, ultra-smooth UI transitions, and maximum thermal efficiency.*

---

**`uname -r` → `5.4.xxx-EXTREME++HyperOS`**

[<kbd> <br> 💬 Join Telegram Support Group <br> </kbd>](https://t.me/Extremeplus_Support)

</div>

---

## 🎯 Design Philosophy

The Snapdragon 870 is a powerhouse, but stock frequency scaling wastes battery and generates unnecessary heat during everyday tasks like YouTube, Instagram, and WhatsApp. **EXTREME++ GAMING** fixes this with precision hardware-level patches:

- 🎮 **GPU peaks at 670 MHz (with FakeDreamer UV)** — zero compromise on gaming performance, massive thermal reduction.
- 🔋 **10-Step GPU OPP Table** — massive battery savings during reading, YouTube, AOD, and perfectly paced 120Hz scrolling.
- 🧊 **CPU Prime Core capped at 2.84 GHz** — completely eliminates the peak heat spike with zero perceptible performance loss.
- 📱 **SukiSU Ultra (KernelSU)** — Injected directly into the kernel for flawless root access.
- 🛠️ **Flawless Flashing on GKI/HyperOS 3** — Perfected AnyKernel3 script that strictly flashes `boot` and overlays `dtbo.img` to preserve custom recovery ramdisks.

---

## 🎮 GPU Frequency Table — Adreno 650

> **10 custom Operating Performance Points (OPPs)** — 7 more granular steps than stock!

```text
╔═══════════╦══════════════╦═══════════════════════════════════════════╗
║ Frequency ║ Voltage Drop ║ Workload                                  ║
╠═══════════╬══════════════╬═══════════════════════════════════════════╣
║  670 MHz  ║ 1-Step (UV)  ║ 🔴 Peak 3D: Genshin, BGMI max FPS         ║
║  587 MHz  ║ 1-Step (UV)  ║ 🟠 Heavy 3D: Camera viewfinder, 3D apps   ║
║  525 MHz  ║ 1-Step (UV)  ║ 🟡 Moderate 3D: Medium gaming             ║
║  490 MHz  ║ 1-Step (UV)  ║ 🟡 UI transitions: App open/close anim    ║
║  441 MHz  ║ 1-Step (UV)  ║ 🟢 120Hz scrolling: Instagram, Twitter    ║
║  400 MHz  ║ 1-Step (UV)  ║ 🟢 Standard 120Hz: Frame pacing, light 2D ║
║  305 MHz  ║ 1-Step (UV)  ║ 🔵 Light UI: 1080p/4K video playback      ║
║  250 MHz  ║ Stock        ║ 🔵 Low power: Static reading, 60Hz idle   ║
║  200 MHz  ║ Stock        ║ ⚪ Ultra-low: Background rendering, AOD   ║
║  150 MHz  ║ Stock        ║ ⚪ Deep idle: Screen-off compositing       ║
╚═══════════╩══════════════╩═══════════════════════════════════════════╝
```

**Stock had only 3 active steps** (480, 381, 290 MHz). Our 10-step table gives the GPU governor much finer control — it can pick the exact right frequency for each workload instead of jumping between coarse steps.

---

## 🏎️ CPU Frequency Table — Kryo 585

### PRIME Core (Core 7 | Burst/Heavy Load) — ⚡ Capped at 2.84 GHz

> **Stock Prime max:** 3.18 GHz (3187 MHz) → **Patched:** 2.84 GHz (2841 MHz)  
> This reduction matches the Fusion X thermal limit, eliminating extreme heat spikes at peak load while remaining imperceptible in real-world 120Hz usage and gaming.

---

## 📥 Download & Flash

### Step 1: Download
Go to **[Releases](https://github.com/PandeyJI-9/Extreme-PLUS-kernel-munch/releases)** → download the latest `.zip`.

### Step 2: Flash
1. Reboot into **TWRP / OrangeFox** recovery.
2. *(Recommended)* Backup `boot` and `dtbo` partitions.
3. Flash `EXTREME++HyperOS-munch-*.zip`
4. Reboot to System.

*(Note: The AnyKernel3 zip is explicitly designed to leave your `vendor_boot` recovery partition untouched, flashing custom hardware frequencies safely via `dtbo`.)*

### Step 3: Verify
After booting, open a terminal emulator and run:
```bash
uname -r
# Should show: 5.4.xxx-EXTREME++HyperOS
```

---

## 💬 Community & Support

Having issues? Want to request a feature? Join our Telegram support group:
👉 **[Extreme+ Support Group](https://t.me/Extremeplus_Support)**

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
