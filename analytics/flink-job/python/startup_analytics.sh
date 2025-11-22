#!/bin/bash
# Startup script to automatically start analytics job on Dataproc cluster
# This runs after cluster initialization

# Wait for cluster to be fully ready
sleep 30

# Run the install and start script
bash /tmp/install_and_run.sh

