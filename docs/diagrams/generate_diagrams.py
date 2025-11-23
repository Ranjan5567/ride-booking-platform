"""
Script to generate architecture diagrams as images
Requires: pip install matplotlib pillow graphviz
"""
import os
from pathlib import Path

# Create diagrams directory
diagrams_dir = Path(__file__).parent
diagrams_dir.mkdir(exist_ok=True)

print("Creating Mermaid diagram files...")
print("You can render these using:")
print("1. Mermaid Live Editor: https://mermaid.live")
print("2. VS Code Mermaid extension")
print("3. GitHub (renders automatically in .md files)")
print("\nGenerating diagram files...")

# Diagram 1: AWS Infrastructure
aws_infra = """graph TB
    subgraph AWS["AWS Cloud (Primary)"]
        subgraph EKS["Amazon EKS (Kubernetes Cluster)"]
            US[User Service<br/>Port 8001]
            DS[Driver Service<br/>Port 8002]
            RS[Ride Service<br/>Port 8003<br/>HPA: 2-10 pods]
            PS[Payment Service<br/>Port 8004]
        end
        
        RDS[(RDS PostgreSQL<br/>users, drivers<br/>rides, payments)]
        LAMBDA[Lambda + API Gateway<br/>Notification Service]
        S3[(S3 Bucket<br/>Object Storage)]
        
        EKS --> RDS
        RS --> LAMBDA
    end
    
    style AWS fill:#FF9900,stroke:#232F3E,stroke-width:3px
    style EKS fill:#F58536,stroke:#232F3E,stroke-width:2px
    style RS fill:#FF6B6B,stroke:#232F3E,stroke-width:2px
"""

# Diagram 2: GCP Infrastructure
gcp_infra = """graph TB
    subgraph GCP["GCP Cloud (Analytics)"]
        subgraph DATAPROC["Google Dataproc Cluster"]
            MASTER[Master Node<br/>Apache Flink<br/>Analytics Processor]
            WORKER1[Worker Node 1]
            WORKER2[Worker Node 2]
        end
        
        PUBSUB[Google Cloud Pub/Sub<br/>ride-booking-rides<br/>ride-booking-ride-results]
        FIRESTORE[(Firestore NoSQL<br/>ride-booking-analytics<br/>ride_analytics collection)]
        STORAGE[(Cloud Storage<br/>Dataproc Staging)]
        
        DATAPROC --> PUBSUB
        DATAPROC --> FIRESTORE
        DATAPROC --> STORAGE
    end
    
    style GCP fill:#4285F4,stroke:#1A73E8,stroke-width:3px
    style DATAPROC fill:#34A853,stroke:#1A73E8,stroke-width:2px
    style FIRESTORE fill:#EA4335,stroke:#1A73E8,stroke-width:2px
"""

# Diagram 3: Cross-Cloud Communication
cross_cloud = """graph LR
    RS[Ride Service<br/>AWS EKS] -->|Publishes events<br/>Pub/Sub SDK| PUBSUB[Google Pub/Sub<br/>GCP]
    PUBSUB -->|Consumes messages<br/>Pull subscription| FLINK[Analytics Job<br/>GCP Dataproc]
    FLINK -->|Writes aggregated data<br/>Firestore SDK| FIRESTORE[Firestore<br/>GCP]
    FIRESTORE -->|Queries analytics<br/>Firestore REST API| RS2[Ride Service<br/>AWS EKS<br/>/analytics/latest]
    RS2 -->|HTTP Response| FRONTEND[Frontend<br/>Next.js]
    
    style RS fill:#FF9900,stroke:#232F3E
    style RS2 fill:#FF9900,stroke:#232F3E
    style PUBSUB fill:#4285F4,stroke:#1A73E8
    style FLINK fill:#4285F4,stroke:#1A73E8
    style FIRESTORE fill:#4285F4,stroke:#1A73E8
    style FRONTEND fill:#61DAFB,stroke:#20232A
"""

# Diagram 4: Microservices Architecture
microservices = """graph TB
    FRONTEND[Frontend Next.js<br/>localhost:3000<br/>/auth /book /rides /analytics] -->|HTTP/REST| US[User Service<br/>Port 8001]
    FRONTEND -->|HTTP/REST| DS[Driver Service<br/>Port 8002]
    FRONTEND -->|HTTP/REST| RS[Ride Service<br/>Port 8003<br/>Orchestrator]
    
    US --> RDS1[(RDS DB<br/>users)]
    DS --> RDS2[(RDS DB<br/>drivers)]
    RS --> RDS3[(RDS DB<br/>rides)]
    
    RS -->|HTTP| PS[Payment Service<br/>Port 8004]
    PS --> RDS4[(RDS DB<br/>payments)]
    
    RS -->|HTTP| LAMBDA[Notification Lambda<br/>AWS]
    RS -->|Pub/Sub SDK| PUBSUB[Google Pub/Sub<br/>GCP]
    PUBSUB -->|Pull| ANALYTICS[Analytics Job<br/>Dataproc Flink]
    ANALYTICS --> FIRESTORE[(Firestore<br/>GCP)]
    RS -->|Read| FIRESTORE
    
    style RS fill:#FF6B6B,stroke:#232F3E,stroke-width:3px
    style LAMBDA fill:#FF9900,stroke:#232F3E
    style PUBSUB fill:#4285F4,stroke:#1A73E8
    style ANALYTICS fill:#4285F4,stroke:#1A73E8
    style FIRESTORE fill:#EA4335,stroke:#1A73E8
"""

# Diagram 5: Data Flow
data_flow = """sequenceDiagram
    participant User
    participant Frontend
    participant RS as Ride Service
    participant RDS as RDS PostgreSQL
    participant PS as Payment Service
    participant Lambda
    participant PubSub as Google Pub/Sub
    participant Flink as Analytics (Flink)
    participant Firestore
    
    User->>Frontend: 1. POST /ride/start
    Frontend->>RS: POST /ride/start
    RS->>RDS: 2. INSERT INTO rides
    RS->>PS: 3. POST /payment/process
    PS->>RDS: INSERT INTO payments
    RS->>Lambda: 4. POST /notify (async)
    RS->>PubSub: 5. Publish ride event
    PubSub->>Flink: 6. Pull messages
    Flink->>Flink: 7. Aggregate by city (60s window)
    Flink->>Firestore: 8. Write aggregated data
    User->>Frontend: 9. GET /analytics
    Frontend->>RS: GET /analytics/latest
    RS->>Firestore: Query analytics
    Firestore-->>RS: Return data
    RS-->>Frontend: HTTP Response
    Frontend-->>User: Display chart
"""

# Diagram 6: Deployment Architecture
deployment = """graph TB
    subgraph TERRAFORM["Terraform (IaC)"]
        AWS_MODULE[AWS Module<br/>VPC, EKS, RDS<br/>Lambda, API Gateway]
        GCP_MODULE[GCP Module<br/>Dataproc, Pub/Sub<br/>Firestore, Storage]
    end
    
    AWS_MODULE -->|terraform apply| AWS_RESOURCES[AWS Resources<br/>EKS Cluster<br/>RDS Instance<br/>Lambda Function]
    GCP_MODULE -->|terraform apply| GCP_RESOURCES[GCP Resources<br/>Dataproc<br/>Pub/Sub Topics<br/>Firestore DB]
    
    AWS_RESOURCES --> K8S[Kubernetes EKS]
    GCP_RESOURCES --> K8S
    
    subgraph K8S
        ARGOCD[ArgoCD GitOps<br/>Monitors Git repo<br/>Auto-deploys changes]
        APPS[Application Services<br/>User Service<br/>Driver Service<br/>Ride Service HPA<br/>Payment Service]
        MONITORING[Monitoring Stack<br/>Prometheus<br/>Grafana<br/>Loki]
    end
    
    ARGOCD -->|Deploys from Git| APPS
    
    style TERRAFORM fill:#7C3AED,stroke:#5B21B6,stroke-width:2px
    style AWS_MODULE fill:#FF9900,stroke:#232F3E
    style GCP_MODULE fill:#4285F4,stroke:#1A73E8
    style ARGOCD fill:#EF4444,stroke:#DC2626,stroke-width:2px
"""

# Diagram 7: Scalability Architecture
scalability = """graph TB
    LB[Load Balancer<br/>Kubernetes Service] -->|Distributes load| POD1[Ride Service Pod 1<br/>2 CPU]
    LB -->|Distributes load| POD2[Ride Service Pod 2<br/>2 CPU]
    LB -->|Distributes load| PODN[Ride Service Pod N<br/>2 CPU]
    
    POD1 --> HPA[HPA Controller<br/>Metrics Server<br/>Monitors CPU<br/>Target: 5%]
    POD2 --> HPA
    PODN --> HPA
    
    HPA -->|If CPU > 5%| SCALEUP[Scale Up<br/>Add Pods]
    HPA -->|If CPU < 5%| SCALEDOWN[Scale Down<br/>Remove Pods]
    
    SCALEUP --> PODN
    SCALEDOWN --> POD1
    
    style HPA fill:#10B981,stroke:#059669,stroke-width:3px
    style SCALEUP fill:#3B82F6,stroke:#2563EB
    style SCALEDOWN fill:#EF4444,stroke:#DC2626
"""

# Write all diagrams to files
diagrams = {
    "01-aws-infrastructure.mmd": aws_infra,
    "02-gcp-infrastructure.mmd": gcp_infra,
    "03-cross-cloud-communication.mmd": cross_cloud,
    "04-microservices-architecture.mmd": microservices,
    "05-data-flow-sequence.mmd": data_flow,
    "06-deployment-architecture.mmd": deployment,
    "07-scalability-architecture.mmd": scalability,
}

for filename, content in diagrams.items():
    filepath = diagrams_dir / filename
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✓ Created {filename}")

print(f"\n✓ All diagrams created in: {diagrams_dir}")
print("\nTo convert to images:")
print("1. Use Mermaid Live Editor: https://mermaid.live (paste content, export as PNG)")
print("2. Use VS Code with Mermaid extension")
print("3. Use command line: npm install -g @mermaid-js/mermaid-cli && mmdc -i diagram.mmd -o diagram.png")

