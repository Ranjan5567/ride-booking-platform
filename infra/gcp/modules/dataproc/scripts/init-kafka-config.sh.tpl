#!/bin/bash
# Initialize Kafka configuration for Flink on Dataproc

set -e

# Create Kafka configuration file
cat > /etc/kafka/kafka.properties << EOF
bootstrap.servers=${kafka_bootstrap}
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="${kafka_api_key}" password="${kafka_api_secret}";
EOF

# Set permissions
chmod 600 /etc/kafka/kafka.properties

# Create Flink Kafka connector directory
mkdir -p /usr/lib/flink/lib/

# Download Flink Kafka connector (if not already present)
cd /usr/lib/flink/lib/
if [ ! -f flink-sql-connector-kafka-*.jar ]; then
    wget -q https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.17.0/flink-sql-connector-kafka-1.17.0.jar
fi

echo "Kafka configuration completed successfully"

