-- This SQL query identifies network devices experiencing high instability (flapping) over the last 24 hours by detecting status changes, counting them in 1-hour rolling windows, and filtering for \(\ge 5\) changes. It leverages LAG() to compare current status with the previous state. 

--Step-by-Step Breakdown:
--(1) device_state_logs (CTE): 
-- Retrieves/Reads network_ops.raw_logs from the last 24 hours.
-- Uses LAG(status) to pull the status of the previous row (ordered by time, partioned by device_id) into the current row for comparison, creating a prev_status column.

--(2) state_transitions (CTE): 
-- Filters the device_state_logs to keep only rows where the status actually changed (status != prev_status) or it is the first recorded status for that device (prev_status IS NULL). 
-- Pinpointing the exact moments a device changed state. (e.g., UP to DOWN or DOWN to UP).

-- (3) flapping_metrics (CTE): Calculates how many state changes ---(flap_count) occured for each device within a 1-hour rolling window (RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW), leading -up to each timestamp for each device.

-- (4) Final Select: 
-- Joins the results with snowflake_dna.inventory to get device metadata (model, region)
-- filters for devices with \(\ge 5\) changes
-- displays the maximum flaps observed per hour, ordered by severity. 

--SQL: 
WITH device_state_logs AS (
-- Step 1: Use LAG() function to compare current status with the previous one
-- This identifies the exact moment a 'change' happens.
SELECT 
device_id,
status,
event_timestamp,
LAG(status) OVER (PARTITION BY device_id ORDER BY event_timestamp) as prev_status
FROM network_ops.raw_logs
WHERE event_timestamp >= CURRENT_DATE - INTERVAL '24 hours'
),
state_transitions AS (
-- Step 2: Filter for ONLY the rows where a change occurred (Up -> Down or vice versa)
SELECT 
device_id,
event_timestamp,
status as current_status,
prev_status
FROM device_state_logs
WHERE status != prev_status 
OR prev_status IS NULL
),
flapping_metrics AS (
-- Step 3: Use a Window Frame to count changes in a rolling 1-hour window
SELECT 
device_id,
event_timestamp,
COUNT(*) OVER (
PARTITION BY device_id 
ORDER BY event_timestamp 
RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW
) as flap_count
FROM state_transitions
)
-- Final Step: Join with Snowflake DNA for categorization
SELECT 
f.device_id,
dna.equipment_model,
dna.region,
MAX(f.flap_count) as max_flaps_per_hour
FROM flapping_metrics f
JOIN snowflake_dna.inventory dna ON f.device_id = dna.device_id
WHERE f.flap_count >= 5 -- The 'Flapping' threshold
GROUP BY 1, 2, 3
ORDER BY max_flaps_per_hour DESC;


--Output: A list of device_ids, equipment_model, region, and max_flaps_per_hour for devices that have flapped at least 5 times in an hour in the last 24 hours.
