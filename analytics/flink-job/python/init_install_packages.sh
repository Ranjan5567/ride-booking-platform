#!/bin/bash
# Dataproc Initialization Script
# Installs Python packages required for analytics processing
# This script will continue even if network access fails (packages can be installed later)

echo "=========================================="
echo "Installing Python packages for analytics"
echo "=========================================="

# Install python3-venv if not present
if ! command -v python3 -m venv &> /dev/null; then
    echo "Installing python3-venv..."
    apt-get update -qq || echo "Warning: apt-get update failed"
    apt-get install -y -qq python3.11-venv python3-pip || echo "Warning: apt-get install failed"
fi

# Create virtual environment
VENV_PATH="/opt/analytics-env"
echo "Creating virtual environment at $VENV_PATH..."
python3 -m venv $VENV_PATH || {
    echo "ERROR: Failed to create virtual environment"
    exit 0  # Don't fail cluster creation
}

# Activate virtual environment
source $VENV_PATH/bin/activate || {
    echo "ERROR: Failed to activate virtual environment"
    exit 0
}

# Try to upgrade pip (non-blocking)
echo "Upgrading pip (may fail if no internet)..."
pip install --upgrade pip setuptools wheel || echo "Warning: pip upgrade failed (no internet access)"

# Try to install required Google Cloud libraries (non-blocking)
echo "Installing google-cloud-pubsub (may fail if no internet)..."
pip install google-cloud-pubsub || echo "Warning: google-cloud-pubsub installation failed - will install manually later"

echo "Installing google-cloud-firestore (may fail if no internet)..."
pip install google-cloud-firestore || echo "Warning: google-cloud-firestore installation failed - will install manually later"

# Try to verify installation (non-blocking)
echo "Verifying installation..."
python3 -c "from google.cloud import pubsub_v1, firestore; print('✅ SUCCESS: All packages installed correctly')" 2>/dev/null || {
    echo "⚠️  WARNING: Packages not installed (no internet access)"
    echo "Packages will be installed manually after cluster creation"
}

# Make venv accessible system-wide
chmod -R 755 $VENV_PATH

echo "=========================================="
echo "Initialization script complete!"
echo "Virtual environment: $VENV_PATH"
echo "Note: If packages failed to install, they will be installed manually"
echo "=========================================="

# Always exit successfully to allow cluster creation
exit 0

