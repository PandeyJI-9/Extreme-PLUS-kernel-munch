#!/bin/sh
# ═══════════════════════════════════════════════════════════════
#  EXTREME++GAMING — Schedutil Workload Tweaks
#  POCO F4 (munch) | HyperOS 3 Optimized
# ═══════════════════════════════════════════════════════════════
# This script is injected into /vendor/bin/ and run at boot
# via init.rc to dynamically tune the schedutil governor.

sleep 15 # Wait for boot completion

echo "Applying EXTREME++GAMING Schedutil & Workload rules..." > /dev/kmsg

# ── 1. LITTLE Cluster (Cores 0-3 | Efficiency) ──
# 300-614: Deep idle, 691-1171: Sync, 1248-1804: OS housekeeping
echo 1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl
echo 614400 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
echo 1000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us
echo 4000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us

# ── 2. GOLD Cluster (Cores 4-6 | Performance) ──
# 710-1286: Static UI, 1382-1958: 120Hz pacing, 2054-2419: Sustained load
echo 1 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/pl
echo 1382400 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq
echo 500 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us
echo 8000 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us

# ── 3. PRIME Cluster (Core 7 | Burst/Heavy Load) ──
# 844-1516: Parking, 1632-2457: Burst mitigation, 2553-3000: Cold launch/3D
echo 1 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl
echo 1632000 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq
echo 500 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us
echo 10000 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us

# Prevent upmigrate bouncing by increasing margins
if [ -f /proc/sys/kernel/sched_upmigrate ]; then
    echo "85 90" > /proc/sys/kernel/sched_upmigrate
    echo "75 80" > /proc/sys/kernel/sched_downmigrate
fi

echo "EXTREME++GAMING: Tuned successfully." > /dev/kmsg
exit 0
