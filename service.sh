#!/system/bin/sh
MODDIR=${0%/*}

# Wait boot complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 5

# Exynos 990 CPU clusters paths
CLUSTER_LITTLE="/sys/devices/system/cpu/cpu0/cpufreq"
CLUSTER_MID="/sys/devices/system/cpu/cpu4/cpufreq"
CLUSTER_BIG="/sys/devices/system/cpu/cpu6/cpufreq"

get_max_supported_freq() {
    local cpufreq_path=$1

    if [ -f "$cpufreq_path/cpuinfo_max_freq" ]; then
        cat "$cpufreq_path/cpuinfo_max_freq"
    elif [ -f "$cpufreq_path/scaling_available_frequencies" ]; then
        local last_freq=""
        for freq in $(cat "$cpufreq_path/scaling_available_frequencies"); do
            last_freq=$freq
        done
        echo "$last_freq"
    else
        cat "$cpufreq_path/scaling_max_freq" 2>/dev/null
    fi
}

# Get the default maximum frequencies for each cluster
DEFAULT_MAX_LITTLE=$(get_max_supported_freq "$CLUSTER_LITTLE")
DEFAULT_MAX_MID=$(get_max_supported_freq "$CLUSTER_MID")
DEFAULT_MAX_BIG=$(get_max_supported_freq "$CLUSTER_BIG")

# Define the maximum frequencies for each cluster when in power saving mode
# Set the values ​​in Hz, example: "1300000" is 1.3GHZ.
PS_MAX_LITTLE=1300000  # Limita o LITTLE a 1.3 GHz
PS_MAX_MID=1508000     # Limita o MID a 1.508 GHz
PS_MAX_BIG=1690000     # Limita o BIG a 1.690 GHz

# Function to apply the maximum frequencies to each cluster

apply_freqs() {
    local max_little=$1
    local max_mid=$2
    local max_big=$3

    # Apply the maximum frequencies to each cluster
    for i in 0 1 2 3; do
        echo $max_little > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq 2>/dev/null
    done
    for i in 4 5; do
        echo $max_mid > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq 2>/dev/null
    done
    for i in 6 7; do
        echo $max_big > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq 2>/dev/null
    done
}

# Gets the last state of the power saving mode
LAST_STATE=$(settings get global low_power)
if [ "$LAST_STATE" = "1" ]; then
    apply_freqs $PS_MAX_LITTLE $PS_MAX_MID $PS_MAX_BIG
fi

# Main loop to monitor the power saving mode state
while true; do
    CURRENT_STATE=$(settings get global low_power)
    
    if [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
        if [ "$CURRENT_STATE" = "1" ]; then
            apply_freqs $PS_MAX_LITTLE $PS_MAX_MID $PS_MAX_BIG
        else
            apply_freqs $DEFAULT_MAX_LITTLE $DEFAULT_MAX_MID $DEFAULT_MAX_BIG
        fi
        LAST_STATE=$CURRENT_STATE
    fi

    sleep 5 
done
