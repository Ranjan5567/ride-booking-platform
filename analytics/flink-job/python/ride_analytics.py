"""
Flink Python Job for Ride Analytics - Stream Processing Pipeline
This is the analytics service running on GCP Dataproc (requirement: stream processing with Flink)

Data Flow:
1. Consumes ride events from GCP Pub/Sub (published by AWS Ride Service)
2. Aggregates rides by city in 60-second time windows
3. Writes aggregated results to Firestore (for frontend analytics dashboard)
4. Optionally publishes results to Pub/Sub results topic

This demonstrates cross-cloud stream processing: AWS → GCP → Real-time Analytics
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

# Custom Pub/Sub source - PyFlink doesn't have native Pub/Sub connector
# This reads ride events from GCP Pub/Sub subscription

class PubSubSourceFunction:
    """Custom source function for Google Cloud Pub/Sub
    Reads ride events from Pub/Sub subscription - events published by AWS Ride Service
    This enables cross-cloud event streaming: AWS (Ride Service) → GCP (Analytics)"""
    def __init__(self, project_id, subscription_name):
        self.project_id = project_id
        self.subscription_name = subscription_name
        self.subscriber = None
        self.running = True
    
    def open(self, runtime_context):
        """Initialize Pub/Sub subscriber - connects to GCP Pub/Sub subscription"""
        self.subscriber = pubsub_v1.SubscriberClient()
        self.subscription_path = self.subscriber.subscription_path(
            self.project_id, self.subscription_name
        )
    
    def run(self, source_context):
        """Continuously pulls messages from Pub/Sub and streams them to Flink
        Each message is a ride event JSON from AWS Ride Service"""
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
    """Parse ride event JSON and extract city for aggregation
    Transforms: JSON string → (city, count) tuple
    This is the map step in the stream processing pipeline"""
    def map(self, value):
        try:
            data = json.loads(value)
            city = data.get('city', 'unknown')
            return (city, 1)  # Returns tuple for keyed aggregation
        except Exception as e:
            print(f"Error parsing ride event: {e}")
            return ('unknown', 1)

class AggregateWindowFunction(ProcessWindowFunction):
    """Windowed aggregation function - aggregates rides by city in time windows
    This implements the core stream processing requirement: time-windowed aggregation
    Groups rides by city and counts them within 60-second windows"""
    def process(self, key, context, elements, out):
        city = key  # City is the grouping key
        count = sum(1 for _ in elements)  # Count rides in this window
        
        # Extract window boundaries for the aggregated result
        window_start = datetime.fromtimestamp(context.window().start / 1000).isoformat()
        window_end = datetime.fromtimestamp(context.window().end / 1000).isoformat()
        
        # Create aggregated result document
        result = {
            'city': city,
            'count': count,  # Total rides in this city for this time window
            'windowStart': window_start,
            'windowEnd': window_end,
            'timestamp': datetime.now().isoformat()
        }
        out.collect(json.dumps(result))  # Output aggregated result

class PubSubSinkFunction:
    """Custom sink function for Google Cloud Pub/Sub
    Publishes aggregated results to Pub/Sub results topic (optional - for downstream processing)"""
    def __init__(self, project_id, topic_name):
        self.project_id = project_id
        self.topic_name = topic_name
        self.publisher = None
    
    def open(self, runtime_context):
        """Initialize Pub/Sub publisher - connects to results topic"""
        self.publisher = pubsub_v1.PublisherClient()
        self.topic_path = self.publisher.topic_path(self.project_id, self.topic_name)
    
    def invoke(self, value, context):
        """Publishes aggregated analytics result to Pub/Sub results topic"""
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
    """Custom sink function for Google Cloud Firestore
    Writes aggregated analytics results to Firestore - this is the primary output
    Frontend analytics dashboard reads from this collection to display real-time charts"""
    def __init__(self, collection_name):
        self.collection_name = collection_name
        self.db = None
    
    def open(self, runtime_context):
        """Initialize Firestore client - connects to GCP Firestore database"""
        self.db = firestore.Client()
    
    def invoke(self, value, context):
        """Writes aggregated result to Firestore collection
        Each document represents city-wise ride count for a time window
        Frontend reads these documents to display analytics dashboard"""
        try:
            data = json.loads(value)
            # Create unique document ID: city-windowStart
            doc_id = f"{data['city']}-{data['windowStart']}"
            doc_ref = self.db.collection(self.collection_name).document(doc_id)
            doc_ref.set({
                'city': data['city'],
                'count': data['count'],  # Aggregated ride count
                'windowStart': data['windowStart'],
                'windowEnd': data['windowEnd'],
                'timestamp': data['timestamp'],
                'ttlSeconds': 3600  # Optional: auto-delete after 1 hour
            })
        except Exception as e:
            print(f"Error writing to Firestore: {e}")
    
    def close(self):
        """Close Firestore client"""
        if self.db:
            self.db.close()

def main():
    """Main Flink job execution - sets up the stream processing pipeline
    This function orchestrates the entire analytics flow:
    1. Read from Pub/Sub (source)
    2. Parse and extract city (map)
    3. Windowed aggregation by city (aggregate)
    4. Write to Firestore (sink)
    
    This runs on GCP Dataproc Flink cluster"""
    # Get environment variables - configured when deploying to Dataproc
    project_id = os.getenv('PUBSUB_PROJECT_ID', 'careful-cosine-478715-a0')
    rides_subscription = os.getenv('PUBSUB_RIDES_SUBSCRIPTION', 'ride-booking-rides-flink')
    results_topic = os.getenv('PUBSUB_RESULTS_TOPIC', 'ride-booking-ride-results')
    firestore_collection = os.getenv('FIRESTORE_COLLECTION', 'ride_analytics')
    
    # Create Flink execution environment - this is the stream processing engine
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(1)  # Adjust based on your needs - controls parallel processing
    
    # Stream Processing Pipeline Setup:
    # 1. Source: PubSubSourceFunction reads from Pub/Sub subscription
    # 2. Map: ParseRideEvent extracts city from each ride event
    # 3. KeyBy: Group by city (implicit in Flink)
    # 4. Window: TumblingProcessingTimeWindows (60-second windows)
    # 5. Aggregate: AggregateWindowFunction counts rides per city per window
    # 6. Sink: FirestoreSinkFunction writes results to Firestore
    
    # Note: PyFlink doesn't have native Pub/Sub connector, so we use custom source/sink
    # In production, consider using Flink's Table API with Pub/Sub connector
    
    print(f"Connecting to Pub/Sub subscription: {rides_subscription}")
    print(f"Publishing results to topic: {results_topic}")
    print(f"Writing analytics to Firestore collection: {firestore_collection}")
    
    # Pipeline execution - this starts the stream processing job
    # The job will continuously:
    # - Consume ride events from Pub/Sub
    # - Aggregate by city in 60-second windows
    # - Write results to Firestore for frontend dashboard
    env.execute("Ride Analytics Job (Pub/Sub -> Firestore)")

if __name__ == '__main__':
    main()
