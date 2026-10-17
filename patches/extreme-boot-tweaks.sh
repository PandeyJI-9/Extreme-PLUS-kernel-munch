#!/bin/sh
# ═══════════════════════════════════════════════════════════════
#  PROJECT EXTREME++ | Maintainer: PandeyJI-9
#  iPhone-Grade Frame Pacing & EXTREME+ Workload Engine | HyperOS ONLY
#  POCO F4 (munch / SM8250-AC Kona)
# ═══════════════════════════════════════════════════════════════

sleep 15 # Wait for boot completion

echo "Applying EXTREME++ iPhone-Grade Frame Pacing & Governor rules..." > /dev/kmsg

# ── 1. Enforce EXTREME+ Governor on all CPU Policies ──
for p in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -f "$p/scaling_available_governors" ] && grep -q "extreme+" "$p/scaling_available_governors"; then
        echo "extreme+" > "$p/scaling_governor" 2>/dev/null || true
    fi
    for gov in extreme+ schedutil; do
        if [ -d "$p/$gov" ]; then
            echo 500 > "$p/$gov/up_rate_limit_us" 2>/dev/null || true
            echo 20000 > "$p/$gov/down_rate_limit_us" 2>/dev/null || true
            echo 65 > "$p/$gov/hispeed_load" 2>/dev/null || true
            echo 1 > "$p/$gov/pl" 2>/dev/null || true
        fi
    done
done

# Anti-Flicker: Little cluster floor at 576MHz prevents DSI mode-switch flicker during YouTube 120Hz<->60Hz switching
echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq 2>/dev/null || true
echo 710400 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq 2>/dev/null || true
echo 844800 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq 2>/dev/null || true

# Power Efficient Workqueues (Sleep & Battery Optimization)
echo Y > /sys/module/workqueue/parameters/power_efficient 2>/dev/null || true

# ── 2. Hardware Cluster Hispeed Frequencies for Instant App Launch ──
echo 1056000 > /sys/devices/system/cpu/cpufreq/policy0/extreme+/hispeed_freq 2>/dev/null || true
echo 1804800 > /sys/devices/system/cpu/cpufreq/policy4/extreme+/hispeed_freq 2>/dev/null || true
echo 2169600 > /sys/devices/system/cpu/cpufreq/policy7/extreme+/hispeed_freq 2>/dev/null || true

# ── 3. Smooth WALT Migration (Zero Silver Choke, Zero Ping-Pong) ──
if [ -f /proc/sys/kernel/sched_upmigrate ]; then
    echo "65 80" > /proc/sys/kernel/sched_upmigrate
    echo "50 65" > /proc/sys/kernel/sched_downmigrate
    echo 70 > /proc/sys/kernel/sched_group_upmigrate 2>/dev/null || true
    echo 55 > /proc/sys/kernel/sched_group_downmigrate 2>/dev/null || true
fi

echo "EXTREME++: iPhone-grade frame pacing & governor active." > /dev/kmsg
exit 0
