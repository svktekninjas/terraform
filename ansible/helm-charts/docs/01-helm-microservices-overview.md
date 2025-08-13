# Helm Microservices Overview

## 📋 Complete Microservices List

The CF-Microservices Helm chart contains 10 microservices deployed across the ROSA cluster:

### Service Categories

| Category | Count | Services |
|----------|-------|----------|
| **Database Services** | 4 | bench-profile, daily-submissions, interviews, placements |
| **Infrastructure** | 3 | apigateway-app, spring-cloud-config, naming-server |
| **Processing/UI** | 3 | excel-service, frontend-service, spring-boot-admin |
| **Total** | **10** | All microservices |

### Detailed Service List

| # | Deployment Name | Namespace | Port | Replicas | Database Required | Status |
|---|-----------------|-----------|------|----------|-------------------|---------|
| 1 | `apigateway-app` | cf-dev | 8765 | 2 | ❌ No | Infrastructure |
| 2 | `bench-profile-service` | cf-dev | 8081 | 2 | ✅ **Aurora** | **Database Service** |
| 3 | `spring-cloud-config-service` | cf-dev | 8888 | 1 | ❌ No | Infrastructure |
| 4 | `daily-submissions-service` | cf-dev | 8080 | 2 | ✅ **Aurora** | **Database Service** |
| 5 | `excel-service` | cf-dev | 8083 | 2 | ❌ No | Processing |
| 6 | `frontend-service` | cf-dev | 80 | 2 | ❌ No | UI |
| 7 | `interviews-service` | cf-dev | 8080 | 2 | ✅ **Aurora** | **Database Service** |
| 8 | `naming-server-new` | cf-dev | 8761 | 1 | ❌ No | Infrastructure |
| 9 | `placements-service` | cf-dev | 8080 | 2 | ✅ **Aurora** | **Database Service** |
| 10 | `spring-boot-admin` | cf-dev | 8082 | 1 | ❌ No | Monitoring |

## 🗄️ Aurora Database Configuration

### Database-Connected Services
All business logic services are configured with Aurora PostgreSQL:

| Service | Port | Aurora Connection | Environment Variables |
|---------|------|-------------------|----------------------|
| bench-profile-service | 8081 | ✅ Connected | SPRING_DATASOURCE_* |
| daily-submissions-service | 8080 | ✅ Connected | SPRING_DATASOURCE_* |
| interviews-service | 8080 | ✅ Connected | SPRING_DATASOURCE_* |
| placements-service | 8080 | ✅ Connected | SPRING_DATASOURCE_* |

### Database Connection Details
```yaml
Environment Variables:
  SPRING_DATASOURCE_URL: jdbc:postgresql://cf-aurora-pg-cluster-dev.cluster-c5ouqg2i83zv.us-west-1.rds.amazonaws.com:5432/cfdb_dev
  SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver
  SPRING_DATASOURCE_USERNAME: cfadmin
  SPRING_DATASOURCE_PASSWORD: svktekdbdev
  SPRING_JPA_DATABASE_PLATFORM: org.hibernate.dialect.PostgreSQLDialect
  SPRING_JPA_HIBERNATE_DDL_AUTO: update
```

## 🏗️ Architecture Overview

### Service Dependencies
```
┌─────────────────┐
│   Frontend      │
│   (Port 80)     │
└─────────┬───────┘
          │
┌─────────▼───────┐
│   API Gateway   │
│   (Port 8765)   │
└─────────┬───────┘
          │
    ┌─────▼─────┐
    │  Naming   │
    │  Server   │
    │(Port 8761)│
    └─────┬─────┘
          │
┌─────────▼───────────────────────────────┐
│         Business Services               │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐    │
│ │ Bench   │ │ Daily   │ │Interview│    │
│ │Profile  │ │Submiss. │ │Service  │    │
│ │(8081)   │ │ (8080)  │ │ (8080)  │    │
│ └─────────┘ └─────────┘ └─────────┘    │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐    │
│ │Placement│ │ Excel   │ │Config   │    │
│ │Service  │ │Service  │ │Service  │    │
│ │ (8080)  │ │ (8083)  │ │ (8888)  │    │
│ └─────────┘ └─────────┘ └─────────┘    │
└─────────┬───────────────────────────────┘
          │
┌─────────▼───────┐
│   Aurora DB     │
│   PostgreSQL    │
│  (us-west-1)    │
└─────────────────┘
```

## 📊 Resource Allocation

### Memory and CPU Limits
| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| bench-profile | 200m | 500m | 256Mi | 512Mi |
| daily-submissions | 200m | 500m | 256Mi | 512Mi |
| interviews | 200m | 500m | 256Mi | 512Mi |
| placements | 200m | 500m | 256Mi | 512Mi |
| api-gateway | 200m | 500m | 256Mi | 512Mi |
| excel-service | 200m | 500m | 256Mi | 512Mi |
| frontend | 200m | 500m | 256Mi | 512Mi |
| naming-server | 200m | 500m | 256Mi | 512Mi |
| config-service | 200m | 500m | 256Mi | 512Mi |
| spring-boot-admin | 200m | 500m | 256Mi | 512Mi |

### Total Resource Requirements
- **Total CPU Request**: 2000m (2 cores)
- **Total CPU Limit**: 5000m (5 cores)
- **Total Memory Request**: 2560Mi (~2.5GB)
- **Total Memory Limit**: 5120Mi (~5GB)
- **Total Pods**: 17 (including replicas)

## 🔧 Helm Chart Structure

```
helm-charts/cf-microservices/
├── Chart.yaml                  # Main chart metadata
├── values.yaml                 # Global configuration
├── templates/
│   └── _helpers.tpl            # Template helpers
└── charts/                     # Individual microservice charts
    ├── api-gateway/
    ├── bench-profile/
    ├── config-service/
    ├── daily-submissions/
    ├── excel-service/
    ├── frontend/
    ├── interviews/
    ├── naming-server/
    ├── placements/
    └── spring-boot-admin/
```

Each microservice chart contains:
- `Chart.yaml` - Service metadata
- `values.yaml` - Service-specific configuration
- `templates/` - Kubernetes manifests
  - `deployment.yaml`
  - `service.yaml`
  - `route.yaml`

## 📈 Deployment Status

### Current State (✅ Deployed and Working)
- **Helm Release**: `cf-microservices-dev`
- **Namespace**: `cf-dev`
- **Revision**: 30
- **Status**: deployed

### Service Health
- **bench-profile-service**: ✅ Running (2/2) - Aurora Connected
- **daily-submissions-service**: ✅ Running (2/2) - Aurora Connected
- **interviews-service**: ✅ Running (2/2) - Aurora Connected
- **placements-service**: ✅ Running (2/2) - Aurora Connected
- **All Infrastructure Services**: ✅ Running

---
*Last Updated: July 30, 2025*
*Environment: cf-dev*
*Aurora Database: cf-aurora-pg-cluster-dev*