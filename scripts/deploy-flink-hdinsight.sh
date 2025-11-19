#!/bin/bash
# Deploy Flink Job to HDInsight Cluster

set -e

echo "🚀 Deploying Flink Job to Azure HDInsight..."

# Variables
CLUSTER_NAME="${1:-ride-booking-hdinsight}"
SSH_USER="${2:-sshuser}"
SSH_PASS="${3:-P@ssw0rd123!}"
RESOURCE_GROUP="${4:-cloudProject}"

# Get cluster SSH endpoint
echo "📡 Getting HDInsight SSH endpoint..."
SSH_ENDPOINT=$(az hdinsight show \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.connectivityEndpoints[?name=='SSH'].location" \
  -o tsv)

if [ -z "$SSH_ENDPOINT" ]; then
  echo "❌ Error: Could not get SSH endpoint"
  exit 1
fi

echo "✅ SSH Endpoint: $SSH_ENDPOINT"

# Install Flink on HDInsight cluster
echo "📦 Installing Flink..."
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$SSH_ENDPOINT" << 'EOF'
# Download and install Flink
cd /home/sshuser
if [ ! -d "flink-1.17.1" ]; then
  wget https://archive.apache.org/dist/flink/flink-1.17.1/flink-1.17.1-bin-scala_2.12.tgz
  tar -xzf flink-1.17.1-bin-scala_2.12.tgz
  rm flink-1.17.1-bin-scala_2.12.tgz
fi
cd flink-1.17.1

# Start Flink cluster
./bin/stop-cluster.sh 2>/dev/null || true
./bin/start-cluster.sh

echo "✅ Flink cluster started"
EOF

# Build and copy Flink job JAR
echo "🔨 Building Flink job..."
cd "$(dirname "$0")/../analytics/flink-job"
./mvnw clean package

# Copy JAR to HDInsight
echo "📤 Uploading Flink job JAR..."
JAR_FILE="target/ride-analytics-1.0.jar"
sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$JAR_FILE" "$SSH_USER@$SSH_ENDPOINT:/home/sshuser/flink-1.17.1/"

# Get Event Hub connection string
echo "📡 Getting Event Hub connection string..."
EVENTHUB_CONN=$(cd ../../infra/azure && terraform output -raw eventhub_connection_string)
COSMOSDB_CONN=$(cd ../../infra/azure && terraform output -raw cosmosdb_connection_string)

# Submit Flink job
echo "🚀 Submitting Flink job..."
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$SSH_ENDPOINT" << EOF
cd /home/sshuser/flink-1.17.1
./bin/flink run \
  -c com.ridebooking.RideAnalyticsJob \
  ride-analytics-1.0.jar \
  --eventhub-connection-string "$EVENTHUB_CONN" \
  --cosmosdb-connection-string "$COSMOSDB_CONN"
EOF

echo "✅ Flink job deployed successfully!"
echo ""
echo "📊 Access Flink Web UI:"
echo "   ssh -L 8081:localhost:8081 $SSH_USER@$SSH_ENDPOINT"
echo "   Then open: http://localhost:8081"

