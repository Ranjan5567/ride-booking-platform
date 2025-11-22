#!/bin/bash
# Simple script to restart analytics on cluster

cd /tmp

# Stop old script
pkill -f ride_analytics_standalone.py
sleep 2

# Download fixed script
gsutil cp gs://careful-cosine-478715-a0-dataproc-staging-8bf85efcc32f4f5d/flink-jobs/ride_analytics_standalone.py .

# Set environment variables
export PUBSUB_PROJECT_ID='careful-cosine-478715-a0'
export PUBSUB_RIDES_SUBSCRIPTION='ride-booking-rides-flink'
export PUBSUB_RESULTS_TOPIC='ride-booking-ride-results'
export FIRESTORE_COLLECTION='ride_analytics'

# Start script
nohup python3 ride_analytics_standalone.py > analytics.log 2>&1 &

sleep 5

# Verify
echo "=== Process Status ==="
ps aux | grep ride_analytics | grep -v grep

echo ""
echo "=== Last 20 lines of log ==="
tail -20 analytics.log

