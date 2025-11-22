#!/bin/bash
# Install packages and start analytics script

# Install packages with --break-system-packages (Dataproc requirement)
echo "Installing Python packages..."
pip3 install --break-system-packages --upgrade pip
pip3 install --break-system-packages google-cloud-pubsub google-cloud-firestore

# Verify installation
python3 -c "from google.cloud import pubsub_v1, firestore; print('✅ Packages installed')" || echo "⚠️  Package verification failed"

# Download script
cd /tmp
gsutil cp gs://careful-cosine-478715-a0-dataproc-staging-8bf85efcc32f4f5d/flink-jobs/ride_analytics_standalone.py .

# Set environment variables
export PUBSUB_PROJECT_ID='careful-cosine-478715-a0'
export PUBSUB_RIDES_SUBSCRIPTION='ride-booking-rides-flink'
export PUBSUB_RESULTS_TOPIC='ride-booking-ride-results'
export FIRESTORE_COLLECTION='ride_analytics'

# Start analytics script (using system python with user packages)
nohup python3 ride_analytics_standalone.py > analytics.log 2>&1 &

sleep 3

# Verify it's running
ps aux | grep ride_analytics | grep -v grep && echo "✅ Analytics script is running!" || echo "❌ Analytics script not running"

