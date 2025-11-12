# Architecture Documentation

## System Architecture Overview

The Ride Booking Platform is a multi-cloud, microservices-based system designed to demonstrate cloud-native patterns and practices.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Frontend (Next.js)                   │
│              /auth, /book, /rides, /analytics               │
└──────────────────────┬──────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud (Primary)                       │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ User Service │  │Driver Service│  │Ride Service │      │
│  │  (FastAPI)   │  │  (FastAPI)   │  │  (FastAPI)  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                  │              │
│         └─────────────────┴──────────────────┘              │
│                            │                                 │
│                            ▼                                 │
│                  ┌──────────────────┐                        │
│                  │  RDS PostgreSQL  │                        │
│                  │  (Users, Drivers,│                        │
│                  │   Rides, Cities) │                        │
│                  └──────────────────┘                        │
│                                                              │
│  ┌──────────────┐                                           │
│  │Payment Service│                                          │
│  │  (FastAPI)    │                                          │
│  └──────┬───────┘                                           │
│         │                                                    │
│  ┌──────▼───────┐  ┌──────────────┐                         │
│  │Ride Service  │─▶│Lambda (Notif)│                         │
│  │              │  │  + API GW    │                         │
│  └──────┬───────┘  └──────────────┘                         │
│         │                                                    │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │   S3 Bucket  │                                           │
│  │  (Optional)  │                                           │
│  └──────────────┘                                           │
│                                                              │
│  ┌──────────────────────────────────────────┐              │
│  │  Observability Stack                      │              │
│  │  - Prometheus (Metrics)                   │              │
│  │  - Grafana (Dashboards)                   │              │
│  │  - Loki (Logs)                            │              │
│  └──────────────────────────────────────────┘              │
│                                                              │
│  ┌──────────────────────────────────────────┐              │
│  │  GitOps (ArgoCD)                         │              │
│  │  - Auto-sync deployments                 │              │
│  └──────────────────────────────────────────┘              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ Event Publishing
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   Azure Cloud (Secondary)                    │
│                                                              │
│  ┌──────────────────────────────────────────┐              │
│  │  Azure Event Hub (Kafka-compatible)      │              │
│  │  Topic: rides                            │              │
│  └──────────────┬───────────────────────────┘              │
│                 │                                            │
│                 ▼                                            │
│  ┌──────────────────────────────────────────┐              │
│  │  HDInsight Flink Cluster                 │              │
│  │  - Stream Processing                     │              │
│  │  - Aggregates rides per city per minute  │              │
│  └──────────────┬───────────────────────────┘              │
│                 │                                            │
│                 ▼                                            │
│  ┌──────────────────────────────────────────┐              │
│  │  Cosmos DB (MongoDB API)                 │              │
│  │  - Analytics results storage             │              │
│  │  - Collection: ride_analytics            │              │
│  └──────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Frontend (Next.js)

**Pages:**
- `/auth` - User registration and login
- `/book` - Book a new ride
- `/rides` - View all rides
- `/analytics` - Analytics dashboard with charts

**Technology Stack:**
- Next.js 14
- React 18
- Tailwind CSS
- Recharts for visualization
- Axios for API calls

### 2. User Service

**Responsibilities:**
- User registration (riders and drivers)
- User authentication (mock)
- City management
- User profile retrieval

**Database Schema:**
```sql
users (
  id, name, email, password, user_type, city, created_at
)

cities (
  id, name, created_at
)
```

**Endpoints:**
- `POST /user/register` - Register new user
- `POST /user/login` - Login user
- `GET /user/{id}` - Get user details

### 3. Driver Service

**Responsibilities:**
- Driver profile creation
- Driver status management (online/offline)
- Vehicle information storage

**Database Schema:**
```sql
drivers (
  id, user_id, vehicle_number, vehicle_type, 
  license_number, status, created_at
)
```

**Endpoints:**
- `POST /driver/create` - Create driver profile
- `PUT /driver/status` - Update driver status
- `GET /driver/{id}` - Get driver details

### 4. Ride Service (Main Orchestrator)

**Responsibilities:**
- Ride creation and management
- Orchestrates payment processing
- Triggers notifications
- Publishes events to Azure Event Hub
- Primary target for HPA scaling

**Flow:**
1. Receive ride request
2. Store in RDS
3. Call Payment Service
4. Call Notification Lambda
5. Publish event to Event Hub
6. Return response

**Database Schema:**
```sql
rides (
  id, rider_id, driver_id, pickup, drop_location, 
  city, status, created_at
)
```

**Endpoints:**
- `POST /ride/start` - Start a new ride
- `GET /ride/all` - Get all rides
- `GET /ride/{id}` - Get ride details

### 5. Payment Service

**Responsibilities:**
- Dummy payment processing
- Always returns SUCCESS status
- Instant response

**Endpoints:**
- `POST /payment/process` - Process payment

### 6. Notification Service (AWS Lambda)

**Responsibilities:**
- HTTP-triggered via API Gateway
- Logs ride notifications to CloudWatch
- Can be disabled during load testing

**Trigger:** API Gateway POST /notify

**Payload:**
```json
{
  "ride_id": 123,
  "city": "Bangalore"
}
```

### 7. Analytics Service (Azure Flink)

**Responsibilities:**
- Consumes events from Event Hub
- Aggregates rides per city per minute
- Writes results to Cosmos DB

**Processing Logic:**
- Window: 1 minute tumbling windows
- Key: city
- Aggregation: count of rides

**Output Format:**
```json
{
  "city": "Bangalore",
  "count": 45,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Data Flow

### Ride Booking Flow

1. User logs in via Frontend → User Service
2. User books ride via Frontend → Ride Service
3. Ride Service:
   - Stores ride in RDS
   - Calls Payment Service (synchronous)
   - Calls Lambda via API Gateway (async, can fail)
   - Publishes event to Event Hub (async, can fail)
4. Returns success response to Frontend

### Analytics Flow

1. Event Hub receives ride events
2. Flink job consumes events
3. Flink aggregates by city per minute
4. Results written to Cosmos DB
5. Frontend queries analytics endpoint
6. Analytics displayed in dashboard

## Infrastructure Components

### AWS EKS

- **Cluster Version:** 1.28
- **Node Group:** t3.medium instances
- **Scaling:** 2-10 nodes
- **Services:** All 4 microservices deployed

### AWS RDS

- **Engine:** PostgreSQL 15.4
- **Instance:** db.t3.micro
- **Storage:** 20GB encrypted
- **Network:** Private subnets only

### AWS Lambda

- **Runtime:** Python 3.11
- **Trigger:** API Gateway HTTP
- **Timeout:** 30 seconds
- **Memory:** 128MB

### Azure Event Hub

- **Tier:** Standard
- **Topic:** rides
- **Partitions:** 2
- **Retention:** 1 day

### Azure HDInsight Flink

- **Version:** 4.0
- **Flink Version:** 1.17.0
- **Head Node:** Standard_D4s_v3
- **Worker Nodes:** 2x Standard_D4s_v3

### Azure Cosmos DB

- **API:** MongoDB
- **Database:** analytics
- **Collection:** ride_analytics
- **Shard Key:** city

## Observability

### Prometheus

- Scrapes pod metrics every 15 seconds
- Targets: All microservices
- Metrics: CPU, memory, HTTP requests

### Grafana

- Dashboards:
  - CPU Usage per Service
  - HPA Pod Scaling
  - Request Rate
  - Error Rate

### Loki

- Log aggregation from all pods
- Queryable via Grafana

## Autoscaling (HPA)

### Ride Service HPA

- **Min Replicas:** 2
- **Max Replicas:** 10
- **Metric:** CPU utilization
- **Target:** 70%
- **Scale Up:** When CPU > 70% for 1 minute
- **Scale Down:** When CPU < 70% for 5 minutes

### User Service HPA

- **Min Replicas:** 2
- **Max Replicas:** 10
- **Metric:** CPU utilization
- **Target:** 70%

## Security Considerations

1. **Database:** Private subnets, no public access
2. **Secrets:** Kubernetes secrets for credentials
3. **Network:** VPC with private/public subnets
4. **IAM:** Least privilege roles for services
5. **Encryption:** RDS encryption at rest, S3 encryption

## Scalability

- **Horizontal Scaling:** HPA for Ride and User services
- **Database:** Can upgrade RDS instance type
- **Event Processing:** Flink can scale workers
- **Storage:** Cosmos DB auto-scales

## High Availability

- **Multi-AZ:** RDS in multiple availability zones
- **EKS:** Nodes across multiple AZs
- **Event Hub:** Standard tier with redundancy
- **Cosmos DB:** Multi-region capable

## Cost Optimization

- **Instance Types:** t3.micro for RDS, t3.medium for EKS
- **Auto-scaling:** Scale down during low traffic
- **Reserved Instances:** Can be used for production
- **S3 Lifecycle:** Can configure for cost savings

