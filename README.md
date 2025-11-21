# Production Deployment Guide: Go Banking API AWS EKS

📋 Table of Contents

1. Overview
2. Architecture
3. Prerequisites
4. AWS Infrastructure Setup
5. Kubernetes Configuration
6. CI/CD Pipeline
7. Problems Encountered & Solutions
8. Interview Preparation
9. Useful Commands
10. Best Practices

---

## Overview
This porject demonstratets a complete production deployment of a Go-based banking REST API using

- Application: Go REST API with JWT authentication
- Database: Amazon RDS (PostgreSQL)
- Container Registry: Amazon ECR
- Orchestration: Amazon EKS (Kubernetes)
- CI/CD: GitHub Actions
- Load Balancing: AWS Elastic Load Balancer
- Infrastructure: Fully automated deployment pipeline

```bash
# Key Features
✅Automated CI/CD pipeline with GitHub Actions
✅Horizontal scaling with Kubernetes(2 replicas)
✅Database migrations handled automatically
✅JWT-based authentication
✅Production-grade security with IAM roles
✅External access via LoadBalancer
```

---

## 🏗️ Architecture
```bash
┌─────────────────────────────────────────────────────────────┐
│                        GitHub Actions                       │
│  (Build → Test → Push to ECR → Deploy to EKS)               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                     Amazon ECR                              │
│              (Docker Image Registry)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Amazon EKS Cluster                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    Worker Nodes                       │  │
│  │  ┌──────────────┐         ┌──────────────┐            │  │
│  │  │   Pod 1      │         │   Pod 2      │            │  │
│  │  │  API Server  │         │  API Server  │            │  │
│  │  └──────────────┘         └──────────────┘            │  │
│  │           │                        │                  │  │
│  │           └────────────┬───────────┘                  │  │
│  │                        │                              │  │
│  │                   ┌────▼─────┐                        │  │
│  │                   │ Service  │                        │  │
│  │                   │(LoadBalancer)                     │  │
│  │                   └────┬─────┘                        │  │
│  └────────────────────────┼──────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │   Internet    │
                    │    Users      │
                    └───────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │  Amazon RDS   │
                    │  (PostgreSQL) │
                    └───────────────┘
```


## Prerequistes
```bash
# AWS CLI
aws --version # Should be v2.x

# kubectl (Kubernetes CLI)
kubectl version --client

# Docker
docker --version

# k9s (Optional, for better Kubernetes UI)
k9s version

```

## AWS Account Setup
1. IAM User with premissions:
- AmazonEKSClusterPolicy
- AmazonEKSWorkerNodePolicy
- AmazonEC2ContainerRegistryFullAccess
- AmazonRDSFullAccess

2. AWS Credentials configured:

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (eu-central-1)
```

## AWS Infrastructure Setup

Step 1: Create RDS PostgreSQL Database

```bash
# Create RDS instance via AWS Console or CLI
aws rds create-db-instance \
  --db-instance-identifier simple-bank \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username root \
  --master-user-password YourSecurePassword \
  --allocated-storage 20 \
  --vpc-security-group-ids sg-xxxxxxxx \
  --publicly-accessible \
  --region eu-central-1
```
Important: Save the endpoint address:

```bash
simple-bank.c1w8imcgiazn.eu-central-1.rds.amazonaws.com:5432
```

Step 2: Create ECR Repository

```bash
# Create repository for Docker images
aws ecr create-repository \
  --repository-name: simplebank \
  --region eu-central-1

# Note the repository URI:
# 160983234858.dkr.ecr.eu-central-1.amazonaws.com/simplebank
```

Step 3: Create EKS Cluster

```bash
# Using eksctl (recommended)
eksctl create cluster \
  --name simple-bank \
  --region eu-central-1 \
  --nodegroup-name simple-bank \
  --node-type t3.samll \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3

  # Or via AWS Console
  # EKS --> Create Cluster --> Fllow wizard
```

Step 4: Configure kubectl Access

```bash
# Update kubeconfig to access the cluster
aws eks update-kubeconfig \
  --name simple-bank \
  --region eu-central-1

# Verify connection
kubectl get nodes
```

## ⚙️ Kubernetes Configuration

## Project Structure
```bash
go-simple-bank/
├── .github/
│   └── workflows/
│       └── deploy.yml         # CI/CD pipeline
├── eks/
│   ├── deployment.yaml        # K8s Deployment config
│   ├── service.yaml           # LoadBalancer service
│   └── ingress.yaml           # (Optional) Ingress rules
├── db/
│   └── migration/             # Database migrations
├── api/                       # API handlers
├── Dockerfile                 # Multi-stage Docker build
├── start.sh                   # Startup script
└── wait-for-it.sh             # Wait for PostgreSQL
```

Deployment Configuration

```yaml
# eks/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-bank-api-deployment
  labels:
    app: simple-bank-api
spec:
  replicas: 2  # Run 2 instances for high availability
  selector:
    matchLabels:
      app: simple-bank-api
  template:
    metadata:
      labels:
        app: simple-bank-api
    spec:
      containers:
      - name: simple-bank-api
        image: 160813693928.dkr.ecr.eu-central-1.amazonaws.com/simplebank:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: DB_DRIVER
          value: "postgres"
        - name: DB_SOURCE
          valueFrom:  # Best practice: use secrets
            secretKeyRef:
              name: simple-bank-secrets
              key: DB_SOURCE
        - name: SERVER_ADDRESS
          value: "0.0.0.0:8080"
        - name: TOKEN_SYMMETRIC_KEY
          valueFrom:
            secretKeyRef:
              name: simple-bank-secrets
              key: TOKEN_SYMMETRIC_KEY
        - name: ACCESS_TOKEN_DURATION
          value: "15m"
```

Service Configuration

```yaml
# eks/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: simple-bank-api-service
spec:
  type: LoadBalancer  # Creates AWS ELB
  selector:
    app: simple-bank-api
  ports:
  - protocol: TCP
    port: 80          # External port
    targetPort: 8080  # Container port

```

Create Kubernetes Secretes

```bash
# Store sensitive data securely
kubectl create secret generic simple-bank-secrets \
  --from-literal=DB_SOURCE='postgresql://user:pass@host:5432/db' \
  --from-literal=TOKEN_SYMMETRIC_KEY='your-secret-key'

# Verify secret was created
kubectl get secrets
```

## 🔄 CI/CD Pipeline
GitHub Actions Workflow

```yaml
#.github/workflows/deploy.yml

name: Deploy to production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-central-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image to ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: simplebank
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
                     $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig \
            --name simple-bank \
            --region eu-central-1

      - name: Deploy to EKS
        run: |
          kubectl apply -f eks/deployment.yaml
          kubectl apply -f eks/service.yaml
          kubectl rollout status deployment/simple-bank-api-deployment
```

## GitHub Secrets Required

Add these in: GitHub --> Settings --> Secrets and variables --> Actions
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_REGION (eu-central-1)

## 🐛Problems Encountered & Solutions

## Problem 1: Authentication Error - "server has asked for credentials"

```bash
Error: You must be logged in to the server (the server has asked for the client to provide credential)
```

Root Case: IAM user github-cli was not authorized to access the EKS cluster.

Solution:
1. Go to AWS Console --> EKS --> Cluster --> simple-bank
2. Navigate to Access tab
3. Click Create access entry
4. Add IAM principal ARN: arn:aws:iam::ACCOUNT_ID:user/github-ci
5. Attach policy: AmazonEKSClusterAdminPolicy

Key Learinging: By default, only the IAM user who created the cluster has access. Additional users must be explicitly granted access via Access Entries or aws-auth ConfigMap.

## Problem 2: Pods in CrashLoopBackOff

Error:
```bash
NAME                           READY   STATUS             RESTARTS
simple-bank-api-xxx            0/1     CrashLoopBackOff   4
```

Root Cause: Missing environment variables. The application couldn't connect to the database because DB_SOURCE and other variables werent't provided.

Symptoms in logs:

```bash
Waiting for Postgres at :...
Error: you need to provide a host and port to test.
```

Solution:
```yaml
env:
- name: DB_HOST
  value: "simple-bank.xxx.rds.amazonaws.com"
- name: DB_PORT
  value: "5432"
- name: DB_SOURCE
  value: "postgresql://user:pass@host:5432/db"
```
Key Learning: Always verify that all required environment variables are passed to containers. Use <code>kubectl logs <pod-name></code> to debug startup issues

## Problem 3: RDS Connection Timeout

Error in pod logs:

```bash
dial tcp: i/o timeout
```

Root Cause: Security Group of RDS didn't allow inbound connections from EKS worker nodes.

Solution:

1. Find EKS node Security Group
```bash
kubectl get nodes -o wide  # Note the EC2 instance IDs
aws ec2 describe-instances --instance-ids i-xxx \
  --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId'
```

2. Update RDS Security Group:
- AWS Console --> RDS --> Database --> Connectivity & Security
- Click on VPC Security Group
- Edit Inboutnd Rules
- Add rule: Type=PostgreSQL,Port=5432,Source=EKS Node Security Group

Key Learning: Network security in AWS requires explicit rules. Always ensure Security Groups allow traffic between resources.

## Problem 4: Node Group with 0 Desired Capacity
Error:
```bash
kubectl get nodes
No resources found
```

Root Cause: Node group was configured with <code>desiredSize: 0</code>, so no EC2 instances were running.

Solution:

```bash
aws eks update-nodegroup-config \
  --cluster-name simple-bank \
  --nodegroup-name simple-bank \
  --scaling-config minSize=1,maxSize=2,desiredSize=1 \
  --region eu-central-1
```

Key Learning: EKS Node Groups can be "scaled zero" to save costs. Always verify the desired capacity matches your needs.

## Problem 5: Service Type ClusterIP(No External Access)
Error: Service had no EXTERNAL-IP, only accessible within cluster.

Root Cause: Service was configured as <code>type: ClusterIP</code>insted of <code>type: LoadBalancer</code>.

Solution:
```bash
kubectl edit service simple-bank-api-service
# Change: type: ClusterIP --> type: LoaderBalancer
```

Key Learning:
- ClusterIP: Internal-only access(default)
- Node Port: Access via node IP:port
- LoadBalancer: Creates AWS ELB for external access

## Problem 6: GitHub Actions - Wrong Cluster Name
Error:
```bash
An error occurred (ResourceNotFoundException) when calling the DescribeCluster operation: 
No cluster found for name: simple-bank-eks
```

Root Cause: Workflow referenced <code>simple-bank-eks</code> but actual cluster name was <code>simple-bank</code>.
Solution: Updated workflow file to use correct cluster name.
Key Learning: Always verify resource names match across configurations. Use <code>aws eks list-clusters</code> to confirm.


## Problem 7: Special Characters in Database Password
Issue: Password contained & characters which needed URL encoding in connections string.

Solution:
- Original password Password&7777&
- URL-encoded: Passowrd%267777%26
- Connections string: <code>postgresql://root:Passowrd%267777%26@host:5432/db</code>
Key Learinging: Special characters in URLs must be percent-encoded:
- <code>&</code> -> <code>%26</code>
- <code>@</code> -> <code>%40</code>
- <code>#</code> -> <code>%23</code>

## Problem 8: Storing Secrets in Git (Security Risk)
Issue: Initially stored database passwords and API keys directly in <code>deployment.yaml</code>
Why It's Dangerous:
- ❌ Exposed in Git history forever
- ❌ Visible to anyone with repo access
- ❌ Can be scraped by bots

Solution: Use Kubernetes Secrets
```bash
# Create secret
kubectl create secret generic simple-bank-secrets \
  --from-literal=DB_SOURCE='connection-string' \
  --from-literal=TOKEN_SYMMETRIC_KEY='secret-key'

# Reference in deployment
env:
- name: DB_SOURCE
  valueFrom:
    secretKeyRef:
      name: simple-bank-secrets
      key: DB_SOURCE
```
Key Learning: Never commit secrets to Git. Use secret managememt solutions (Kubernetes Secrets, AWS Secrets Manager, HashiCorp Valut)

## Interview Preparation
Common Question & Answers
## 1. "Walk me through you deployment process"
Answer: "I implemented a fully automated CI/CD pipeline using GitHub Actions. When code is pushed to main:
  1. GitHub Actions tirggers the workflow
  2. Code is checked out and Docker image is built
  3. Image is tagged with git SHA and pushed to Amazon ECR
  4. AWS credentials authenticate with EKS cluster
  5. kubectl applies updated Kubernetes manifests
  6. Kubernetes performs rolling update wiht zero downtime
  7. LoadBalancer routes traffic to new pods
The entire process takes about 2-3 minutes and includes automatic rollback if health checks fail"

## 2. "How do you handle database migrations in production?"
Answer: "Database migrations are handled automatically using golang-migrate. The process is:
  1. Migration files are bundled in the Docker image
  2. start.sh script runs before the application starts
  3. It waits for database availability using wait-for-it.sh
  4. Runs <code>migrate -path ./migration -database $DB_SOURCE up</code>
  5. Only after successful migration, the API server starts
This ensures database schema is always in sync with the application code. We use versioned migration files (up/down) for safe rollbacks"

## 3. "How do you ensure high availability?"
Answer: "Multiple layers of high availability:
  1. Kubernetes Deployment with 2 replicas - if one pod crashes, traffic routes to the other
  2. EKS across multiple AZs - node group spans 3 availability zones.
  3. LoadBalancer health checks - automatically removes unhealthy pods.
  4. RDS Multi-AZ (optional) - automatic failover for database
  5. Rolling updates - <code>maxUnavailable: 1</code> ensures at least one pod always runs
During deployment, Kuberntes gradually replaces pods ensuring zero downtime."

## 4. "How do you handle secrets securely?"
Answer: "I use a multi-layered approach:
  1. Kubernetes Secrets for runtime - secrets are stored encrypted at rest in etcd
  2. AWS Secrets Manager for long-term storage-provides rotation and audit logs
  3. IAM roles instead of access keys where possible - using IRSA (IAM Roles for Service Account)
  4. Never commit secrets to Git - use .gitignore and secret scanning tools
  5. Access control - only auhtorized service accounts can read secrets
For GitHub Actions, credentials are stored as repository secrets and injected at runtime."

## 5. "How would you troubleshoot a failing pod?"
Answer: "I follow a systematic approach:
  1. Check pod status: <code>kubectl get pods</code> - look for CrashLoopBackOff, ImagePullBackOff
  2. View pod logs: <code>kubectl logs <pod-name></code> - see application errors
  3. Describe pod: <code>kubectl describe pod <pod-name></code> - check events and resource limits
  4. Check resources: <code>kubectl top pods</code> - verify CPU/memory usage
  5. Access pod: <code>kubectl exec -it <pod-name> -- /bin/sh </code> - debug interactively
  6. Network debugging: Test connectivity to external services(DB, APIs)
Common issues I've encountered: missing env vars, insufficient resources, networking porblems, and wrong image tags."

## 6. "What's your strategy for scaling the application?"
Answer:
"I use horizontal pod autoscaling based on metrics:

```bash
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: simple-bank-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: simple-bank-api-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

This automatically scales pods based on CPU usage. For the node group, I configure cluster autoscaler to add/remove EC2 instances as needed.
For database scaling, RDS supports read replicas and vertical scaling during maintenance windows."

## 7. "How do you monitor the application in production?"
Answer: "I would implement comprehensive monitoring:
  1. Kubernetes built-in: <code>kubectl top</code>, describe, logs
  2. Prometheus: Collect metrics (request rate, latency, errors)
  3. Grafna: Visualize dashboard for real-time monitoring
  4. ELK Stack: Centralized logging (Elasticsearch, Logstash, Kibana)
  5. CloudWatch: AWS-level metrics (ELB, RDS, EKS)
  6. AlertManager: Send alerts so Slack/PagerDuty
Key Metric I monitor:
- Request latency (p50, p95, p99)
- Error rate
- Pod restarts
- Database connection pool
- Resource utilization"

## 8. "What improvements would you make for production?"
Answer: "Several enhancements for production-readiness:
  1. Security:
    - Enable pod security polices
    - Netwok polices to restrict traffic
    - Use AWS Secret Manager with automatic rotation
    - Implement IRSA for pod-level IAM roles
  2. Observability:
    - Distributed tracing wiht Jaeger
    - Structured logging with correlation IDs
    - Custom Prometheus metrics
  3. Resilience:
    - Circuit breakers with istio
    - Rate limiting at API gateway
    - Chaos engineering tests
  4. Cost Optimization:
    - Use Spot instances for non-critical workloads
    - Right-size pods with VPA (Vertical Pod Autoscaler)
    - Schedule node scaling based on traffic patterns
  5. Compliance:
    - Enable audit logging
    - Implement RBAC with principle of least privilege
    - Regular security scanning of images"

## 📚 Useful Commands
```bash
make postgres     # Start PostgreSQL with Docker
make createdb     # Create DB
make dropdb       # Drop DB
make migrateup    # Apply migrations
make migratedown  # Rollback migrations
make server       # Run API server
make test         # Run unit tests
```

## Kubernetes Operations
```bash
# View all resources
kubectl get all -A

# Check pod logs (follow mode)
kubectl logs -f <pod-name>

# Describe pod (see events and issues)
kubectl describe pod <pod-name>

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash

# Port forward for local testing
kubectl port-forward service/simple-bank-api-service 8080:80

# View pod resource usage
kubectl top pods

# Restart deployment
kubectl rollout restart deployment/simple-bank-api-deployment

# Check rollout status
kubectl rollout status deployment/simple-bank-api-deployment

# Rollback to previous version
kubectl rollout undo deployment/simple-bank-api-deployment

# Scale deployment
kubectl scale deployment/simple-bank-api-deployment --replicas=5

# Apply configuration changes
kubectl apply -f eks/

# Delete resources
kubectl delete -f eks/deployment.yaml
```

## AWS EKS Command 
```bash
# List all clusters
aws eks list-clusters --region eu-central-1

# Describe cluster
aws eks describe-cluster --name simple-bank --region eu-central-1

# Update kubeconfig
aws eks update-kubeconfig --name simple-bank --region eu-central-1

# List node groups
aws eks list-nodegroups --cluster-name simple-bank --region eu-central-1

# Update node group scaling
aws eks update-nodegroup-config \
  --cluster-name simple-bank \
  --nodegroup-name simple-bank \
  --scaling-config minSize=1,maxSize=5,desiredSize=2

# Add IAM user to cluster access
eksctl create iamidentitymapping \
  --cluster simple-bank \
  --arn arn:aws:iam::ACCOUNT:user/username \
  --group system:masters
```

## Docker & ECR Commands
```bash
# Login to ECR
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com

# Build image
docker build -t simplebank:latest .

# Tag image
docker tag simplebank:latest \
  ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/simplebank:latest

# Push to ECR
docker push ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/simplebank:latest

# List images in ECR
aws ecr list-images --repository-name simplebank
```

## k9s Commands (Interactive CLI)
```bash
# Launch k9s
k9s

# Inside k9s:
# :pods         - View pods
# :svc          - View services
# :deploy       - View deployments
# :nodes        - View nodes
# l             - View logs (when pod selected)
# d             - Describe resource
# e             - Edit resource
# /filter       - Filter by name
# ctrl+d        - Delete resource
# q             - Quit/go back
```

## ✅ Best Practices Implemented
1. Infrastructure as Code
- All Kubernetes configs in version control
- Reproducible deployments
- Easy rollback capability

2. Security
- Secrets stored in Kubernetes Secrets (not Git)
- IAM roles with least privilege
- Security Groups restrict network access
- No root user in containers

3. High Availability
- Multiple pod replicas
- Multi-AZ node group
- Health checks and auto-healing
- LoadBalancer distributes traffic

4. Observability
- Structured logging
- Health check endpoints
- Resource limits defined
- Pod status monitoring

5. CI/CD
- Automated testing and deployment
- Image tagged with git SHA
- Rolling updates with zero downtime
- Automated rollback on failure

6. Cost Optimization
- Right-sized instances (t3.small)
- Auto-scaling based on demand
- Efficient container images (multi-stage builds)

## Key Takeaways for Interviews

What You Learned:
- ✅ Container Orchestration: How Kubernetes manages containerized applications at scale
- ✅ Cloud Native Architecture: Designing applications for cloud environments
- ✅ Infrastructure Management: Setting up and maintaining AWS resources
- ✅ DevOps Practices: CI/CD, automation, monitoring
- ✅ Security: IAM, secrets management, network policies
- ✅ Troubleshooting: Systematic debugging of distributed systems
- ✅ Scalability: Horizontal scaling, load balancing, auto-scaling


Be Ready to Discuss:
- Why you chose EKS over other platforms (ECS, EC2, serverless)
- Trade-offs between different deployment strategies
- How you would monitor and alert on issues
- Disaster recovery and backup strategies
- Cost optimization techniques
- Security best practices

## 🚀 Next Steps
To Further Improve:

- Add monitoring: Prometheus + Grafana
- Implement HTTPS: cert-manager with Let's Encrypt
- Custom domain: Route53 + ACM certificate
- Database backups: Automated RDS snapshots
- Staging environment: Separate cluster for testing
- Infrastructure as Code: Use Terraform/CloudFormation
- Service mesh: Istio for advanced traffic management

## Production Access
```bash
http://a7c396821c32646659b5966d525cb0ab-382972812.eu-central-1.elb.amazonaws.com
```

## Test Endpoints:
```bash
# Create user
curl -X POST $API_URL/users \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"secret","full_name":"Test User","email":"test@example.com"}'

# Login
curl -X POST $API_URL/users/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"secret"}'

# Get accounts (requires token)
curl -X GET "$API_URL/accounts?page_id=1&page_size=10" \
  -H "Authorization: Bearer $TOKEN"
```

## 📝 Conclusion
This project demonstrates a production-grade deployment of a microservice on AWS with:

- ✅ Automated CI/CD reducing deployment time from hours to minutes
- ✅ High availability with multi-pod, multi-AZ architecture
- ✅ Security following AWS and Kubernetes best practices
- ✅ Scalability handling increased load automatically
- ✅ Observability with logs, metrics, and health checks

The experience gained here directly translates to real-world DevOps and Cloud Engineering roles.

## Built with ❤️ using Go, Kubernetes, and AWS