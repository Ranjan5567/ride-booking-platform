#!/bin/bash
# Check and restart analytics script

cd /tmp

echo "=== Stopping old script ==="
pkill -f ride_analytics_standalone.py
sleep 2

echo "=== Downloading script ==="
gsutil cp gs://careful-cosine-478715-a0-dataproc-staging-8bf85efcc32f4f5d/flink-jobs/ride_analytics_standalone.py .

echo "=== Setting environment ==="
export PUBSUB_PROJECT_ID='careful-cosine-478715-a0'
export PUBSUB_RIDES_SUBSCRIPTION='ride-booking-rides-flink'
export PUBSUB_RESULTS_TOPIC='ride-booking-ride-results'
export FIRESTORE_COLLECTION='ride_analytics'

echo "=== Starting script ==="
nohup python3 ride_analytics_standalone.py > analytics.log 2>&1 &

sleep 8

echo ""
echo "=== Process Status ==="
ps aux | grep ride_analytics | grep -v grep

echo ""
echo "=== Log File Contents ==="
if [ -f analytics.log ]; then
    cat analytics.log
else
    echo "Log file not created yet"
fi

echo ""
echo "=== Testing Firestore Connection ==="
python3 << 'PYEOF'
from google.cloud import firestore
try:
    db = firestore.Client(project='careful-cosine-478715-a0', database='ride-booking-analytics')
    docs = list(db.collection('ride_analytics').limit(5).stream())
    print(f'Found {len(docs)} documents in ride_analytics')
    for doc in docs:
        print(f'  - {doc.id}: {doc.to_dict()}')
except Exception as e:
    print(f'Error: {e}')
PYEOF

