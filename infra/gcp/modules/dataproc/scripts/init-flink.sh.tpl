#!/bin/bash
set -e

echo "=== Installing Apache Flink on Dataproc ==="

# Install Java 11 (required for Flink)
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> ~/.bashrc

# Download and install Flink
FLINK_VERSION="1.18.1"
FLINK_HOME="/opt/flink"
FLINK_URL="https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_2.12.tgz"

echo "Downloading Flink ${FLINK_VERSION}..."
cd /tmp
wget -q ${FLINK_URL}
tar -xzf flink-${FLINK_VERSION}-bin-scala_2.12.tgz
sudo mv flink-${FLINK_VERSION} ${FLINK_HOME}
sudo chown -R $(whoami):$(whoami) ${FLINK_HOME}

# Configure Flink
echo "Configuring Flink..."

# Set Flink configuration
cat >> ${FLINK_HOME}/conf/flink-conf.yaml <<EOF
# JobManager configuration
jobmanager.rpc.address: localhost
jobmanager.rpc.port: 6123
jobmanager.memory.process.size: 1600m

# TaskManager configuration
taskmanager.memory.process.size: 1728m
taskmanager.numberOfTaskSlots: 2

# High availability (optional)
high-availability: NONE

# Web UI
rest.port: 8081
rest.address: 0.0.0.0
EOF

# Download Flink Pub/Sub connector
echo "Downloading Flink GCP Pub/Sub connector..."
cd ${FLINK_HOME}/lib
wget -q https://repo1.maven.org/maven2/org/apache/flink/flink-connector-gcp-pubsub/3.0.1-1.18/flink-connector-gcp-pubsub-3.0.1-1.18.jar

# Set environment variables
echo "export FLINK_HOME=${FLINK_HOME}" >> ~/.bashrc
echo "export PATH=\$PATH:${FLINK_HOME}/bin" >> ~/.bashrc

# Create systemd service for Flink (optional - for auto-start)
cat > /tmp/flink-jobmanager.service <<EOF
[Unit]
Description=Apache Flink JobManager
After=network.target

[Service]
Type=simple
User=$(whoami)
Environment=JAVA_HOME=${JAVA_HOME}
Environment=FLINK_HOME=${FLINK_HOME}
ExecStart=${FLINK_HOME}/bin/jobmanager.sh start
ExecStop=${FLINK_HOME}/bin/jobmanager.sh stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Make Flink scripts executable
chmod +x ${FLINK_HOME}/bin/*.sh

echo "=== Flink installation completed ==="
echo "Flink home: ${FLINK_HOME}"
echo "Flink version: ${FLINK_VERSION}"
echo "To start Flink: ${FLINK_HOME}/bin/start-cluster.sh"
echo "Flink Web UI will be available at: http://<master-node>:8081"

