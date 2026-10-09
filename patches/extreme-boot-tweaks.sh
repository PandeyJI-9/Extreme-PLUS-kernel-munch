#!/bin/sh
# ═══════════════════════════════════════════════════════════════
#  PROJECT EXTREME++ | Maintainer: PandeyJI-9
#  Schedutil Workload Tweaks | POCO F4 (munch) | HyperOS ONLY
# ═══════════════════════════════════════════════════════════════
# This script is injected into /vendor/bin/ and run at boot
# via init.rc to dynamically tune the schedutil governor.

sleep 15 # Wait for boot completion

echo "Applying EXTREME++GAMING Schedutil & Workload rules..." > /dev/kmsg

# ── 1. LITTLE Cluster (Cores 0-3 | Efficiency) ──
echo 1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl 2>/dev/null || true
echo 614400 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 2>/dev/null || true
echo 500 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us 2>/dev/null || true
echo 20000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 2>/dev/null || true

# ── 2. GOLD Cluster (Cores 4-6 | Performance) ──
echo 1 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/pl 2>/dev/null || true
echo 1382400 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq 2>/dev/null || true
echo 500 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us 2>/dev/null || true
echo 20000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us 2>/dev/null || true

# ── 3. PRIME Cluster (Core 7 | Burst/Heavy Load) ──
echo 1 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl 2>/dev/null || true
echo 1632000 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq 2>/dev/null || true
echo 500 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us 2>/dev/null || true
echo 20000 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us 2>/dev/null || true

# ── 4. EXTREME+ Governor Tunables (Zero Lag, Frame-Pacing) ──
for gov_path in /sys/devices/system/cpu/cpufreq/policy*/extreme+; do
    if [ -d "$gov_path" ]; then
        echo 500 > "$gov_path/up_rate_limit_us" 2>/dev/null || true
        echo 20000 > "$gov_path/down_rate_limit_us" 2>/dev/null || true
    fi
done

# Prevent upmigrate bouncing by increasing margins
if [ -f /proc/sys/kernel/sched_upmigrate ]; then
    echo "85 95" > /proc/sys/kernel/sched_upmigrate
    echo "65 75" > /proc/sys/kernel/sched_downmigrate
fi

echo "EXTREME++GAMING: Tuned successfully." > /dev/kmsg
exit 0
