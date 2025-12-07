package com.ridebooking;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.windowing.WindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.streaming.api.functions.sink.RichSinkFunction;

import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.FirestoreOptions;
import com.google.cloud.pubsub.v1.Subscriber;
import com.google.pubsub.v1.ProjectSubscriptionName;
import com.google.pubsub.v1.PubsubMessage;
import com.google.cloud.pubsub.v1.AckReplyConsumer;
import org.apache.flink.streaming.api.functions.source.SourceFunction;

import java.io.Serializable;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

public class RideAnalyticsJob {

    public static void main(String[] args) throws Exception {
        final String projectId = getRequiredEnv("PUBSUB_PROJECT_ID");
        final String ridesSubscription = getRequiredEnv("PUBSUB_RIDES_SUBSCRIPTION");
        final String resultsTopic = getRequiredEnv("PUBSUB_RESULTS_TOPIC");
        final String firestoreCollection = System.getenv().getOrDefault("FIRESTORE_COLLECTION", "ride_analytics");

        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // Custom Pub/Sub source function
        DataStream<String> rideStream = env.addSource(new PubSubSourceFunction(projectId, ridesSubscription))
                                           .name("gcp-pubsub-rides");

        DataStream<Tuple2<String, Integer>> cityEvents = rideStream.map(new ExtractCity());

        DataStream<RideAggregate> aggregates = cityEvents
                .keyBy(value -> value.f0)
                .window(TumblingProcessingTimeWindows.of(Time.minutes(1)))
                .apply(new AggregateWindowFunction());

        DataStream<String> aggregateJson = aggregates.map(new AggregateToJson());

        aggregates.addSink(new FirestoreSink(firestoreCollection));

        // TODO: You can add Pub/Sub sink if needed using Google Cloud Pub/Sub client.

        env.execute("Ride Analytics Job (Pub/Sub -> Firestore)");
    }

    private static String getRequiredEnv(String key) {
        String value = System.getenv(key);
        if (value == null || value.isEmpty()) {
            throw new IllegalArgumentException("Missing required environment variable: " + key);
        }
        return value;
    }

    // === Helper classes ===
    static class ExtractCity implements MapFunction<String, Tuple2<String, Integer>> {
        @Override
        public Tuple2<String, Integer> map(String value) {
            String city = "unknown";
            try {
                ObjectMapper mapper = new ObjectMapper();
                Map<?, ?> payload = mapper.readValue(value, Map.class);
                Object cityValue = payload.get("city");
                if (cityValue != null) {
                    city = cityValue.toString();
                }
            } catch (Exception ignored) {}
            return Tuple2.of(city, 1);
        }
    }

    static class AggregateWindowFunction implements WindowFunction<Tuple2<String, Integer>, RideAggregate, String, TimeWindow> {
        @Override
        public void apply(String key, TimeWindow window, Iterable<Tuple2<String, Integer>> input, org.apache.flink.util.Collector<RideAggregate> out) {
            long total = 0L;
            for (Tuple2<String, Integer> tuple : input) {
                total += tuple.f1;
            }

            RideAggregate aggregate = new RideAggregate();
            aggregate.city = key;
            aggregate.count = total;
            aggregate.windowStartEpochMillis = window.getStart();
            aggregate.windowEndEpochMillis = window.getEnd();

            out.collect(aggregate);
        }
    }

    static class AggregateToJson implements MapFunction<RideAggregate, String> {
        private static final ObjectMapper mapper = new ObjectMapper();

        @Override
        public String map(RideAggregate value) throws Exception {
            Map<String, Object> payload = new HashMap<>();
            payload.put("city", value.city);
            payload.put("count", value.count);
            payload.put("windowStart", Instant.ofEpochMilli(value.windowStartEpochMillis).toString());
            payload.put("windowEnd", Instant.ofEpochMilli(value.windowEndEpochMillis).toString());
            return mapper.writeValueAsString(payload);
        }
    }

    static class FirestoreSink extends RichSinkFunction<RideAggregate> {
        private final String collectionName;
        private transient Firestore firestore;

        FirestoreSink(String collectionName) {
            this.collectionName = collectionName;
        }

        @Override
        public void open(Configuration parameters) {
            FirestoreOptions options = FirestoreOptions.getDefaultInstance();
            firestore = options.getService();
        }

        @Override
        public void invoke(RideAggregate value, Context context) throws Exception {
            if (firestore == null || value == null) {
                return;
            }
            String docId = value.city + "-" + value.windowStartEpochMillis;
            firestore.collection(collectionName).document(docId).set(value.toMap()).get();
        }
    }

    static class RideAggregate implements Serializable {
        String city;
        long count;
        long windowStartEpochMillis;
        long windowEndEpochMillis;

        Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("city", city);
            map.put("count", count);
            map.put("windowStart", Instant.ofEpochMilli(windowStartEpochMillis).toString());
            map.put("windowEnd", Instant.ofEpochMilli(windowEndEpochMillis).toString());
            map.put("ttlSeconds", 3600);
            return map;
        }
    }

    // === Custom Pub/Sub SourceFunction to avoid ambiguity ===
    static class PubSubSourceFunction implements SourceFunction<String> {
        private final String projectId;
        private final String subscriptionId;
        private transient Subscriber subscriber;
        private volatile boolean running = true;

        public PubSubSourceFunction(String projectId, String subscriptionId) {
            this.projectId = projectId;
            this.subscriptionId = subscriptionId;
        }

        @Override
        public void run(SourceContext<String> ctx) {
            ProjectSubscriptionName subName = ProjectSubscriptionName.of(projectId, subscriptionId);

            com.google.cloud.pubsub.v1.MessageReceiver receiver = (PubsubMessage message, AckReplyConsumer consumer) -> {
                ctx.collect(message.getData().toStringUtf8());
                consumer.ack();
            };

            subscriber = Subscriber.newBuilder(subName, receiver).build();
            subscriber.startAsync().awaitRunning();

            while (running) {
                try {
                    Thread.sleep(100);
                } catch (InterruptedException ignored) {}
            }
        }

        @Override
        public void cancel() {
            running = false;
            if (subscriber != null) subscriber.stopAsync();
        }
    }
}
