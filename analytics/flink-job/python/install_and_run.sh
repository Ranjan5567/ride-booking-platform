#!/bin/bash
# Script to start analytics job on Dataproc
# This script uses the virtual environment created by init_install_packages.sh

set -e

VENV_PATH="/opt/analytics-env"
SCRIPT_PATH="/tmp/ride_analytics_standalone.py"

echo "=========================================="
echo "Starting Ride Analytics Processor"
echo "=========================================="

# Check if virtual environment exists
if [ ! -d "$VENV_PATH" ]; then
    echo "ERROR: Virtual environment not found at $VENV_PATH"
    echo "Please ensure initialization script ran successfully"
    exit 1
fi

# Download the analytics script from GCS if not present
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Downloading analytics script from GCS..."
    # Get bucket name from metadata or environment
    BUCKET_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/dataproc-bucket || echo "")
    if [ -z "$BUCKET_NAME" ]; then
        echo "ERROR: Could not determine GCS bucket. Please upload script manually."
        exit 1
    fi
    gsutil cp "gs://${BUCKET_NAME}/flink-jobs/ride_analytics_standalone.py" "$SCRIPT_PATH"
fi

# Set environment variables
export PUBSUB_PROJECT_ID="${PUBSUB_PROJECT_ID:-careful-cosine-478715-a0}"
export PUBSUB_RIDES_SUBSCRIPTION="${PUBSUB_RIDES_SUBSCRIPTION:-ride-booking-rides-flink}"
export PUBSUB_RESULTS_TOPIC="${PUBSUB_RESULTS_TOPIC:-ride-booking-ride-results}"
export FIRESTORE_COLLECTION="${FIRESTORE_COLLECTION:-ride_analytics}"

# Check if script is already running
if pgrep -f "ride_analytics_standalone.py" > /dev/null; then
    echo "Analytics script is already running!"
    exit 0
fi

# Activate virtual environment and run script
echo "Activating virtual environment and starting analytics processor..."
source "$VENV_PATH/bin/activate"

# Run in background with nohup
nohup "$VENV_PATH/bin/python3" "$SCRIPT_PATH" > /tmp/analytics.log 2>&1 &
ANALYTICS_PID=$!

echo "✅ Analytics job started with PID: $ANALYTICS_PID"
echo "📋 Logs available at: /tmp/analytics.log"
echo "🔍 Check status: ps aux | grep ride_analytics"
echo "=========================================="

