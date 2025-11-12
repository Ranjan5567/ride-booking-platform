package com.ridebooking;

import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.flink.api.common.functions.AggregateFunction;

import java.util.Properties;
import java.util.HashMap;
import java.util.Map;

public class RideAnalyticsJob {
    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        
        // Kafka consumer properties (Azure Event Hub)
        Properties kafkaProps = new Properties();
        kafkaProps.setProperty("bootstrap.servers", System.getenv("EVENTHUB_NAMESPACE") + ".servicebus.windows.net:9093");
        kafkaProps.setProperty("security.protocol", "SASL_SSL");
        kafkaProps.setProperty("sasl.mechanism", "PLAIN");
        kafkaProps.setProperty("sasl.jaas.config", 
            "org.apache.kafka.common.security.plain.PlainLoginModule required " +
            "username=\"$ConnectionString\" " +
            "password=\"" + System.getenv("EVENTHUB_CONNECTION_STRING") + "\";");
        
        // Consume from Event Hub
        FlinkKafkaConsumer<String> consumer = new FlinkKafkaConsumer<>(
            "rides",
            new SimpleStringSchema(),
            kafkaProps
        );
        
        DataStream<String> rideStream = env.addSource(consumer);
        
        // Parse JSON and extract city
        DataStream<Tuple2<String, Integer>> cityRides = rideStream
            .map(new MapFunction<String, Tuple2<String, Integer>>() {
                @Override
                public Tuple2<String, Integer> map(String value) throws Exception {
                    // Simple JSON parsing (use proper JSON library in production)
                    String city = extractCity(value);
                    return new Tuple2<>(city, 1);
                }
                
                private String extractCity(String json) {
                    // Extract city from JSON string
                    int cityIndex = json.indexOf("\"city\":\"");
                    if (cityIndex != -1) {
                        int start = cityIndex + 8;
                        int end = json.indexOf("\"", start);
                        return json.substring(start, end);
                    }
                    return "unknown";
                }
            });
        
        // Aggregate rides per city per minute
        DataStream<String> aggregated = cityRides
            .keyBy(0)
            .window(TumblingProcessingTimeWindows.of(Time.minutes(1)))
            .aggregate(new AggregateFunction<Tuple2<String, Integer>, Integer, Integer>() {
                @Override
                public Integer createAccumulator() {
                    return 0;
                }
                
                @Override
                public Integer add(Tuple2<String, Integer> value, Integer accumulator) {
                    return accumulator + value.f1;
                }
                
                @Override
                public Integer getResult(Integer accumulator) {
                    return accumulator;
                }
                
                @Override
                public Integer merge(Integer a, Integer b) {
                    return a + b;
                }
            })
            .map(new MapFunction<Integer, String>() {
                @Override
                public String map(Integer value) throws Exception {
                    return "{\"count\":" + value + "}";
                }
            });
        
        // Write to Cosmos DB (via HTTP sink or custom sink)
        // For demo, we'll use a simple print sink
        aggregated.print();
        
        env.execute("Ride Analytics Job");
    }
}

