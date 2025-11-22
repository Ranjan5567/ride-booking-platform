#!/bin/bash
# Install required Python packages
echo "Installing dependencies..."
pip3 install google-cloud-pubsub google-cloud-firestore --quiet

# Run the analytics script
echo "Starting Ride Analytics Processor..."
python3 /tmp/ride_analytics_standalone.py


