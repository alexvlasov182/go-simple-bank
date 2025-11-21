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

```bash
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

```bash
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

```bash
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

## Useful Commands
```bash
make postgres     # Start PostgreSQL with Docker
make createdb     # Create DB
make dropdb       # Drop DB
make migrateup    # Apply migrations
make migratedown  # Rollback migrations
make server       # Run API server
make test         # Run unit tests
```