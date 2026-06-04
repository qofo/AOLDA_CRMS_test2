#!/bin/bash
# ==============================================================================
# Fluent Bit Stress & Drift Test
# Estimated Execution Time: 65 Seconds
# ==============================================================================

LOG_FILE="fluent_stress_test_result.log"
echo "=== Fluent Bit Stress & Drift Test Started ===" | tee $LOG_FILE

export INSTANCE_ID="test-instance-uuid-0001"
export PROJECT_ID="test-project-uuid-0001"

# 1. Ensure stress-ng is installed to simulate high resource contention
if ! command -v stress-ng &> /dev/null; then
    echo "Installing stress-ng..."
    sudo apt-get update && sudo apt-get install -y stress-ng
fi

# 2. Generate a temporary configuration for the stress test
# We output data to a local file to verify if data is actively being written 
# without relying on network conditions.
cat << 'EOF' > fluent-bit-stress.conf
[SERVICE]
    Flush           2
    Daemon          Off
    Log_Level       error

[INPUT]
    Name            cpu
    Tag             guest.cpu
    Interval_Sec    2

[OUTPUT]
    Name            stdout
    Match           *
    Format          json_lines
EOF

# Clean up previous test artifacts
rm -f output_stress.json

# 3. Start Fluent Bit in the background
echo "Starting Fluent Bit..."
/opt/fluent-bit/bin/fluent-bit -c fluent-bit-stress.conf > output_stress.json 2>&1 &
FLUENT_PID=$!

# 4. Inject load using stress-ng
# WHY 500M? On a 1GB VM, allocating more might trigger the Linux OOM Killer.
# This command maxes out 1 CPU core and consumes 500MB of memory for 60 seconds.
echo "Injecting load (CPU 100%, 500MB Memory) for 60 seconds..."
#stress--ng --vm 1 --vm-bytes 50M --timeout 60s > /dev/null 2>&1 &
stress-ng --cpu 1 --cpu-load 100 --vm 1 --vm-bytes 500M --timeout 60s > /dev/null 2>&1 &

STRESS_PID=$!

# Print the header for monitoring
printf "%-15s %-10s %-10s %-25s\n" "TIME" "CPU(%)" "RSS(KB)" "TOTAL_JSON_LINES_WRITTEN" | tee -a $LOG_FILE

# 5. Monitor Fluent Bit behavior under heavy system load
# We check every 5 seconds for 60 seconds (12 iterations).
for i in {1..12}; do
    sleep 5
    if ps -p $FLUENT_PID > /dev/null; then
        # Fetch the current CPU and Memory (RSS) usage of Fluent Bit
        METRICS=$(ps -p $FLUENT_PID -o %cpu,rss | tail -n 1)
        CPU=$(echo $METRICS | awk '{print $1}')
        RSS=$(echo $METRICS | awk '{print $2}')
        
        # Count the total lines in the output file to check for "Metric Drift"
        # Since Flush is 2 seconds, we expect the line count to increase steadily.
        # If it stops increasing, the agent is starved of CPU time.
        LINES=$(wc -l < output_stress.json 2>/dev/null || echo "0")
        
        CURRENT_TIME=$(date '+%H:%M:%S')
        printf "%-15s %-10s %-10s %-25s\n" "$CURRENT_TIME" "$CPU" "$RSS" "$LINES lines" | tee -a $LOG_FILE
    else
        echo "[ERROR] Fluent Bit process died unexpectedly under stress!" | tee -a $LOG_FILE
        break
    fi
done

# 6. Clean up processes
echo "Cleaning up processes..."
kill $FLUENT_PID 2>/dev/null

echo "=== Stress Test Completed ===" | tee -a $LOG_FILE
