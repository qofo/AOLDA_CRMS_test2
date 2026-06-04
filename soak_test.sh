#!/bin/bash
# ==============================================================================
# Fluent Bit Soak Test (Long-duration Memory Leak & Stability Test)
# Estimated Execution Time: 12 Hours (Configurable)
# ==============================================================================

LOG_FILE="fluent_soak_test_result.log"
echo "=== Fluent Bit Deep Soak Test Started ===" > $LOG_FILE
echo "Monitoring RSS (Memory) and CPU usage to detect memory leaks." >> $LOG_FILE

# Set metadata environment variables required for Fluent Bit
export INSTANCE_ID="test-instance-uuid-0000"
export PROJECT_ID="test-project-uuid-0001"

# Restart Fluent Bit in the background for a clean test environment
# Note: Assumes fluent-bit.conf and normalize.lua are in the current directory
echo "Starting Fluent Bit..."
/opt/fluent-bit/bin/fluent-bit -c fluent-bit.conf > fluent_soak_output.log 2>&1 &
FLUENT_PID=$!

echo "Fluent Bit started with PID: $FLUENT_PID" | tee -a $LOG_FILE
printf "%-25s %-10s %-10s\n" "TIMESTAMP" "CPU(%)" "RSS(KB)" | tee -a $LOG_FILE

# ------------------------------------------------------------------------------
# Test Loop Configuration
# Interval: 300 seconds (5 minutes)
# Iterations: 144 (144 * 5 mins = 720 mins = 12 hours)
# ------------------------------------------------------------------------------
ITERATIONS=72
SLEEP_TIME=300

for ((i=1; i<=ITERATIONS; i++)); do
    # Sleep first to allow Fluent Bit to process initial data
    sleep $SLEEP_TIME
    
    # Check if the process is still running
    if ps -p $FLUENT_PID > /dev/null; then
        # Extract CPU and RSS (Resident Set Size) memory usage
        # This is critical for C-based applications to ensure no memory leaks exist
        METRICS=$(ps -p $FLUENT_PID -o %cpu,rss | tail -n 1)
        CPU=$(echo $METRICS | awk '{print $1}')
        RSS=$(echo $METRICS | awk '{print $2}')
        
        CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        printf "%-25s %-10s %-10s\n" "$CURRENT_TIME" "$CPU" "$RSS" >> $LOG_FILE
    else
        echo "[ERROR] Fluent Bit process ($FLUENT_PID) died unexpectedly at iteration $i!" | tee -a $LOG_FILE
        break
    fi
done

echo "=== Soak Test Completed ===" | tee -a $LOG_FILE