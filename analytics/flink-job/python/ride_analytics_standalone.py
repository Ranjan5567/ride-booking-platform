"""
Standalone Python Script for Ride Analytics
Processes Pub/Sub messages and writes to Firestore
Can run on Dataproc without PyFlink dependency
"""
import os
import json
import time
from datetime import datetime
from google.cloud import pubsub_v1
from google.cloud import firestore
from concurrent.futures import ThreadPoolExecutor
from collections import defaultdict

class RideAnalyticsProcessor:
    """Process ride events from Pub/Sub and aggregate by city"""
    
    def __init__(self, project_id, subscription_name, results_topic, firestore_collection):
        self.project_id = project_id
        self.subscription_name = subscription_name
        self.results_topic = results_topic
        self.firestore_collection = firestore_collection
        
        # Initialize clients
        self.subscriber = pubsub_v1.SubscriberClient()
        self.publisher = pubsub_v1.PublisherClient()
        # Specify the database name explicitly
        self.db = firestore.Client(project=project_id, database='ride-booking-analytics')
        
        # Subscription path
        self.subscription_path = self.subscriber.subscription_path(
            project_id, subscription_name
        )
        
        # Topic path for results
        self.topic_path = self.publisher.topic_path(project_id, results_topic)
        
        # Aggregation window (1 minute)
        self.window_size = 60  # seconds
        self.aggregates = defaultdict(int)  # city -> count
        self.last_window_end = time.time()
        
    def process_message(self, message):
        """Process a single Pub/Sub message"""
        try:
            data = json.loads(message.data.decode('utf-8'))
            city = data.get('city', 'unknown')
            
            # Add to current window aggregate
            self.aggregates[city] += 1
            
            # Acknowledge message
            message.ack()
            
            print(f"Processed ride event: city={city}")
            
        except Exception as e:
            print(f"Error processing message: {e}")
            message.nack()
    
    def flush_aggregates(self):
        """Flush current aggregates to Pub/Sub and Firestore"""
        if not self.aggregates:
            return
        
        window_end = datetime.now().isoformat()
        
        for city, count in self.aggregates.items():
            result = {
                'city': city,
                'count': count,
                'windowEnd': window_end,
                'timestamp': window_end
            }
            
            # Publish to Pub/Sub
            try:
                data = json.dumps(result).encode('utf-8')
                future = self.publisher.publish(self.topic_path, data)
                future.result()  # Wait for publish
                print(f"Published to Pub/Sub: {result}")
            except Exception as e:
                print(f"Error publishing to Pub/Sub: {e}")
            
            # Write to Firestore
            try:
                doc_id = f"{city}-{int(time.time())}"
                doc_ref = self.db.collection(self.firestore_collection).document(doc_id)
                doc_ref.set({
                    'city': city,
                    'count': count,
                    'windowEnd': window_end,
                    'timestamp': window_end
                })
                print(f"Written to Firestore: {doc_id}")
            except Exception as e:
                print(f"Error writing to Firestore: {e}")
        
        # Clear aggregates for next window
        self.aggregates.clear()
        self.last_window_end = time.time()
    
    def run(self):
        """Main processing loop"""
        print(f"Starting Ride Analytics Processor")
        print(f"Subscription: {self.subscription_path}")
        print(f"Results Topic: {self.topic_path}")
        print(f"Firestore Collection: {self.firestore_collection}")
        
        def callback(message):
            """Callback for Pub/Sub messages"""
            self.process_message(message)
            
            # Check if we should flush aggregates
            current_time = time.time()
            if current_time - self.last_window_end >= self.window_size:
                self.flush_aggregates()
        
        # Start streaming pull
        streaming_pull_future = self.subscriber.subscribe(
            self.subscription_path, callback=callback
        )
        
        print("Listening for messages...")
        
        try:
            # Keep running and flush aggregates periodically
            while True:
                time.sleep(self.window_size)
                self.flush_aggregates()
        except KeyboardInterrupt:
            print("Stopping processor...")
            # Flush remaining aggregates
            self.flush_aggregates()
            streaming_pull_future.cancel()
            streaming_pull_future.result()  # Wait for cancellation
        except Exception as e:
            print(f"Error in processing loop: {e}")
            streaming_pull_future.cancel()
            raise

def main():
    """Main entry point"""
    # Get environment variables
    project_id = os.getenv('PUBSUB_PROJECT_ID', 'careful-cosine-478715-a0')
    rides_subscription = os.getenv('PUBSUB_RIDES_SUBSCRIPTION', 'ride-booking-rides-flink')
    results_topic = os.getenv('PUBSUB_RESULTS_TOPIC', 'ride-booking-ride-results')
    firestore_collection = os.getenv('FIRESTORE_COLLECTION', 'ride_analytics')
    
    # Create and run processor
    processor = RideAnalyticsProcessor(
        project_id=project_id,
        subscription_name=rides_subscription,
        results_topic=results_topic,
        firestore_collection=firestore_collection
    )
    
    processor.run()

if __name__ == '__main__':
    main()

