"""
Flink Python Job for Ride Analytics
Aggregates rides per city per minute from Google Cloud Pub/Sub
Writes results to Pub/Sub and Firestore
"""
import os
import json
from datetime import datetime
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.common.serialization import SimpleStringSchema
from pyflink.common.typeinfo import Types
from pyflink.datastream.functions import MapFunction, ProcessWindowFunction
from pyflink.datastream.window import TumblingProcessingTimeWindows
from pyflink.common import Time
from pyflink.datastream.connectors import FlinkKafkaConsumer
from google.cloud import pubsub_v1
from google.cloud import firestore

# For Pub/Sub, we'll use a custom source that wraps Google Cloud Pub/Sub Python client
# Note: PyFlink doesn't have a direct Pub/Sub connector, so we'll use a custom implementation

class PubSubSourceFunction:
    """Custom source function for Google Cloud Pub/Sub"""
    def __init__(self, project_id, subscription_name):
        self.project_id = project_id
        self.subscription_name = subscription_name
        self.subscriber = None
        self.running = True
    
    def open(self, runtime_context):
        """Initialize Pub/Sub subscriber"""
        self.subscriber = pubsub_v1.SubscriberClient()
        self.subscription_path = self.subscriber.subscription_path(
            self.project_id, self.subscription_name
        )
    
    def run(self, source_context):
        """Pull messages from Pub/Sub"""
        def callback(message):
            try:
                data = message.data.decode('utf-8')
                source_context.collect(data)
                message.ack()
            except Exception as e:
                print(f"Error processing message: {e}")
                message.nack()
        
        streaming_pull_future = self.subscriber.subscribe(
            self.subscription_path, callback=callback
        )
        
        try:
            streaming_pull_future.result()
        except Exception as e:
            print(f"Error in Pub/Sub subscription: {e}")
            streaming_pull_future.cancel()
    
    def close(self):
        """Close Pub/Sub subscriber"""
        self.running = False
        if self.subscriber:
            self.subscriber.close()

class ParseRideEvent(MapFunction):
    """Parse JSON event and extract city"""
    def map(self, value):
        try:
            data = json.loads(value)
            city = data.get('city', 'unknown')
            return (city, 1)
        except Exception as e:
            print(f"Error parsing ride event: {e}")
            return ('unknown', 1)

class AggregateWindowFunction(ProcessWindowFunction):
    """Aggregate rides per city in time windows"""
    def process(self, key, context, elements, out):
        city = key
        count = sum(1 for _ in elements)
        
        window_start = datetime.fromtimestamp(context.window().start / 1000).isoformat()
        window_end = datetime.fromtimestamp(context.window().end / 1000).isoformat()
        
        result = {
            'city': city,
            'count': count,
            'windowStart': window_start,
            'windowEnd': window_end,
            'timestamp': datetime.now().isoformat()
        }
        out.collect(json.dumps(result))

class PubSubSinkFunction:
    """Custom sink function for Google Cloud Pub/Sub"""
    def __init__(self, project_id, topic_name):
        self.project_id = project_id
        self.topic_name = topic_name
        self.publisher = None
    
    def open(self, runtime_context):
        """Initialize Pub/Sub publisher"""
        self.publisher = pubsub_v1.PublisherClient()
        self.topic_path = self.publisher.topic_path(self.project_id, self.topic_name)
    
    def invoke(self, value, context):
        """Publish message to Pub/Sub"""
        try:
            data = value.encode('utf-8')
            future = self.publisher.publish(self.topic_path, data)
            future.result()  # Wait for publish to complete
        except Exception as e:
            print(f"Error publishing to Pub/Sub: {e}")
    
    def close(self):
        """Close Pub/Sub publisher"""
        if self.publisher:
            self.publisher.close()

class FirestoreSinkFunction:
    """Custom sink function for Google Cloud Firestore"""
    def __init__(self, collection_name):
        self.collection_name = collection_name
        self.db = None
    
    def open(self, runtime_context):
        """Initialize Firestore client"""
        self.db = firestore.Client()
    
    def invoke(self, value, context):
        """Write aggregate to Firestore"""
        try:
            data = json.loads(value)
            doc_id = f"{data['city']}-{data['windowStart']}"
            doc_ref = self.db.collection(self.collection_name).document(doc_id)
            doc_ref.set({
                'city': data['city'],
                'count': data['count'],
                'windowStart': data['windowStart'],
                'windowEnd': data['windowEnd'],
                'timestamp': data['timestamp'],
                'ttlSeconds': 3600
            })
        except Exception as e:
            print(f"Error writing to Firestore: {e}")
    
    def close(self):
        """Close Firestore client"""
        if self.db:
            self.db.close()

def main():
    """Main Flink job execution"""
    # Get environment variables
    project_id = os.getenv('PUBSUB_PROJECT_ID', 'careful-cosine-478715-a0')
    rides_subscription = os.getenv('PUBSUB_RIDES_SUBSCRIPTION', 'ride-booking-rides-flink')
    results_topic = os.getenv('PUBSUB_RESULTS_TOPIC', 'ride-booking-ride-results')
    firestore_collection = os.getenv('FIRESTORE_COLLECTION', 'ride_analytics')
    
    # Create Flink execution environment
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(1)  # Adjust based on your needs
    
    # For PyFlink on Dataproc, we'll use a workaround:
    # Since PyFlink doesn't have native Pub/Sub connector, we'll use
    # a custom source that reads from Pub/Sub using the Python client
    # In production, consider using Flink's Table API with Pub/Sub connector
    
    # Create custom Pub/Sub source
    # Note: This is a simplified version. For production, implement proper SourceFunction
    print(f"Connecting to Pub/Sub subscription: {rides_subscription}")
    print(f"Publishing results to topic: {results_topic}")
    print(f"Writing analytics to Firestore collection: {firestore_collection}")
    
    # For now, we'll use a placeholder that reads from a file or uses Kafka
    # In production on Dataproc, you would:
    # 1. Use Flink's Table API with Pub/Sub connector (if available)
    # 2. Or use a custom Java source function and call it from Python
    # 3. Or use the Python Pub/Sub client in a custom source
    
    # This is a template - actual implementation depends on Dataproc Flink setup
    print("Note: This script needs to be adapted for Dataproc's Flink Python environment")
    print("Consider using Flink Table API or custom Java source functions")
    
    env.execute("Ride Analytics Job (Pub/Sub -> Firestore)")

if __name__ == '__main__':
    main()
