# Extreme-PLUS Zero-Heat Kernel — POCO F4 (munch)

> **CI/CD-only build. No local clone required.**
> Everything runs on GitHub Actions, fetching source from AstideLabs at build time.

---

## ⚠️ Security — Read First

**Never paste your GitHub PAT into chat or code.**  
Add it as a repository secret:

```
GitHub → Your repo → Settings → Secrets and variables → Actions
→ New repository secret → Name: GH_TOKEN → Paste token
```

---

## Repo Structure

```
.github/
  workflows/
    builder.yml           ← Full kernel build + ZIP
    tester.yml            ← Fast CI: defconfig + DTB only
    verifier.yml          ← Confirms patches compiled correctly
    releaser_and_sync.yml ← Weekly upstream sync + rKSU + Release
patches/
  (drop extra .patch files here — builder.yml applies them automatically)
README.md
```

---

## Zero-Heat Tuning Summary

| Component | Stock | Patched | Method |
|-----------|-------|---------|--------|
| **GPU (Adreno 650) min freq** | 290MHz | **150MHz** | New OPP in `kona-gpu.dtsi` |
| **GPU voltage @ 150MHz** | N/A | `MIN_SVS` | Safe Qualcomm voltage level |
| **CPU7 (Prime / Kryo 585) max** | 3.187GHz | **3.0GHz** | `qcom,freq-domain-max-freq` in `kona.dtsi` |
| CPU4-6 (Gold) | Stock | **Unchanged** | — |
| CPU0-3 (Silver) | Stock | **Unchanged** | — |
| Display (60/90/120Hz) | Stock | **Unchanged** | — |
| Haptics / Sensors | Stock | **Unchanged** | — |
| Battery / Charging | Stock | **Unchanged** | — |

---

## How to Use

### 1. Setup (once)
1. Create a new **empty** repo on GitHub: `PandeyJI-9/Extreme-PLUS-kernel-munch`
2. Push this directory to it
3. Add `GH_TOKEN` secret (see above)

### 2. Manual Build
```
GitHub → Actions → "🔨 Build Extreme-PLUS Kernel" → Run workflow
```
Options:
- **Release tag** — leave empty to just build, or set `v1.0-zero-heat` to publish a Release
- **Inject KSU** — toggle KernelSU

### 3. Fast CI Check (auto on every push)
`tester.yml` runs automatically on every push — takes ~10 min.

### 4. Weekly Auto-Release
`releaser_and_sync.yml` runs every Sunday 02:00 UTC.  
Pulls upstream fixes from AstideLabs, re-applies patches, injects rKSU, builds, publishes Release.

### 5. Manual Release
```
Actions → "🚀 Release + Upstream Sync" → Run workflow → set tag
```

---

## GPU Frequency Table (after patch)

```
Adreno 650 OPP table — kona-gpu.dtsi
────────────────────────────────────────────────────────────
 Freq       Voltage Level        Use case
────────────────────────────────────────────────────────────
 480 MHz    SVS_L1               Heavy gaming / benchmark
 381 MHz    SVS                  Medium gaming / video
 290 MHz    LOW_SVS              Light UI tasks
 150 MHz    MIN_SVS   ← NEW     Idle / ambient / battery save
────────────────────────────────────────────────────────────
```

> The GPU governor (msm-adreno-tz) will automatically select 150MHz
> during idle and low-load scenarios, dropping to MIN_SVS voltage.
> This significantly reduces idle GPU power consumption.

---

## CPU Frequency (after patch)

```
SM8250 CPU topology:
  CPU0-3  Kryo 585 Silver (LITTLE)  → Stock (max ~1.8GHz)
  CPU4-6  Kryo 585 Gold             → Stock (max ~2.42GHz)
  CPU7    Kryo 585 Gold Plus/Prime  → Capped 3.187 → 3.0GHz
```

---

## Source

Kernel: [AstideLabs/android_kernel_xiaomi_sm8250](https://github.com/AstideLabs/android_kernel_xiaomi_sm8250) (branch: `android17-aptusitu`)
