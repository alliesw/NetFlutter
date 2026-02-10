# NetFlutter
This project provides a high-performance SQL analytical engine designed to identify intermittent instability or "flapping" devices—nodes or ports that rapidly cycle between UP and DOWN states - across millions of network events

The Problem: The "Silent" Outage
Standard monitoring often misses devices that toggle states 10+ times an hour but never stay down long enough to "red line" a dashboard. This tool was developed to:
* Identify "Top Talker" flapping devices in real-time.
* Correlate instability with specific hardware models via Snowflake DNA (Digital Network Architecture) inventory.
* Reduce Mean Time to Resolution (MTTR) by pinpointing flaky firmware versions.
  
Tech Stack
* SQL Dialects: Optimized for Snowflake, AWS Athena, and Postgres.
* Tools: PGadmin (Database Admin), DBeaver (Query Development).
* Observability: Integrated with Splunk for dashboarding and alerting.

Core Logic: The Flap Detection Engine
The heart of this project is a multi-stage Common Table Expression (CTE) that avoids expensive self-joins by utilizing the LAG() window function and a sliding temporal frame.

Key Technical Features:
* State Transition Detection: Uses LAG() window function (self-joins > less optimal for large datasets) to compare current status against the previous row within a PARTITION BY device_id in snowflake - since we were dealing with millions of rows we needed to optimize this in snowflake at scale.  
* Rolling Window Analytics: I used RANGE BETWEEN frame (INTERVAL '1 hour' PRECEDING) to calculate a "Flap Score" - or counting how many times a device toggled within a sliding 60-minute window.
* Cross-Platform Integration: Joins raw S3/Log data with structured inventory metadata (Snowflake/Postgres) to provide geographical context.

FOLDER STRUCTURE 
-----------------------------------------------------------------------
* /sql-scripts: Contains your NetFlutter.sql.
* /splunk-configs: Contains your .conf files or sample SPL queries.
* /docs: A screenshot of a DBeaver ER diagram.

* ER Diagram: A visual of how your raw logs link to the DNA inventory.
• Performance Notes: Use CTEs for readability and Window Functions to avoid the nightmare of self-joins.
• Splunk Integration: The results of this query are what are used to feed your Splunk Dashboards, creating a 'Top 10 Flapping Devices' view for the NOC.

Splunk Project Module 
Module: Real-Time Observability with Splunk
While the SQL engine identifies historical trends, I integrated this logic into Splunk to provide the Network Operations Center (NOC) with a "Live Heatmap" of network instability.

Key Deliverables:
* The "Flap-Count" Dashboard: A real-time visualization that correlates raw syslog data with the "Flap Score" logic. It uses a 5-minute sliding window to trigger visual alerts (Yellow/Red) before a customer-facing outage occurs.
* Indexing Strategy: Optimized data inputs to ensure high-velocity network logs were indexed with the correct sourcetype, allowing for sub-second search performance during high-traffic events.
* Actionable Alerting: Configured Splunk alerts to trigger a webhook into our ticketing system when a device's "Flap Score" exceeds 10 transitions per hour.
  
Splunk Search (SPL) Equivalent:
index=network_logs sourcetype=cisco_ios 
| streamstats current=f last(status) as prev_status by device_id 
| where status != prev_status 
| stats count as flap_count by device_id, _time span=1h 
| where flap_count > 5
| lookup snowflake_dna_inventory device_id OUTPUT equipment_model, region
