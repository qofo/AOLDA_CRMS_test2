#!/bin/bash
# ==============================================================================
# Fluent Bit Network Blackhole & Buffer Test
# Estimated Execution Time: 65 Seconds
# ==============================================================================

LOG_FILE="fluent_buffer_test_result.log"
echo "=== Fluent Bit Network Blackhole Test Started ===" | tee $LOG_FILE

# 1. Simulate a network partition using iptables
# WHY DROP? REJECT returns an immediate error (Connection Refused), which is easy to handle.
# DROP forces the agent into a TCP timeout state, which is a realistic and dangerous scenario.
sudo iptables -A OUTPUT -d 10.255.255.255 -j DROP

# 2. Generate a custom Fluent Bit configuration for the test
# We use a dummy input at a high rate to quickly saturate the buffer.
cat << 'EOF' > fluent-bit-blackhole.conf
[SERVICE]
    Flush           1
    Daemon          Off
    Log_Level       info

[INPUT]
    Name            dummy
    Tag             guest.dummy
    Rate            5000
    # Crucial Setting: Limit memory buffer to 1MB. 
    # When this limit is reached, Fluent Bit must pause data ingestion.
    Mem_Buf_Limit   1M

[OUTPUT]
    Name            http
    Match           *
    Host            10.255.255.255
    Port            8080
    URI             /v1/metrics
    Format          json
    # False means infinite retries. It will hold data in memory until the limit is hit.
    Retry_Limit     False
EOF

# Clean up previous artifacts
rm -f fluent_blackhole_error.log

# 3. Start Fluent Bit in the background
echo "Starting Fluent Bit with 1MB Buffer Limit and targeting a Blackholed IP..."
/opt/fluent-bit/bin/fluent-bit -c fluent-bit-blackhole.conf > fluent_blackhole_error.log 2>&1 &
FLUENT_PID=$!

# Print the header for monitoring
printf "%-15s %-10s %-15s %-30s\n" "TIME" "RSS(KB)" "BUFFER_STATUS" "LATEST_LOG" | tee -a $LOG_FILE

# 4. Monitor the memory and log output for 60 seconds (12 iterations)
for i in {1..12}; do
    sleep 5
    if ps -p $FLUENT_PID > /dev/null; then
        # Check actual OS memory usage
        RSS=$(ps -p $FLUENT_PID -o rss | tail -n 1 | tr -d ' ')
        
        # Check if Fluent Bit has triggered backpressure by pausing the input plugin
        PAUSED=$(grep "pausing" fluent_blackhole_error.log | wc -l)
        if [ "$PAUSED" -gt 0 ]; then
            STATUS="PAUSED (SAFE)"
        else
            STATUS="FILLING"
        fi
        
        # Extract the latest log message for context
        LATEST_LOG=$(tail -n 1 fluent_blackhole_error.log | cut -d']' -f3- | cut -c 2-55)
        
        CURRENT_TIME=$(date '+%H:%M:%S')
        printf "%-15s %-10s %-15s %-30s\n" "$CURRENT_TIME" "$RSS" "$STATUS" "$LATEST_LOG" | tee -a $LOG_FILE
    else
        echo "[ERROR] Fluent Bit process crashed! Memory limit protection failed." | tee -a $LOG_FILE
        break
    fi
done

# 5. Clean up iptables rule and kill the background process
echo "Cleaning up iptables and processes..."
sudo iptables -D OUTPUT -d 10.255.255.255 -j DROP
kill $FLUENT_PID 2>/dev/null
rm -f fluent-bit-blackhole.conf

echo "=== Network Blackhole Test Completed ===" | tee -a $LOG_FILE