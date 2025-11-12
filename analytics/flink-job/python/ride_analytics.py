"""
Flink Python Job for Ride Analytics
Aggregates rides per city per minute from Azure Event Hub
Writes results to Cosmos DB
"""
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors import FlinkKafkaConsumer
from pyflink.common.serialization import SimpleStringSchema
from pyflink.common.typeinfo import Types
from pyflink.datastream.functions import MapFunction, KeyedProcessFunction
from pyflink.datastream.window import TumblingProcessingTimeWindows
from pyflink.common import Time
import json
from datetime import datetime

class ParseRideEvent(MapFunction):
    def map(self, value):
        """Parse JSON event and extract city"""
        try:
            data = json.loads(value)
            return (data.get('city', 'unknown'), 1)
        except:
            return ('unknown', 1)

class AggregateRides(KeyedProcessFunction):
    def process_element(self, value, ctx, out):
        """Aggregate rides per city"""
        city, count = value
        # In production, use proper windowing
        out.collect({
            'city': city,
            'count': count,
            'timestamp': datetime.now().isoformat()
        })

def main():
    env = StreamExecutionEnvironment.get_execution_environment()
    
    # Event Hub connection properties
    properties = {
        'bootstrap.servers': f"{os.getenv('EVENTHUB_NAMESPACE')}.servicebus.windows.net:9093",
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'PLAIN',
        'sasl.jaas.config': f"org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$ConnectionString\" password=\"{os.getenv('EVENTHUB_CONNECTION_STRING')}\";"
    }
    
    # Consume from Event Hub
    kafka_source = FlinkKafkaConsumer(
        topics='rides',
        deserialization_schema=SimpleStringSchema(),
        properties=properties
    )
    
    ride_stream = env.add_source(kafka_source)
    
    # Parse and aggregate
    parsed = ride_stream.map(ParseRideEvent())
    
    # Window by 1 minute and aggregate
    aggregated = parsed \
        .key_by(lambda x: x[0]) \
        .window(TumblingProcessingTimeWindows.of(Time.minutes(1))) \
        .sum(1)
    
    # Write to Cosmos DB (implement custom sink)
    aggregated.add_sink(CosmosDBSink())
    
    env.execute("Ride Analytics Job")

if __name__ == '__main__':
    main()

