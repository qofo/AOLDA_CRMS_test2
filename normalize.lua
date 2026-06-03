-- =====================================================================
-- Data Schema Transformation Function
-- Restructures Fluent Bit telemetry records into the unified CRMS schema format.
-- =====================================================================
function format_to_crms_schema(tag, timestamp, record)
    local new_record = {}
    
    -- -----------------------------------------------------------------
    -- 1. Infrastructure Resource Component Assembly
    -- -----------------------------------------------------------------
    -- Extracts and maps the environment metadata to define the source identity.
    new_record["resource"] = {
        ["type"] = "instance",
        ["id"] = record["resource_id"] or "unknown_instance",
        ["project_id"] = record["project_id"] or "unknown_project"
    }

    -- -----------------------------------------------------------------
    -- 2. Initialization of Metric Specifications and Data Payloads
    -- -----------------------------------------------------------------
    -- Establishes safe fallback defaults before conditional parsing.
    local metric_name = tag
    local metric_type = "gauge"
    local metric_unit = "unknown"
    local value = 0.0

    -- -----------------------------------------------------------------
    -- 3. Telemetry Input Tag-Based Routing and Raw Metric Normalization
    -- -----------------------------------------------------------------
    -- Parses specific input plugin tags to map raw internal fields to standard formats.
    if tag == "guest.cpu" then
        -- CPU Utilization Parsing
        metric_name = "guest.cpu.util"
        metric_unit = "percent"
        value = record["cpu_p"] or 0.0
        
    elseif tag == "guest.memory" then
        -- Memory Consumption Percentage Parsing
        metric_name = "guest.memory.used_percent"
        metric_unit = "percent"
        -- value = record["Mem.used_p"] or 0.0
        local mem_total = record["Mem.total"] or 1
        local mem_used = record["Mem.used"] or 0
        value = (mem_used / mem_total) * 100
        
    elseif tag == "guest.net" then
        -- Network Traffic Parsing (Inbound Interface Bytes)
        -- Configured as a cumulative counter to track total rx.bytes over time.
        metric_name = "guest.net.in.bytes"
        metric_type = "cumulative"
        metric_unit = "bytes"
        value = record["rx.bytes"] or 0.0
        
    elseif tag == "guest.disk" then
        -- Storage Subsystem I/O Parsing (Disk Read Bytes)
        -- Configured as a cumulative counter to track cumulative bytes read.
        metric_name = "guest.disk.read.bytes"
        metric_type = "cumulative"
        metric_unit = "bytes"
        value = record["read_size"] or 0.0
    end

    -- Construct the standardized metric definitions block
    new_record["metric"] = {
        ["name"] = metric_name,
        ["type"] = metric_type,
        ["unit"] = metric_unit
    }

    -- -----------------------------------------------------------------
    -- 4. Timestamp Serialization & Compatibility Processing
    -- -----------------------------------------------------------------
    -- Handles diverse Fluent Bit internal timestamp formats.
    -- Unwraps table objects (containing seconds and nanoseconds) to extract the Unix epoch seconds.
    local ts = timestamp
    if type(timestamp) == "table" then
        ts = timestamp["sec"]
    end

    -- Construct the payload block pairing the cleaned timestamp with the metric value
    new_record["measure"] = {
        ["timestamp"] = ts,
        ["value"] = value
    }

    -- -----------------------------------------------------------------
    -- 5. Execution Pipeline Handshake Return
    -- -----------------------------------------------------------------
    -- Status Code '1' signals Fluent Bit that the original record has been 
    -- successfully replaced by the new modified structure ('new_record').
    return 1, timestamp, new_record
end
