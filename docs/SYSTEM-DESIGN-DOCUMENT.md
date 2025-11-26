# System Design Document - Ride Booking Platform

**Multi-Cloud Microservices Architecture for Real-Time Ride Booking and Analytics**

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Cloud Deployment Architecture](#2-cloud-deployment-architecture)
3. [Microservices Architecture](#3-microservices-architecture)
4. [Microservice Responsibilities](#4-microservice-responsibilities)
5. [Interconnection Mechanisms](#5-interconnection-mechanisms)
6. [Design Rationale](#6-design-rationale)
7. [Architecture Diagrams](#7-architecture-diagrams)

---

## 1. System Overview

### 1.1 Purpose

The Ride Booking Platform is a cloud-native, multi-cloud microservices application designed to demonstrate modern cloud computing principles. The system enables users to book rides, manages driver profiles, processes payments, and provides real-time analytics on ride patterns across different cities.

### 1.2 Key Characteristics

- **Multi-Cloud Architecture**: Spans AWS (primary) and GCP (analytics)
- **Microservices-Based**: 6 independent, loosely coupled services
- **Real-Time Processing**: Stream processing for analytics using Apache Flink
- **Auto-Scaling**: Kubernetes HPA for dynamic resource management
- **Infrastructure as Code**: Complete Terraform-based provisioning
- **GitOps**: ArgoCD for continuous deployment
- **Observability**: Prometheus, Grafana, and Loki for monitoring

### 1.3 Technology Stack

| Layer | Technology |
|-------|-----------|
| **Application Framework** | FastAPI (Python 3.10+) |
| **Frontend** | Next.js 14 (TypeScript, React) |
| **Container Orchestration** | Kubernetes (AWS EKS) |
| **Primary Database** | PostgreSQL (AWS RDS) |
| **Analytics Database** | Firestore (GCP NoSQL) |
| **Message Broker** | Google Cloud Pub/Sub |
| **Stream Processing** | Apache Flink (Python) |
| **Compute Platform** | Google Dataproc |
| **Serverless** | AWS Lambda |
| **Infrastructure as Code** | Terraform |
| **GitOps** | ArgoCD |
| **Monitoring** | Prometheus + Grafana |
| **Load Testing** | k6 |

---

## 2. Cloud Deployment Architecture

### 2.1 Multi-Cloud Strategy

The system employs a **hybrid multi-cloud architecture** with clear separation of concerns:

- **AWS (Provider A)**: Primary infrastructure for application services, transactional data, and serverless functions
- **GCP (Provider B)**: Analytics and stream processing workloads

### 2.2 AWS Infrastructure Components

![AWS Infrastructure Architecture](diagrams/01-aws-infrastructure.png)

**Key AWS Services:**
- **EKS Cluster**: Kubernetes 1.28, 2-10 nodes (t3.medium)
- **RDS PostgreSQL**: db.t3.micro, 20GB storage, encrypted
- **Lambda**: Python 3.11, 128MB memory, 30s timeout
- **API Gateway**: REST API for Lambda invocation
- **S3**: Object storage for artifacts and state
- **VPC**: Public/private subnets, NAT Gateway

### 2.3 GCP Infrastructure Components

![GCP Infrastructure Architecture](diagrams/02-gcp-infrastructure.png)

**Key GCP Services:**
- **Dataproc**: Managed Hadoop/Spark cluster, Flink 1.18.1
- **Pub/Sub**: Managed message broker for event streaming
- **Firestore**: NoSQL document database for analytics
- **Cloud Storage**: Object storage for Dataproc artifacts
- **Cloud NAT**: Network address translation for outbound traffic

### 2.4 Cross-Cloud Communication

![Cross-Cloud Communication Flow](diagrams/03-cross-cloud-communication.png)

**Communication Patterns:**
1. **Synchronous HTTP**: Service-to-service calls within EKS (Kubernetes DNS)
2. **Asynchronous Pub/Sub**: Cross-cloud event streaming (AWS → GCP)
3. **REST API**: Frontend to backend services (port-forwarded)
4. **Database Queries**: Direct connections to RDS and Firestore

---

## 3. Microservices Architecture

### 3.1 Service Decomposition

The system is decomposed into **6 microservices**, each with a single, well-defined responsibility:

![Microservices Architecture](diagrams/04-microservices-architecture.png)

### 3.2 Service Communication Matrix

| From Service | To Service | Protocol | Pattern | Purpose |
|--------------|------------|----------|---------|---------|
| Frontend | User Service | HTTP/REST | Request-Response | User registration, login |
| Frontend | Driver Service | HTTP/REST | Request-Response | Driver profile management |
| Frontend | Ride Service | HTTP/REST | Request-Response | Book ride, view rides |
| Ride Service | Payment Service | HTTP/REST | Synchronous | Process payment |
| Ride Service | Lambda | HTTP/REST | Asynchronous | Send notification |
| Ride Service | Pub/Sub | Pub/Sub SDK | Asynchronous | Publish ride event |
| Analytics | Pub/Sub | Pub/Sub SDK | Pull | Consume ride events |
| Analytics | Firestore | Firestore SDK | Write | Store aggregated data |
| Ride Service | Firestore | Firestore SDK | Read | Query analytics |
| All Services | RDS | PostgreSQL | Direct Connection | CRUD operations |

---

## 4. Microservice Responsibilities

### 4.1 User Service

**Location**: AWS EKS (Kubernetes)  
**Port**: 8001  
**Technology**: FastAPI (Python)

**Responsibilities:**
- User registration and authentication
- User profile management (CRUD operations)
- City management (list cities, add cities)
- Session management
- User data validation

**Database Schema:**
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    city VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Key Endpoints:**
- `POST /users/register` - Register new user
- `POST /users/login` - Authenticate user
- `GET /users/{user_id}` - Get user profile
- `GET /cities` - List all cities

**Dependencies:**
- RDS PostgreSQL (users, cities tables)
- No external service dependencies

---

### 4.2 Driver Service

**Location**: AWS EKS (Kubernetes)  
**Port**: 8002  
**Technology**: FastAPI (Python)

**Responsibilities:**
- Driver profile management
- Driver status management (online/offline)
- Vehicle information management
- Driver availability tracking
- Driver data validation

**Database Schema:**
```sql
CREATE TABLE drivers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    vehicle_type VARCHAR(50),
    vehicle_number VARCHAR(50),
    status VARCHAR(20) DEFAULT 'offline',
    city VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Key Endpoints:**
- `POST /drivers/register` - Register new driver
- `GET /drivers/{driver_id}` - Get driver profile
- `PUT /drivers/{driver_id}/status` - Update driver status
- `GET /drivers/available` - List available drivers

**Dependencies:**
- RDS PostgreSQL (drivers table)
- No external service dependencies

---

### 4.3 Ride Service (Orchestrator)

**Location**: AWS EKS (Kubernetes)  
**Port**: 8003  
**Technology**: FastAPI (Python)  
**HPA**: 2-10 pods, 5% CPU threshold

**Responsibilities:**
- **Primary Orchestrator**: Coordinates ride booking workflow
- Ride creation and management
- Orchestrates payment processing
- Triggers notifications (asynchronous)
- Publishes ride events to Pub/Sub for analytics
- Queries analytics from Firestore
- Ride status management

**Database Schema:**
```sql
CREATE TABLE rides (
    id SERIAL PRIMARY KEY,
    rider_id INTEGER NOT NULL,
    driver_id INTEGER NOT NULL,
    pickup VARCHAR(255) NOT NULL,
    drop_location VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'started',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Key Endpoints:**
- `POST /ride/start` - Create new ride (orchestrates payment, notification, Pub/Sub)
- `GET /ride/all` - List all rides
- `GET /ride/{ride_id}` - Get ride details
- `GET /analytics/latest` - Get latest analytics from Firestore

**Workflow (POST /ride/start):**
1. Store ride in RDS PostgreSQL
2. Call Payment Service (synchronous HTTP)
3. Call Notification Lambda (asynchronous HTTP, can fail)
4. Publish event to Google Pub/Sub (asynchronous, can fail)
5. Return success response

**Dependencies:**
- RDS PostgreSQL (rides table)
- Payment Service (HTTP)
- AWS Lambda via API Gateway (HTTP)
- Google Pub/Sub (SDK)
- Google Firestore (SDK for analytics queries)

---

### 4.4 Payment Service

**Location**: AWS EKS (Kubernetes)  
**Port**: 8004  
**Technology**: FastAPI (Python)

**Responsibilities:**
- Payment processing (dummy implementation for demo)
- Transaction management
- Payment status tracking
- Payment validation

**Database Schema:**
```sql
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    ride_id INTEGER NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING',
    transaction_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Key Endpoints:**
- `POST /payment/process` - Process payment for a ride
- `GET /payment/{payment_id}` - Get payment details
- `GET /payment/ride/{ride_id}` - Get payment for a ride

**Dependencies:**
- RDS PostgreSQL (payments table)
- No external service dependencies

**Note**: This is a dummy payment service for demonstration purposes. In production, it would integrate with payment gateways (Stripe, PayPal, etc.).

---

### 4.5 Notification Service (Lambda)

**Location**: AWS Lambda (Serverless)  
**Trigger**: HTTP via API Gateway  
**Technology**: Python 3.11

**Responsibilities:**
- Asynchronous notification processing
- Logging notifications to CloudWatch
- Ride event notifications
- Can be disabled during load testing

**Function Code:**
```python
def lambda_handler(event, context):
    ride_id = event.get('ride_id')
    city = event.get('city')
    
    # Log notification to CloudWatch
    print(f"Notification: Ride {ride_id} created in {city}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Notification sent')
    }
```

**API Gateway Endpoint:**
- `POST /notify` - Trigger notification

**Dependencies:**
- AWS CloudWatch (logging)
- No database dependencies

**Design Choice**: Lambda is used to demonstrate serverless architecture. Notifications are fire-and-forget, so failures don't affect ride creation.

---

### 4.6 Analytics Service (Flink on Dataproc)

**Location**: Google Dataproc (GCP)  
**Technology**: Apache Flink 1.18.1 (Python)

**Responsibilities:**
- Real-time stream processing
- Consume ride events from Google Pub/Sub
- Aggregate rides by city with time windows (60-second windows)
- Write aggregated results to Firestore
- Publish results to Pub/Sub (optional)

**Processing Logic:**
```python
# Pseudo-code
1. Subscribe to Pub/Sub topic: ride-booking-rides
2. For each message:
   - Extract city from ride event
   - Increment count for that city
3. Every 60 seconds (tumbling window):
   - Flush aggregates to Firestore
   - Document structure: {city, count, timestamp}
   - Clear aggregates for next window
```

**Output Format:**
```json
{
  "city": "Mumbai",
  "count": 45,
  "timestamp": "2024-01-15T10:30:00Z",
  "windowEnd": "2024-01-15T10:30:00Z"
}
```

**Dependencies:**
- Google Pub/Sub (input subscription)
- Google Firestore (output database)
- Google Pub/Sub (optional output topic)

**Design Choice**: Flink is chosen for its low-latency stream processing capabilities and built-in windowing functions. Dataproc provides managed infrastructure, eliminating cluster management overhead.

---

## 5. Interconnection Mechanisms

### 5.1 Synchronous Communication

#### 5.1.1 HTTP/REST (Service-to-Service)

**Pattern**: Request-Response  
**Protocol**: HTTP/1.1  
**Format**: JSON

**Use Cases:**
- Frontend → Backend Services
- Ride Service → Payment Service
- Ride Service → Notification Lambda (via API Gateway)

**Example:**
```python
# Ride Service calling Payment Service
async with httpx.AsyncClient() as client:
    response = await client.post(
        "http://payment-service:8004/payment/process",
        json={"ride_id": ride_id, "amount": 100.0},
        timeout=5.0
    )
```

**Service Discovery:**
- Within Kubernetes: Kubernetes DNS (`service-name.namespace.svc.cluster.local`)
- External: Environment variables or ConfigMaps

**Error Handling:**
- Timeout: 5 seconds
- Retry: Not implemented (fail-fast for demo)
- Fallback: Continue ride creation even if payment fails (demo mode)

---

#### 5.1.2 Database Connections

**Pattern**: Direct Connection  
**Protocol**: PostgreSQL wire protocol

**Use Cases:**
- All services → RDS PostgreSQL
- Ride Service → Firestore (for analytics queries)

**Connection Pooling:**
- Each service maintains its own connection pool
- Connection string from Kubernetes Secrets

**Example:**
```python
# RDS Connection
conn = psycopg2.connect(
    host=DB_HOST,  # From Secret
    database=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD,
    port=DB_PORT
)
```

---

### 5.2 Asynchronous Communication

#### 5.2.1 Google Cloud Pub/Sub

**Pattern**: Publish-Subscribe  
**Protocol**: gRPC/HTTP (Pub/Sub SDK)

**Use Cases:**
- Ride Service → Pub/Sub (publish ride events)
- Analytics Service → Pub/Sub (consume ride events)

**Topics:**
- `ride-booking-rides`: Input topic for ride events
- `ride-booking-ride-results`: Output topic for aggregated results (optional)

**Subscription:**
- `ride-booking-rides-flink`: Pull subscription for Analytics Service

**Message Format:**
```json
{
  "ride_id": 123,
  "rider_id": 1,
  "driver_id": 2,
  "pickup": "Location A",
  "drop": "Location B",
  "city": "Mumbai",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**Publishing (Ride Service):**
```python
# Initialize publisher
publisher = pubsub_v1.PublisherClient(credentials=credentials)
topic_path = publisher.topic_path(project_id, topic_name)

# Publish message
future = publisher.publish(
    topic_path,
    json.dumps(ride_data).encode("utf-8"),
    city=ride_data.get("city", "unknown")
)
future.result(timeout=10)  # Wait for publish
```

**Consuming (Analytics Service):**
```python
# Initialize subscriber
subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(project_id, subscription_name)

# Pull messages
flow_control = pubsub_v1.types.FlowControl(max_messages=10)
with subscriber:
    streaming_pull_future = subscriber.subscribe(
        subscription_path,
        callback=process_message,
        flow_control=flow_control
    )
    streaming_pull_future.result()
```

**Design Rationale:**
- **Decoupling**: Ride Service doesn't wait for analytics processing
- **Scalability**: Pub/Sub handles high throughput
- **Reliability**: At-least-once delivery guarantee
- **Cross-Cloud**: Enables AWS → GCP communication

---

#### 5.2.2 Firestore (NoSQL Database)

**Pattern**: Document Store  
**Protocol**: Firestore REST API / gRPC

**Use Cases:**
- Analytics Service → Firestore (write aggregated data)
- Ride Service → Firestore (read analytics for frontend)

**Database Structure:**
```
Database: ride-booking-analytics
Collection: ride_analytics
Documents:
  - Document ID: {city}-{timestamp}
  - Fields:
    - city: string
    - count: int
    - timestamp: string
    - windowEnd: string
```

**Writing (Analytics Service):**
```python
db = firestore.Client(project=project_id, database='ride-booking-analytics')
doc_ref = db.collection('ride_analytics').document(f"{city}-{timestamp}")
doc_ref.set({
    'city': city,
    'count': count,
    'timestamp': timestamp,
    'windowEnd': windowEnd
})
```

**Reading (Ride Service):**
```python
db = firestore.Client(project=project_id, database='ride-booking-analytics')
docs = list(db.collection('ride_analytics').stream())

# Aggregate by city
city_aggregates = defaultdict(int)
for doc in docs:
    data = doc.to_dict()
    city_aggregates[data['city']] += data['count']
```

**Design Rationale:**
- **NoSQL**: Flexible schema for analytics data
- **Real-Time**: Low-latency reads for dashboard
- **Scalability**: Handles high write throughput
- **GCP Native**: Seamless integration with Dataproc

---

### 5.3 Service Discovery

#### 5.3.1 Kubernetes DNS

**Pattern**: DNS-based service discovery  
**Format**: `{service-name}.{namespace}.svc.cluster.local`

**Example:**
```python
PAYMENT_SERVICE_URL = "http://payment-service:8004"
# Resolves to: payment-service.default.svc.cluster.local
```

**Benefits:**
- Automatic service discovery
- Load balancing via Kubernetes Service
- No external service registry needed

---

#### 5.3.2 Environment Variables / ConfigMaps

**Pattern**: Configuration-based service URLs

**Example:**
```yaml
# Kubernetes Deployment
env:
  - name: PAYMENT_SERVICE_URL
    value: "http://payment-service:80"
  - name: LAMBDA_API_URL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: lambda_api_url
```

---

### 5.4 Authentication & Authorization

#### 5.4.1 GCP Service Account

**Pattern**: Service Account JSON credentials  
**Storage**: Kubernetes Secrets (base64 encoded)

**Use Cases:**
- Ride Service → Pub/Sub (publisher credentials)
- Analytics Service → Pub/Sub (subscriber credentials)
- Services → Firestore (read/write credentials)

**Implementation:**
```python
# Decode credentials from Secret
credentials_json = base64.b64decode(PUBSUB_CREDENTIALS_B64).decode("utf-8")
credentials_info = json.loads(credentials_json)
credentials = service_account.Credentials.from_service_account_info(credentials_info)

# Use credentials
publisher = pubsub_v1.PublisherClient(credentials=credentials)
```

---

#### 5.4.2 RDS Credentials

**Pattern**: Username/Password  
**Storage**: Kubernetes Secrets

**Implementation:**
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: password
```

---

## 6. Design Rationale

This section documents the thought process, discussions, and reasoning behind each major architectural decision. We'll walk through how we arrived at each choice, what alternatives we considered, and why we ultimately chose the path we did.

---

### 6.1 Multi-Cloud Architecture

**Decision**: Use AWS for primary infrastructure and GCP for analytics.

**The Journey to This Decision:**

When we first started designing this system, the requirement was clear: demonstrate multi-cloud capabilities. But the question was: *how do we split the workload between two cloud providers in a way that makes sense?*

Initially, we considered splitting by microservices - some services on AWS, some on GCP. However, this approach seemed artificial. We asked ourselves: "What if we split by *purpose* instead of by service?"

**Key Realization:**

We realized that our system naturally had two distinct workloads:
1. **Transactional workloads** - User management, ride booking, payments (needs strong consistency, ACID transactions)
2. **Analytical workloads** - Real-time stream processing, aggregations (needs high throughput, eventual consistency)

AWS has excellent managed Kubernetes (EKS) and relational databases (RDS) - perfect for our transactional needs. GCP has Dataproc with built-in Flink support and excellent analytics tools - perfect for our stream processing needs.

**Why This Split Works:**

1. **Requirement Compliance**: This wasn't just checking a box. We genuinely needed to show that we could build a system that spans multiple clouds, which is increasingly common in enterprise environments.

2. **Best-of-Breed Approach**: Instead of forcing everything into one cloud, we chose the best tool for each job. AWS EKS is mature and well-integrated with other AWS services. GCP Dataproc makes running Flink clusters trivial - no need to manage Hadoop ourselves.

3. **Cost Optimization**: By using each provider's strengths, we avoid paying for features we don't need. AWS for compute-intensive transactional work, GCP for analytics that benefit from their data processing infrastructure.

4. **Vendor Lock-in Mitigation**: This is a real concern in production. By not putting all our eggs in one basket, we maintain flexibility. If AWS raises prices, we can migrate transactional services. If GCP changes their analytics offerings, we can adapt.

5. **Learning Objective**: More importantly, this demonstrates real-world patterns. Many companies use AWS for production workloads and GCP for data analytics. This architecture reflects industry practices.

**What We Learned Along the Way:**

The biggest challenge was cross-cloud communication. We initially thought about using VPNs or direct network connections, but that's complex and expensive. Then we discovered Pub/Sub - it's designed exactly for this use case. It handles authentication, retries, and scaling automatically. This solution significantly simplified our architecture.

**Trade-offs We Accepted:**

- **Complexity**: Yes, managing two cloud providers is more complex. But the benefits outweigh the costs, especially for a system that needs to demonstrate multi-cloud capabilities.

- **Latency**: Cross-cloud communication does add latency (typically 50-100ms). But since we're using asynchronous Pub/Sub, this doesn't affect user experience. The ride booking completes immediately; analytics happen in the background.

- **Cost**: There are data transfer costs between clouds, but at our demo scale, this is negligible. In production, you'd optimize based on actual usage patterns.

**The Bottom Line:**

This wasn't just about meeting a requirement - it was about building a system that makes architectural sense. The split between transactional and analytical workloads is natural, and using the best tool for each job results in a better system overall.

---

### 6.2 Microservices Architecture

**Decision**: Decompose system into 6 independent microservices.

**The Evolution of Our Thinking:**

We started with a simple question: "Should this be a monolith or microservices?" For a demo project, a monolith would be simpler. But we had requirements to meet: 6 microservices, independent scaling, different communication patterns.

**The "Domain-Driven Design" Approach:**

Instead of arbitrarily splitting services, we looked at the business domain. What are the natural boundaries?

- **User Management** → User Service (makes sense - it's a distinct domain)
- **Driver Management** → Driver Service (different from users, different lifecycle)
- **Ride Orchestration** → Ride Service (this is the core business logic)
- **Payment Processing** → Payment Service (financial transactions are separate)
- **Notifications** → Lambda (event-driven, doesn't need to be always-on)
- **Analytics** → Flink Job (completely different paradigm - stream processing)

Each of these has different:
- **Scaling needs**: Ride Service gets hammered during peak hours, User Service is steady
- **Update frequency**: Payment logic changes often, User Service rarely
- **Failure tolerance**: If notifications fail, rides still work. If payments fail, rides can't proceed.

**Why This Works:**

1. **Separation of Concerns**: This isn't just a buzzword. When we need to change payment logic, we only touch Payment Service. When we need to add driver features, we only touch Driver Service. This reduces cognitive load and makes the codebase more maintainable.

2. **Independent Scaling**: This is huge. During a flash sale or marketing campaign, Ride Service might get 10x traffic, but User Service stays normal. With microservices, we can scale Ride Service to 10 pods while keeping User Service at 2 pods. In a monolith, we'd have to scale everything, wasting resources.

3. **Technology Flexibility**: We chose FastAPI for all services for consistency, but we *could* use different technologies. For example, if we needed real-time features, we could rewrite Ride Service in Go for better performance. The microservices architecture allows this without rewriting everything.

4. **Fault Isolation**: This saved us during development. When Payment Service had a bug, rides still got created (we just logged the error). In a monolith, one bug could bring down the entire system.

5. **Team Autonomy**: In a real organization, different teams can own different services. The Payment team can deploy Payment Service without coordinating with the User team. This enables parallel development and faster iteration.

**The Challenges We Faced:**

- **Network Overhead**: Every service call adds latency. A ride booking that would take 50ms in a monolith now takes 200ms because of multiple service calls. We mitigated this by:
  - Using async calls where possible (Lambda, Pub/Sub)
  - Keeping synchronous calls to a minimum (only Payment Service)
  - Using connection pooling and efficient serialization

- **Operational Complexity**: 6 services means 6 deployments, 6 monitoring dashboards, 6 sets of logs. We solved this with:
  - GitOps (ArgoCD) - one Git push deploys everything
  - Unified monitoring (Prometheus/Grafana) - one dashboard for all services
  - Consistent logging format across services

- **Data Consistency**: This is the hardest part. In a monolith, transactions are easy. In microservices, we can't have distributed transactions (they're too slow and complex). So we:
  - Use eventual consistency (rides get created even if notifications fail)
  - Implement idempotency (retrying doesn't cause duplicates)
  - Use sagas pattern for complex workflows (though we kept it simple for the demo)

**What We'd Do Differently:**

If we were building this for production, we'd add:
- Service mesh (Istio) for better observability and security
- API Gateway (Kong or AWS API Gateway) for rate limiting and authentication
- Event sourcing for better audit trails
- Circuit breakers for better resilience

But for a demo, our current architecture strikes the right balance between complexity and functionality.

**The Bottom Line:**

Microservices aren't always the answer, but for this project, they made sense. The natural domain boundaries, different scaling needs, and requirement to demonstrate distributed systems all pointed to microservices. Yes, it's more complex, but the benefits - independent scaling, fault isolation, team autonomy - are worth it.

---

### 6.3 Kubernetes (EKS) for Container Orchestration

**Decision**: Use AWS EKS for deploying microservices.

**The Container Orchestration Dilemma:**

When we decided on microservices, the next question was: "How do we run them?" We had several options, each with trade-offs.

**Why Not Just EC2?**

We could have deployed each service on separate EC2 instances. Simple, straightforward. But then:
- Manual scaling (spin up new instances, configure load balancers)
- No service discovery (requires hardcoded IPs or manual DNS configuration)
- Manual health checks and restarts
- No resource optimization (each instance runs one service, wasting resources)

This would work, but it's 2010-era thinking. We wanted something more modern.

**Why Not ECS?**

AWS ECS (Elastic Container Service) was tempting. It's AWS-native, integrates well with other AWS services, and is simpler than Kubernetes. But:
- Less flexible (AWS-specific, harder to migrate)
- Smaller ecosystem (fewer tools, less community support)
- Less portable (can't easily move to GCP or Azure)

We considered it, but Kubernetes proved to be the better long-term choice.

**Why Not Lambda?**

Lambda is great for event-driven, stateless functions. But our services:
- Need to be always-on (users expect sub-second response times)
- Have stateful connections (database connection pools)
- Need persistent storage (for caching, sessions)

Lambda would require a complete redesign. Not worth it.

**Why Kubernetes (EKS)?**

1. **Industry Standard**: This matters more than you'd think. When we hire developers, they know Kubernetes. When we look for solutions, there are Kubernetes-native tools for everything. When we need help, the community is huge. It's like choosing SQL over a proprietary database - the ecosystem matters.

2. **Auto-Scaling**: This was a requirement, and Kubernetes HPA (Horizontal Pod Autoscaler) is battle-tested. We set a CPU threshold (5%), and Kubernetes automatically adds/removes pods. During load testing, we observed pods scaling from 2 to 10 in minutes, demonstrating the effectiveness of the auto-scaling mechanism.

3. **Service Discovery**: Kubernetes DNS provides efficient service discovery. Services can find each other by name (`http://payment-service:8004`). No hardcoded IPs, no manual DNS configuration. This simplifies inter-service communication.

4. **Resource Management**: Kubernetes is smart about resource allocation. If Ride Service needs more CPU, it can take it from underutilized services. This means we can run more services on fewer nodes, saving money.

5. **GitOps Support**: ArgoCD (our GitOps tool) is built for Kubernetes. It watches our Git repo and automatically syncs changes. This makes deployments trivial - push to Git, ArgoCD deploys. No manual `kubectl apply` commands.

**The Learning Curve:**

Kubernetes has a steep learning curve. We spent time understanding:
- Pods vs Deployments vs Services
- ConfigMaps and Secrets
- Ingress and Service types
- Resource requests and limits

But once we got it, everything clicked. The abstractions make sense, and the tooling is excellent.

**What We Learned:**

- Start simple: We began with basic Deployments and Services, then added HPA, then ConfigMaps, then Secrets. Don't try to learn everything at once.

- Use managed services: EKS handles the control plane (the hard part). We just manage the worker nodes, which is much simpler.

- Monitor everything: Kubernetes gives you metrics for free (via Metrics Server). Use them to tune your resource requests and HPA thresholds.

**The Bottom Line:**

Kubernetes initially seemed like overkill, but it paid off. The auto-scaling, service discovery, and GitOps integration significantly simplified operations. Additionally, it's a valuable skill - Kubernetes is widely used in the industry. Learning it was worth the investment.

---

### 6.4 PostgreSQL (RDS) for Primary Database

**Decision**: Use AWS RDS PostgreSQL for transactional data.

**The Database Decision: SQL vs NoSQL**

This was one of the first decisions we made, and it shaped everything else. We needed to store: users, drivers, rides, and payments. The question was: SQL or NoSQL?

**Why Not DynamoDB?**

DynamoDB is AWS's managed NoSQL database. It's fast, scalable, and serverless. We seriously considered it. But:
- **No joins**: We need to query "all rides for user X" - in DynamoDB, this requires denormalization or multiple queries
- **Eventual consistency**: For payments, we need strong consistency. DynamoDB's eventual consistency could lead to race conditions
- **Cost**: DynamoDB charges per read/write. For our demo with many queries, it would be expensive

DynamoDB is great for high-throughput, simple queries. But our data has relationships (users have rides, rides have payments), and we need transactions. SQL is the right choice.

**Why Not Aurora?**

Aurora is AWS's "next-generation" database. It's faster, more scalable, and has better high availability. But:
- **Cost**: Aurora is 2-3x more expensive than RDS. For a demo, that's overkill
- **Complexity**: Aurora has more features (serverless, multi-master) that we don't need
- **Lock-in**: Aurora is more AWS-specific than standard PostgreSQL

If this were production with high traffic, we'd consider Aurora. But for a demo, RDS PostgreSQL is perfect.

**Why Not Self-Managed PostgreSQL?**

We could run PostgreSQL on EC2. It would be cheaper and give us more control. But:
- **Operational overhead**: We'd need to handle backups, patching, monitoring, failover
- **Time**: Setting up and maintaining a database takes time away from building features
- **Risk**: If we misconfigure backups or security, we could lose data

RDS handles all of this. It's worth the extra cost.

**Why PostgreSQL Specifically?**

We chose PostgreSQL over MySQL because:
- **Better JSON support**: We store some semi-structured data (like ride metadata)
- **Better concurrency**: PostgreSQL handles concurrent writes better
- **Rich feature set**: Window functions, full-text search, extensions
- **Open source**: No licensing concerns

**Why RDS (Managed Service)?**

1. **ACID Compliance**: This is non-negotiable for financial transactions. When we process a payment, we need to ensure it's recorded exactly once. PostgreSQL's transactions guarantee this.

2. **Relational Model**: Our data has natural relationships. Users have rides. Rides have payments. The relational model (with foreign keys and joins) makes this easy to query and maintain.

3. **Managed Service**: RDS handles:
   - Automated backups (daily snapshots, point-in-time recovery)
   - Patching (security updates applied automatically)
   - High availability (multi-AZ deployment with automatic failover)
   - Monitoring (CloudWatch integration)

   We just configure it and use it. No database administration needed.

4. **Mature Ecosystem**: PostgreSQL has been around for 30+ years. There are libraries for every language, tools for every use case, and a huge community. When we hit issues, solutions are easy to find.

5. **Cost-Effective**: db.t3.micro costs ~$15/month. For a demo, that's nothing. In production, we'd scale up as needed.

**What We Learned:**

- **Connection pooling**: Each service maintains a connection pool. We started with 10 connections per service, but that was too many for db.t3.micro (max 87 connections). We tuned it down to 5 per service.

- **Indexing**: We added indexes on foreign keys (rider_id, driver_id) and frequently queried columns (email, status). This made queries 10x faster.

- **Backups**: RDS creates daily snapshots. We tested restoring from a snapshot - it worked perfectly. Peace of mind.

**The Bottom Line:**

PostgreSQL on RDS was the obvious choice. It's reliable, well-understood, and perfect for transactional data. The managed service aspect saved us countless hours. We could focus on building features instead of managing databases.

---

### 6.5 Firestore (GCP) for Analytics Storage

**Decision**: Use Firestore for storing aggregated analytics data.

**The Analytics Storage Challenge:**

We had a unique requirement: store aggregated analytics data (ride counts by city) that gets updated every 60 seconds by Flink, and queried in real-time by the frontend dashboard. This is different from our transactional data.

**Why Not BigQuery?**

BigQuery is GCP's data warehouse. It's designed for analytics - columnar storage, SQL queries, petabyte scale. We considered it. But:
- **Latency**: BigQuery is optimized for batch queries, not real-time. Queries can take seconds, which is too slow for a dashboard that updates every 30 seconds
- **Cost**: BigQuery charges per query and data scanned. For frequent dashboard queries, this adds up
- **Overkill**: We're storing simple aggregations (city → count), not complex analytics

BigQuery is amazing for data warehousing and complex analytics. But for a real-time dashboard with simple data, it's overkill.

**Why Not Cloud SQL (PostgreSQL)?**

We could have used another PostgreSQL database. It would be consistent with our transactional database. But:
- **Schema rigidity**: Analytics requirements change. We might want to add new dimensions (time of day, weather, etc.). With SQL, this requires schema migrations
- **Write throughput**: Flink writes aggregated results every 60 seconds. With multiple cities, that's many writes. PostgreSQL can handle it, but Firestore is optimized for high write throughput
- **Real-time queries**: Firestore has built-in real-time listeners. When data changes, clients get notified automatically. This is perfect for dashboards

**Why Not MongoDB?**

MongoDB is a popular NoSQL database. We could self-host it or use MongoDB Atlas. But:
- **Self-hosting**: Operational overhead (backups, scaling, monitoring)
- **MongoDB Atlas**: Adds another cloud provider (we're already using AWS and GCP)
- **Integration**: Firestore integrates seamlessly with other GCP services (Dataproc, Pub/Sub)

**Why Firestore?**

1. **NoSQL Flexibility**: Our analytics schema is simple now (city, count, timestamp), but it might evolve. With Firestore, we can add fields without migrations. If we want to track "rides by hour" or "rides by weather condition", we just add the field. No schema changes needed.

2. **Real-Time Queries**: This was the killer feature. Firestore has real-time listeners - when data changes, the client gets notified. We could have used this for the frontend (instead of polling every 30 seconds), but we kept it simple for the demo. Still, the low-latency reads (<100ms) make the dashboard feel instant.

3. **GCP Native**: Since our analytics pipeline is on GCP (Dataproc, Pub/Sub), using Firestore keeps everything in one ecosystem. Authentication, networking, and monitoring all work together seamlessly.

4. **Scalability**: Firestore is designed for high write throughput. Flink writes aggregated results every 60 seconds. With 10 cities, that's 10 writes per minute. Firestore can handle thousands of writes per second, so we're nowhere near the limit.

5. **Serverless**: No infrastructure to manage. No servers, no scaling configuration, no backups to configure. Firestore handles everything. We just write and read data.

**The Trade-offs:**

- **Eventual consistency**: Firestore is eventually consistent. If we write data and immediately read it, we might not see it. But for analytics (which are aggregated over 60-second windows), this is fine. The data is "eventually" consistent within seconds, which is acceptable.

- **Query limitations**: Firestore queries are simpler than SQL. Complex joins aren't possible. But for our use case (aggregate by city), this is fine. We do the aggregation in Flink, then store simple documents.

- **Cost**: Firestore charges per read/write. For our demo scale, it's negligible. In production, we'd optimize by batching reads and using caching.

**What We Learned:**

- **Document structure**: We store one document per city per time window. Document ID: `{city}-{timestamp}`. This makes queries fast (direct document lookup) and avoids complex queries.

- **TTL**: We set a TTL (time-to-live) of 1 hour on documents. Old analytics data gets automatically deleted, keeping the database clean and costs low.

- **Aggregation**: We do aggregation in Flink (not in Firestore). Firestore stores the results. This separation of concerns (compute vs storage) makes the system more maintainable.

**The Bottom Line:**

Firestore was perfect for our analytics use case. The NoSQL flexibility, real-time queries, and GCP integration made it the obvious choice. It's serverless, scalable, and requires zero maintenance. For analytics data that changes frequently and needs to be queried in real-time, Firestore is ideal.

---

### 6.6 Google Cloud Pub/Sub for Event Streaming

**Decision**: Use Pub/Sub for cross-cloud event streaming.

**The Cross-Cloud Communication Problem:**

This was the hardest architectural challenge. We have services on AWS (Ride Service) that need to send events to services on GCP (Analytics Flink). How do we connect them?

**Initial Ideas (That Didn't Work):**

1. **Direct HTTP calls**: Ride Service could call Flink directly via HTTP. But:
   - Flink is on a private network (Dataproc VMs)
   - We'd need VPNs or public IPs (security risk)
   - Synchronous calls would slow down ride booking
   - If Flink is down, rides fail (unacceptable)

2. **AWS SQS → GCP**: We could use AWS SQS, but GCP services can't easily consume from it. We'd need a bridge service, adding complexity.

3. **Database polling**: Flink could poll RDS for new rides. But:
   - Polling is inefficient (wastes resources)
   - Adds load to the database
   - Introduces latency (polling interval)

**The Message Queue Solution:**

We needed a message queue - a system that decouples producers (Ride Service) from consumers (Flink). The producer sends a message and forgets about it. The consumer processes messages when ready.

**Why Not Self-Hosted Kafka?**

Kafka is the industry standard for event streaming. We could run it on EC2 or EKS. But:
- **Operational overhead**: Kafka is complex. We'd need to manage:
  - Zookeeper (or KRaft)
  - Brokers (multiple for high availability)
  - Topics, partitions, replication
  - Monitoring, alerting, backups
- **Cross-cloud complexity**: Running Kafka on AWS and consuming from GCP would require VPNs or public endpoints
- **Time**: Setting up and maintaining Kafka would take days

For a demo, this is too much work.

**Why Not Confluent Cloud (Managed Kafka)?**

Confluent Cloud is managed Kafka. It handles the operational complexity. But:
- **Cost**: Confluent Cloud is expensive (~$1/hour for basic cluster)
- **Complexity**: Kafka has a steep learning curve (topics, partitions, consumer groups, offsets)
- **Overkill**: We don't need Kafka's advanced features (exactly-once semantics, stream processing, etc.)

Kafka is powerful, but for simple pub/sub, it's overkill.

**Why Not AWS SQS/SNS?**

AWS SQS (Simple Queue Service) and SNS (Simple Notification Service) are AWS-native. But:
- **GCP integration**: GCP services can't easily consume from SQS. We'd need a bridge service running on AWS that forwards messages to GCP
- **Features**: SQS is simpler than Pub/Sub (no topics, just queues), but less flexible
- **Multi-cloud**: Using AWS services for cross-cloud communication defeats the purpose

**Why Pub/Sub?**

1. **Managed Service**: This is a significant advantage. Pub/Sub is fully managed - no servers, no configuration, no maintenance. We create a topic, publish messages, and consume them. The setup is straightforward.

2. **Cross-Cloud**: This was the key requirement. Pub/Sub is a GCP service, but it has SDKs for all languages and can be accessed from anywhere (with proper authentication). Ride Service (on AWS) publishes to Pub/Sub (on GCP) using the Python SDK. This enables seamless cross-cloud communication.

3. **Scalability**: Pub/Sub handles millions of messages per second. We're sending maybe 100 messages per minute. It scales automatically - no configuration needed.

4. **Reliability**: Pub/Sub guarantees at-least-once delivery. Messages are stored until acknowledged. If Flink crashes, messages aren't lost. When Flink restarts, it continues from where it left off.

5. **Cost-Effective**: Pub/Sub charges per message ($0.40 per million messages). For our demo, this is essentially free. Even at production scale (millions of rides), it's affordable.

**The Authentication Challenge:**

The tricky part was authentication. Ride Service (on AWS) needs to publish to Pub/Sub (on GCP). We solved this with:
- **Service Account**: Created a GCP service account with Pub/Sub Publisher role
- **Credentials**: Stored the service account JSON key in Kubernetes Secrets (base64 encoded)
- **SDK**: Ride Service decodes the credentials and uses them to authenticate with Pub/Sub

This works, but it's not ideal (storing credentials in Kubernetes). In production, we'd use Workload Identity or similar.

**What We Learned:**

- **Message format**: We use JSON. Simple, human-readable, easy to debug. We include all ride data (ride_id, city, timestamp) so Flink has everything it needs.

- **Error handling**: Pub/Sub publishing can fail (network issues, authentication problems). We catch exceptions and log them, but don't fail the ride booking. Analytics are nice-to-have, not critical.

- **Subscription model**: We use pull subscriptions (Flink pulls messages) instead of push (Pub/Sub pushes to an endpoint). Pull gives us more control over processing rate and error handling.

**The Bottom Line:**

Pub/Sub was the perfect solution for cross-cloud event streaming. It's managed, scalable, reliable, and cost-effective. The authentication setup was a bit complex, but once configured, it operates seamlessly. For connecting AWS and GCP services, Pub/Sub is the way to go.

---

### 6.7 Apache Flink on Dataproc for Stream Processing

**Decision**: Use Apache Flink on Google Dataproc for real-time analytics.

**The Stream Processing Requirement:**

We needed to process ride events in real-time and aggregate them by city in 60-second windows. This is classic stream processing - continuous data flowing in, aggregations computed on-the-fly.

**Why Not Spark Streaming?**

Spark Streaming was our first consideration. It's mature, well-documented, and widely used. But:
- **Micro-batch model**: Spark Streaming processes data in small batches (typically 1-5 seconds). This adds latency. Flink processes events one-by-one, giving sub-second latency.
- **Batch-oriented**: Spark is fundamentally a batch processing engine. Streaming is an add-on. Flink is built from the ground up for streaming.
- **Complexity**: Spark's API is more complex. Flink's windowing API is simpler and more intuitive.

For real-time analytics with low latency, Flink is the better choice.

**Why Not Kafka Streams?**

Kafka Streams is a library for building stream processing applications. It's lightweight and integrates well with Kafka. But:
- **Kafka dependency**: We'd need to run Kafka (or use Confluent Cloud), adding complexity and cost
- **Limited features**: Kafka Streams is simpler than Flink. For complex windowing and aggregations, Flink is more powerful
- **Ecosystem**: Flink has a larger ecosystem and more resources

**Why Not Cloud Dataflow?**

Cloud Dataflow is GCP's managed stream processing service. It's based on Apache Beam. But:
- **Less control**: Dataflow abstracts away the infrastructure. We wanted to see and control the Flink cluster
- **Learning curve**: Beam's programming model is different from Flink. We'd need to learn a new API
- **Cost**: Dataflow charges per processing unit. For our demo, Dataproc is more cost-effective

**Why Flink?**

1. **Low Latency**: This was critical. Flink processes events as they arrive, not in batches. This means our analytics dashboard shows data within seconds of a ride being booked, not minutes. The difference is noticeable - the dashboard feels "live" rather than "near real-time."

2. **Windowing**: Flink's windowing API is well-designed and intuitive. We can define tumbling windows (60 seconds), sliding windows, or session windows with just a few lines of code. The windowing logic is built-in and optimized. We don't have to implement it ourselves.

3. **Managed Infrastructure**: Dataproc makes running Flink trivial. We create a cluster with a few Terraform commands. Dataproc handles:
   - VM provisioning
   - Flink installation
   - Network configuration
   - Monitoring

   We just write the Flink job and submit it. No cluster management headaches.

4. **Python Support**: PyFlink lets us write Flink jobs in Python. This is huge - Python is easier to write and debug than Java/Scala. The performance is slightly worse, but for our use case (simple aggregations), it's fine.

5. **Scalability**: Flink scales horizontally. If we need more processing power, we add more worker nodes. Flink automatically redistributes the workload. No code changes needed.

**The Implementation Journey:**

We started with a simple Flink job:
1. Subscribe to Pub/Sub
2. Extract city from each ride event
3. Count rides per city
4. Every 60 seconds, write results to Firestore

Simple, right? But we hit challenges:

- **Pub/Sub integration**: Flink doesn't have native Pub/Sub connector. We had to write a custom source function using the Pub/Sub Python SDK. This took time, but it works.

- **Windowing**: Getting the windowing right was tricky. We needed tumbling windows (non-overlapping 60-second windows). Flink's API made this easy once we understood it.

- **Error handling**: What if Pub/Sub is down? What if Firestore is down? We added retry logic and error handling. Failed writes don't crash the job.

**What We Learned:**

- **Checkpointing**: Flink's checkpointing ensures exactly-once processing. If the job crashes, it resumes from the last checkpoint. This is crucial for production systems.

- **Backpressure**: If Firestore is slow, Flink automatically slows down message consumption. This prevents memory issues. Flink handles this automatically - we didn't need to configure anything.

- **Monitoring**: Flink exposes metrics (number of events processed, latency, etc.). We integrated these with Prometheus for monitoring.

**The Bottom Line:**

Flink on Dataproc was the perfect choice for real-time stream processing. The low latency, built-in windowing, and managed infrastructure made it ideal. The Python support made development easier. Yes, there was a learning curve, but Flink's power and flexibility made it worth it.

---

### 6.8 AWS Lambda for Notifications

**Decision**: Use AWS Lambda for notification service.

**The Notification Service Dilemma:**

We needed a service to send notifications when rides are created. The question was: should this be a microservice in EKS, or should we use serverless?

**Why Not an EKS Service?**

We could have created a Notification Service microservice and deployed it to EKS alongside the others. It would be consistent with our architecture. But:
- **Resource waste**: Notifications are infrequent (maybe 100 per minute). A service running 24/7 would waste resources (CPU, memory) most of the time
- **Scaling complexity**: We'd need to configure HPA or keep it at minimum replicas. Lambda scales automatically to zero when not in use
- **Operational overhead**: Another service to deploy, monitor, and maintain

For a service that's called occasionally and doesn't need to be always-on, Lambda is perfect.

**Why Not SNS/SQS?**

AWS SNS (Simple Notification Service) and SQS (Simple Queue Service) are simpler than Lambda. We could publish to SNS, which triggers SQS, which triggers... what? We'd still need something to process the messages. Lambda fills that gap.

SNS/SQS + Lambda is a common pattern, but for our use case (simple HTTP-triggered notifications), API Gateway + Lambda is simpler.

**Why Lambda?**

1. **Serverless**: This is the key benefit. No servers to manage. No containers to deploy. No scaling to configure. We write a function, deploy it, and it operates automatically. When a notification is needed, Lambda runs the function. When it's not needed, Lambda doesn't cost anything.

2. **Cost-Effective**: Lambda charges per invocation ($0.20 per million requests) and compute time ($0.0000166667 per GB-second). For our demo (maybe 100 notifications per minute), this is essentially free. Even at production scale, it's cheaper than running a service 24/7.

3. **Auto-Scaling**: Lambda provides seamless auto-scaling. If we get a sudden spike (1000 notifications in a minute), Lambda automatically spins up more instances. No configuration needed. This ensures consistent performance under varying load.

4. **Requirement Compliance**: We needed to demonstrate serverless architecture. Lambda is the industry standard for serverless computing. It serves as an ideal example.

5. **Event-Driven**: Notifications are inherently event-driven. A ride is created (event) → send notification (action). Lambda fits this pattern perfectly.

**The Implementation:**

Our Lambda function is simple:
```python
def lambda_handler(event, context):
    ride_id = event.get('ride_id')
    city = event.get('city')
    print(f"Notification: Ride {ride_id} created in {city}")
    return {'statusCode': 200, 'body': 'Notification sent'}
```

The implementation is concise - just 5 lines of code. In a real system, this would send emails, SMS, or push notifications. For the demo, we log to CloudWatch.

**The API Gateway Integration:**

Lambda needs a way to be invoked. We use API Gateway, which provides an HTTP endpoint. Ride Service calls this endpoint (asynchronously) when a ride is created. API Gateway forwards the request to Lambda.

The setup was straightforward:
1. Create Lambda function
2. Create API Gateway
3. Connect them
4. Get the API Gateway URL
5. Configure it in Ride Service

Terraform handles all of this automatically.

**What We Learned:**

- **Cold starts**: The first invocation after idle time takes longer (1-2 seconds) because Lambda needs to initialize. Subsequent invocations are fast (<100ms). For notifications (which are async), this is acceptable.

- **Timeout**: Lambda has a maximum execution time (we set it to 30 seconds). For simple notifications, this is plenty. For complex processing, you'd need a different approach.

- **Error handling**: If Lambda fails, it retries automatically (up to 2 times). We also catch errors in Ride Service and log them, but don't fail the ride booking. Notifications are best-effort.

**The Bottom Line:**

Lambda was the perfect choice for notifications. It's serverless, cost-effective, and requires zero infrastructure management. The API Gateway integration makes it easy to call from other services. For event-driven, infrequent workloads, Lambda is ideal.

---

### 6.9 Horizontal Pod Autoscaling (HPA)

**Decision**: Configure HPA for Ride Service with 5% CPU threshold.

**The Scaling Challenge:**

Ride Service is our most critical service - it handles ride bookings, which is the core functionality. During peak hours (lunch time, evening commute), it gets hammered. During off-peak hours (2 AM), it's idle. How do we handle this?

**Option 1: Fixed Replicas**

We could run a fixed number of pods (say, 5) all the time. Simple, predictable. But:
- **Waste**: During off-peak hours, 4 pods are idle, wasting money
- **Insufficient**: During peak hours, 5 pods might not be enough, causing slow responses

This doesn't work.

**Option 2: Manual Scaling**

We could manually scale up before peak hours and scale down after. But:
- **Predictability**: Traffic isn't always predictable. A marketing campaign could cause a sudden spike
- **Operational overhead**: Someone needs to monitor and scale manually
- **Reaction time**: By the time we notice high load and scale, users are already experiencing slowness

This doesn't work either.

**Option 3: Automatic Scaling (HPA)**

Kubernetes HPA (Horizontal Pod Autoscaler) monitors pod metrics and automatically scales based on thresholds. This is what we need.

**Why 5% CPU Threshold?**

This was a controversial decision. Typical HPA configurations use 70-80% CPU threshold. We chose 5%, which is very aggressive. Here's why:

1. **Demo Requirement**: We needed to demonstrate auto-scaling during load testing. With a 70% threshold, we'd need to generate massive load to trigger scaling. With 5%, moderate load triggers scaling, making it visible in the demo.

2. **Cost Optimization**: With 5% threshold, pods scale up quickly when load increases, but also scale down quickly when load decreases. This minimizes cost.

3. **Performance**: Lower threshold means more pods, which means better performance. Requests are distributed across more pods, reducing latency.

**The Trade-offs:**

- **Oscillation**: With such a low threshold, HPA might oscillate (scale up, then immediately scale down). Kubernetes HPA has stabilization windows to prevent this, but it's still a risk. We monitor this during load testing.

- **Warm-up Time**: New pods take 30-60 seconds to start and become ready. During this time, existing pods handle the load. For our use case, this is acceptable.

- **Resource Waste**: More pods mean more resources. But since we scale down quickly, the average resource usage is still lower than fixed replicas.

**The Configuration:**

```yaml
minReplicas: 2    # Always have at least 2 pods for high availability
maxReplicas: 10    # Can scale up to 10 pods during peak load
targetCPUUtilizationPercentage: 5  # Scale when CPU > 5%
```

**What We Observed During Load Testing:**

We ran load tests with k6, generating 50 concurrent users. Here's what happened:

1. **Initial State**: 2 pods running, CPU at 2%
2. **Load Starts**: Requests increase, CPU jumps to 15%
3. **HPA Reacts**: HPA sees CPU > 5%, starts scaling up
4. **Scaling**: Over 2-3 minutes, pods scale from 2 → 4 → 6 → 8
5. **Stabilization**: CPU stabilizes around 8-10% (distributed across 8 pods)
6. **Load Stops**: Requests decrease, CPU drops to 3%
7. **Scale Down**: After 5 minutes (cooldown period), pods scale down to 2

It worked perfectly! The system automatically handled the load without manual intervention.

**What We Learned:**

- **Metrics Server**: HPA needs Metrics Server to collect pod metrics. We had to install it first. Without it, HPA can't see CPU usage.

- **Resource Requests**: Pods need CPU requests defined for HPA to work. We set `requests.cpu: 200m` (0.2 CPU cores). HPA uses this to calculate utilization.

- **Cooldown Periods**: HPA has scale-up and scale-down cooldown periods (default 3 minutes). This prevents rapid oscillation. We kept the defaults.

- **Multiple Metrics**: HPA can scale based on multiple metrics (CPU, memory, custom metrics). We kept it simple with just CPU for the demo.

**The Bottom Line:**

HPA is one of Kubernetes' killer features. It automatically handles scaling based on load, optimizing both performance and cost. The 5% threshold is aggressive for a demo, but it clearly demonstrates the capability. In production, we'd use a higher threshold (50-70%) to reduce oscillation and resource usage.

---

### 6.10 Infrastructure as Code (Terraform)

**Decision**: Use Terraform for all infrastructure provisioning.

**The Infrastructure Management Problem:**

When we started this project, we had a choice: provision infrastructure manually (clicking through AWS/GCP consoles) or use Infrastructure as Code (IaC). This wasn't just a technical decision - it was a philosophical one.

**The Manual Setup Nightmare:**

We could have provisioned everything manually:
1. Create VPC in AWS Console
2. Create EKS cluster
3. Create RDS instance
4. Create Lambda function
5. Repeat for GCP...

But then:
- **Reproducibility**: If we need to recreate the infrastructure (for testing, disaster recovery, or a new environment), we'd have to remember every step, which is error-prone and time-consuming.
- **Version Control**: How do we track changes? Screenshots? Notes? This doesn't scale.
- **Error-Prone**: One misclick, one forgotten setting, and the infrastructure is wrong. Debugging is painful.
- **Time-Consuming**: Clicking through consoles takes forever. And if you make a mistake, you have to start over.

We tried this for 30 minutes and gave up. IaC was the only way.

**Why Not CloudFormation?**

CloudFormation is AWS's native IaC tool. It's powerful and well-integrated with AWS. But:
- **AWS-Only**: CloudFormation only works with AWS. We need to provision GCP resources too. We'd need two tools (CloudFormation + Deployment Manager), which is messy.
- **JSON/YAML**: CloudFormation uses JSON or YAML, which is verbose and hard to read. Terraform uses HCL (HashiCorp Configuration Language), which is more readable.
- **Ecosystem**: Terraform has a larger ecosystem and community. More modules, more examples, more help available.

**Why Not Pulumi?**

Pulumi is a newer IaC tool that lets you write infrastructure code in real programming languages (Python, TypeScript, Go). It's powerful and flexible. But:
- **Maturity**: Pulumi is newer and less mature. Terraform has been around longer and is more battle-tested.
- **Learning Curve**: While Pulumi's programming language approach is appealing, Terraform's HCL is simpler for infrastructure definitions.
- **Ecosystem**: Terraform has more providers, more modules, more examples. The ecosystem is larger.

For a demo project, Terraform's maturity and ecosystem made it the safer choice.

**Why Terraform?**

1. **Reproducibility**: This is huge. We can destroy and recreate the entire infrastructure with two commands: `terraform destroy` and `terraform apply`. This is invaluable for:
   - Testing: Create a test environment, test changes, destroy it
   - Disaster recovery: If production fails, recreate from code
   - New environments: Spin up staging, dev, prod from the same code

2. **Version Control**: All infrastructure changes are in Git. We can see:
   - What changed
   - When it changed
   - Who changed it
   - Why it changed (commit messages)

   This is auditability and documentation rolled into one.

3. **Multi-Cloud**: Terraform has providers for AWS, GCP, Azure, and hundreds of other services. One tool, one language, one workflow. This is perfect for our multi-cloud architecture.

4. **Requirement Compliance**: We needed to demonstrate IaC. Terraform is the industry standard. It's what most companies use. Learning it is valuable.

5. **Documentation**: Terraform code is self-documenting. Looking at `main.tf`, you can see exactly what infrastructure exists. No need to check consoles or read separate documentation.

**The Terraform Structure:**

We organized our Terraform code into modules:
```
infra/
  aws/
    main.tf           # Root module - calls other modules
    modules/
      vpc/            # VPC, subnets, NAT gateways
      eks/            # EKS cluster and node groups
      rds/            # RDS PostgreSQL
      lambda/         # Lambda function
      api_gateway/    # API Gateway
      s3/             # S3 bucket
  gcp/
    main.tf           # Root module
    modules/
      dataproc/       # Dataproc cluster
      pubsub/         # Pub/Sub topics and subscriptions
      firestore/      # Firestore database
      networking/     # Cloud NAT, firewall rules
```

This modular structure makes the code:
- **Reusable**: Modules can be reused across projects
- **Maintainable**: Changes to one module don't affect others
- **Testable**: We can test modules independently

**The Workflow:**

1. **Plan**: `terraform plan` shows what changes will be made. This is like a dry run - no changes are made, but you see what would happen.

2. **Apply**: `terraform apply` makes the changes. Terraform is idempotent - running it multiple times produces the same result. Safe to re-run.

3. **State**: Terraform maintains a state file that tracks what resources exist. This is crucial - Terraform uses it to know what to create, update, or destroy.

**What We Learned:**

- **State Management**: The state file is sensitive (contains resource IDs, sometimes secrets). We store it in S3 with versioning enabled. In production, we'd use Terraform Cloud or similar for remote state with locking.

- **Variables**: We use `terraform.tfvars` for environment-specific values (region, instance sizes, etc.). The actual code stays the same across environments.

- **Outputs**: Terraform outputs are useful for getting resource information (RDS endpoint, Lambda URL, etc.). We use these to configure other parts of the system.

- **Dependencies**: Terraform automatically handles dependencies. If RDS depends on VPC, Terraform creates VPC first. But explicit `depends_on` helps with clarity.

**The Bottom Line:**

Terraform transformed how we think about infrastructure. It's not just a tool - it's a mindset. Infrastructure is code, and code should be version-controlled, tested, and reproducible. The initial setup took time, but it paid off. We can recreate the entire infrastructure in minutes, not hours. That's powerful.

---

### 6.11 GitOps with ArgoCD

**Decision**: Use ArgoCD for GitOps-based deployment.

**The Deployment Problem:**

We have Kubernetes manifests (Deployments, Services, ConfigMaps) in the `gitops/` directory. How do we deploy them to the cluster?

**Option 1: Manual kubectl**

We could use `kubectl apply -f gitops/ride-service-deployment.yaml` for each file. Simple, straightforward. But:
- **Manual Process**: Every deployment requires manual commands. Easy to forget a step.
- **No Audit Trail**: Who deployed what? When? Why? No record.
- **Error-Prone**: Wrong file, wrong namespace, wrong cluster - mistakes are easy.
- **No Automation**: Can't integrate with CI/CD pipelines easily.

This works for one-time setups, but not for ongoing deployments.

**Option 2: Helm**

Helm is a package manager for Kubernetes. We could create Helm charts and deploy them. But:
- **Manual Deployment**: Still need to run `helm install` or `helm upgrade` manually.
- **No Git Integration**: Helm doesn't watch Git. Changes in Git don't automatically deploy.
- **Complexity**: Helm adds another layer (charts, values, templates). For simple deployments, it's overkill.

Helm is great for packaging and distributing applications, but it doesn't solve the GitOps problem.

**Option 3: Flux**

Flux is a GitOps tool similar to ArgoCD. It watches a Git repository and automatically syncs changes to the cluster. We considered it. But:
- **UI**: ArgoCD has a better web UI. Flux is more CLI-focused.
- **Ecosystem**: ArgoCD has more integrations and a larger community.
- **Features**: ArgoCD has more features (multi-cluster, application sets, etc.).

Both are good, but ArgoCD felt more polished.

**Why ArgoCD?**

1. **Git as Source of Truth**: This is the core GitOps principle. Git is the single source of truth. The cluster state should match Git. If they diverge, ArgoCD detects it and fixes it. This eliminates "configuration drift" - the cluster gradually diverging from what's in Git.

2. **Automatic Sync**: ArgoCD watches the Git repository. When we push changes, ArgoCD detects them and automatically deploys. No manual `kubectl apply` needed. This enables:
   - CI/CD integration: CI pipeline pushes to Git, ArgoCD deploys
   - Faster deployments: Push to Git, deployment happens automatically
   - Consistency: Everyone deploys the same way (via Git)

3. **Rollback**: If a deployment breaks, we can rollback by reverting the Git commit. ArgoCD detects the change and rolls back automatically. Or we can use ArgoCD's UI to rollback to a previous version. Easy and safe.

4. **Audit Trail**: Every deployment is tracked in Git. We can see:
   - What was deployed (Git diff)
   - When it was deployed (Git commit timestamp)
   - Who deployed it (Git commit author)
   - Why it was deployed (Git commit message)

   This is invaluable for compliance and debugging.

5. **Requirement Compliance**: We needed to demonstrate GitOps. ArgoCD is the most popular GitOps tool. It's what most companies use. Learning it is valuable.

**The ArgoCD Setup:**

We configure ArgoCD to watch our Git repository:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ride-service
spec:
  source:
    repoURL: https://github.com/our-repo
    path: gitops
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

This tells ArgoCD:
- Watch the `gitops/` directory in our Git repo
- Deploy to the `default` namespace
- Automatically sync when changes are detected
- Prune resources that are removed from Git
- Self-heal (if someone manually changes the cluster, ArgoCD fixes it)

**The Workflow:**

1. **Develop**: We make changes to Kubernetes manifests in the `gitops/` directory
2. **Commit**: We commit and push to Git
3. **ArgoCD Detects**: ArgoCD polls Git (or uses webhooks) and detects changes
4. **Sync**: ArgoCD automatically syncs changes to the cluster
5. **Monitor**: We can watch the sync in ArgoCD's UI

It's that simple. No manual steps.

**What We Learned:**

- **Sync Strategies**: ArgoCD supports different sync strategies (automated, manual, sync waves). We use automated for simplicity, but manual gives more control.

- **Health Checks**: ArgoCD monitors application health (pod status, service endpoints, etc.). If something is unhealthy, ArgoCD shows it in the UI. This is helpful for debugging.

- **Multi-Environment**: ArgoCD can manage multiple environments (dev, staging, prod) from the same Git repo using different paths or branches. We kept it simple with one environment for the demo.

- **RBAC**: ArgoCD has role-based access control. We can restrict who can deploy what. For the demo, we kept it open, but in production, we'd lock it down.

**The Bottom Line:**

ArgoCD transformed our deployment process. No more manual `kubectl apply` commands. No more wondering "what's actually deployed?" (Git shows it). No more configuration drift (ArgoCD fixes it). GitOps is the future, and ArgoCD makes it easy. The UI is a bonus - it's nice to see deployments visually.

---

### 6.12 Observability Stack (Prometheus + Grafana)

**Decision**: Use Prometheus for metrics and Grafana for visualization.

**The Observability Challenge:**

"How do we know if our system is working?" This seems like a simple question, but it's actually complex. We need to monitor:
- **Metrics**: CPU, memory, request rate, error rate
- **Logs**: What's happening in each service
- **Traces**: How requests flow through the system

For this demo, we focused on metrics (the most important for understanding system health).

**Why Not CloudWatch?**

CloudWatch is AWS's native monitoring service. It's integrated with all AWS services. We considered it. But:
- **GCP Integration**: CloudWatch doesn't monitor GCP services well. We'd need separate monitoring for Dataproc, Pub/Sub, Firestore.
- **Cost**: CloudWatch charges for metrics, logs, and dashboards. It adds up.
- **Kubernetes**: CloudWatch's Kubernetes integration is okay, but not as good as Prometheus.

For a multi-cloud system, we needed something cloud-agnostic.

**Why Not Datadog/New Relic?**

Datadog and New Relic are commercial monitoring platforms. They're powerful and feature-rich. But:
- **Cost**: They're expensive ($15-31 per host per month). For a demo with multiple services, this adds up quickly.
- **Vendor Lock-in**: Once you're on Datadog, migrating is hard. Prometheus is open source - you own your data.
- **Complexity**: They have many features we don't need (APM, log management, etc.). Prometheus is simpler and focused.

For a demo, open source is better. For production, commercial tools might make sense, but Prometheus is still a solid choice.

**Why Prometheus + Grafana?**

1. **Industry Standard**: Prometheus is the de-facto standard for Kubernetes metrics. It's what everyone uses. Learning it is valuable. The ecosystem is huge - there are exporters for everything.

2. **Kubernetes Integration**: Prometheus integrates seamlessly with Kubernetes:
   - **Service Discovery**: Automatically discovers pods and services
   - **Metrics Endpoints**: Pods expose metrics at `/metrics`, Prometheus scrapes them
   - **Native Support**: Kubernetes components (kubelet, etc.) expose Prometheus metrics

   This requires minimal configuration and operates seamlessly.

3. **Rich Dashboards**: Grafana is the visualization layer. It provides comprehensive and powerful visualization capabilities. We can create dashboards showing:
   - Pod count over time
   - CPU and memory usage
   - Request rate and latency
   - Error rates

   During load testing, the dashboards provide real-time visibility into system behavior, allowing us to observe how the system responds to load.

4. **Alerting**: Prometheus has built-in alerting. We can set up alerts like "if CPU > 80% for 5 minutes, send notification." We didn't set this up for the demo, but it's there.

5. **Open Source**: This is huge. No vendor lock-in. No per-host pricing. We can run it anywhere. The data is ours.

**The Setup:**

1. **Prometheus**: Deployed to Kubernetes, configured to scrape metrics from all services
2. **Service Monitors**: We use Prometheus Operator's ServiceMonitor CRD to tell Prometheus which services to scrape
3. **Grafana**: Deployed to Kubernetes, connected to Prometheus as a data source
4. **Dashboards**: We created dashboards showing key metrics (pod count, CPU, memory, request rate)

**What We Monitored:**

- **Pod Count**: How many pods are running for each service (especially Ride Service with HPA)
- **CPU Usage**: Per-pod CPU usage (to see HPA scaling in action)
- **Memory Usage**: Per-pod memory usage (to detect memory leaks)
- **Request Rate**: Requests per second to each service
- **Error Rate**: Failed requests (though we didn't have many errors)

**What We Learned:**

- **Metrics Endpoints**: Services need to expose metrics at `/metrics`. FastAPI doesn't do this by default - we'd need to add Prometheus client library. For the demo, we used Kubernetes metrics (CPU, memory) which are available by default.

- **Scraping Interval**: Prometheus scrapes metrics every 15 seconds by default. This is fine for most use cases. For high-frequency metrics, you can reduce it.

- **Retention**: Prometheus stores metrics locally. By default, it keeps 15 days of data. For a demo, this is plenty. For production, you'd use long-term storage (like Thanos or Cortex).

- **Dashboards**: Creating good dashboards takes time. We started simple (pod count, CPU) and added more as needed. The key is showing metrics that matter.

**The Bottom Line:**

Prometheus + Grafana gave us visibility into our system. During load testing, we could see pods scaling, CPU spiking, and requests flowing. This is invaluable for understanding system behavior. The open-source nature means no vendor lock-in and no per-host pricing. It's the right choice for Kubernetes monitoring.

---

## 7. Architecture Diagrams

### 7.1 High-Level System Architecture

![High-Level System Architecture](diagrams/04-microservices-architecture.png)

### 7.2 Data Flow Diagram

![Data Flow Sequence Diagram](diagrams/05-data-flow-sequence.png)

### 7.3 Deployment Architecture

![Deployment Architecture](diagrams/06-deployment-architecture.png)

### 7.4 Scalability Architecture

![Scalability Architecture](diagrams/07-scalability-architecture.png)

---

## Conclusion

This design document provides a comprehensive overview of the Ride Booking Platform's architecture, covering:

1. **System Overview**: Purpose, characteristics, and technology stack
2. **Cloud Deployment Architecture**: Multi-cloud strategy with AWS and GCP
3. **Microservices Architecture**: 6 services with clear responsibilities
4. **Interconnection Mechanisms**: Synchronous HTTP, asynchronous Pub/Sub, and database connections
5. **Design Rationale**: Justification for each architectural decision

The system demonstrates modern cloud-native principles including:
- Multi-cloud deployment
- Microservices architecture
- Infrastructure as Code
- GitOps practices
- Auto-scaling
- Real-time stream processing
- Comprehensive observability

All design choices are justified based on requirements, scalability, cost, and operational considerations.

---

**Document Version**: 1.0  
**Last Updated**: January 2025  
**Author**: System Architecture Team

