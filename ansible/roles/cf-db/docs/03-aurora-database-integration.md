# Aurora Database Integration Guide

## 🗄️ Aurora PostgreSQL Configuration

### Database Cluster Details
- **Cluster Name**: `cf-aurora-pg-cluster-dev`
- **Engine**: Aurora PostgreSQL 15.3
- **Region**: us-west-1 (Aurora VPC)
- **VPC**: `vpc-0be0cddd86cc68c5a` (172.31.0.0/16)
- **Writer Endpoint**: `cf-aurora-pg-cluster-dev.cluster-c5ouqg2i83zv.us-west-1.rds.amazonaws.com`
- **Reader Endpoint**: `cf-aurora-pg-cluster-dev.cluster-ro-c5ouqg2i83zv.us-west-1.rds.amazonaws.com`
- **Port**: 5432
- **Database**: `cfdb_dev`

### Database Instances
| Instance | Role | AZ | Instance Class | Status |
|----------|------|----|--------------:|--------|
| `cf-aurora-pg-writer-dev` | Writer | us-west-1a | db.t3.medium | Available ✅ |
| `cf-aurora-pg-reader-dev` | Reader | us-west-1c | db.t3.medium | Available ✅ |

## 🔗 Cross-VPC Connectivity

### Network Architecture
```
┌─────────────────────────────────┐    ┌─────────────────────────────────┐
│        ROSA Cluster VPC         │    │        Aurora DB VPC            │
│         (us-east-1)             │    │        (us-west-1)              │
│      10.0.0.0/16                │    │     172.31.0.0/16               │
│                                 │    │                                 │
│  ┌─────────────────────────┐    │    │  ┌─────────────────────────┐    │
│  │   Microservices Pods    │    │    │  │     Aurora Cluster      │    │
│  │   - bench-profile       │◄───┼────┼──┤   Writer: us-west-1a    │    │
│  │   - daily-submissions   │    │    │  │   Reader: us-west-1c    │    │
│  │   - interviews          │    │    │  │                         │    │
│  │   - placements          │    │    │  │   Private Subnets:      │    │
│  └─────────────────────────┘    │    │  │   - 172.31.2.0/24       │    │
│                                 │    │  │   - 172.31.3.0/24       │    │
└─────────────────────────────────┘    │  └─────────────────────────┘    │
                                       │                                 │
                VPC Peering             │  Security Group:                │
                Connection              │  sg-0d1abc65789e0e29c           │
                                       └─────────────────────────────────┘
```

### Security Configuration
- **Aurora Security Group**: `sg-0d1abc65789e0e29c`
- **Allowed CIDRs**:
  - `172.31.0.0/16` (Aurora VPC internal)
  - `10.0.0.0/16` (ROSA cluster VPC)
  - `172.16.0.0/16` (Additional private ranges)
  - `192.168.0.0/16` (Additional private ranges)

## 🔧 Microservice Database Configuration

### Database-Connected Services
All business logic microservices are configured with Aurora PostgreSQL:

#### 1. Bench Profile Service
```yaml
# Port: 8081
Environment Variables:
  SPRING_DATASOURCE_URL: jdbc:postgresql://cf-aurora-pg-cluster-dev.cluster-c5ouqg2i83zv.us-west-1.rds.amazonaws.com:5432/cfdb_dev
  SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver
  SPRING_DATASOURCE_USERNAME: cfadmin
  SPRING_DATASOURCE_PASSWORD: svktekdbdev
  SPRING_JPA_DATABASE_PLATFORM: org.hibernate.dialect.PostgreSQLDialect
  SPRING_JPA_HIBERNATE_DDL_AUTO: update
```

#### 2. Daily Submissions Service
```yaml
# Port: 8080
Environment Variables:
  SPRING_DATASOURCE_URL: jdbc:postgresql://cf-aurora-pg-cluster-dev.cluster-c5ouqg2i83zv.us-west-1.rds.amazonaws.com:5432/cfdb_dev
  SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver
  SPRING_DATASOURCE_USERNAME: cfadmin
  SPRING_DATASOURCE_PASSWORD: svktekdbdev
  SPRING_JPA_DATABASE_PLATFORM: org.hibernate.dialect.PostgreSQLDialect
  SPRING_JPA_HIBERNATE_DDL_AUTO: update
```

#### 3. Interviews Service
```yaml
# Port: 8080
Environment Variables:
  SPRING_DATASOURCE_URL: jdbc:postgresql://cf-aurora-pg-cluster-dev.cluster-c5ouqg2i83zv.us-west-1.rds.amazonaws.com:5432/cfdb_dev
  SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver
  SPRING_DATASOURCE_USERNAME: cfadmin
  SPRING_DATASOURCE_PASSWORD: svktekdbdev
  SPRING_JPA_DATABASE_PLATFORM: org.hibernate.dialect.PostgreSQLDialects
  SPRING_JPA_HIBERNATE_DDL_AUTO: update
```

#### 4. Placements Service
```yaml
# Port: 8080
Environment Variables:
  SPRING_DATASOURCE_URL: jdbc:postgresql://cf-aurora-pg-cluster-dev.cluster-c5ouqg2i83zv.us-west-1.rds.amazonaws.com:5432/cfdb_dev
  SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver
  SPRING_DATASOURCE_USERNAME: cfadmin
  SPRING_DATASOURCE_PASSWORD: svktekdbdev
  SPRING_JPA_DATABASE_PLATFORM: org.hibernate.dialect.PostgreSQLDialect
  SPRING_JPA_HIBERNATE_DDL_AUTO: update
```

## 📁 Helm Values Configuration

### Updated Values Files
The following Helm values files have been updated with Aurora database configuration:

#### bench-profile/values.yaml
```yaml
deployment:
  env:
    - name: SPRING_DATASOURCE_URL
      value: "jdbc:postgresql://cf-aurora-pg-cluster-dev.cluster-c5ouqg2i83zv.us-west-1.rds.amazonaws.com:5432/cfdb_dev"
    - name: SPRING_DATASOURCE_DRIVER_CLASS_NAME
      value: "org.postgresql.Driver"
    - name: SPRING_DATASOURCE_USERNAME
      value: "cfadmin"
    - name: SPRING_DATASOURCE_PASSWORD
      value: "svktekdbdev"
    - name: SPRING_JPA_DATABASE_PLATFORM
      value: "org.hibernate.dialect.PostgreSQLDialect"
    - name: SPRING_JPA_HIBERNATE_DDL_AUTO
      value: "update"
```

#### daily-submissions/values.yaml ✅
#### interviews/values.yaml ✅
#### placements/values.yaml ✅
*(Same configuration pattern as bench-profile)*

## 🚀 Deployment Process

### Helm Upgrade Command
```bash
cd /Users/swaroop/Documents/FullStack-SRE/ConsultingFirm_infra/ROSA/ClaudeDoc/ansible
helm upgrade cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev
```

### Deployment History
- **Revision 26**: Initial deployment with old database configuration
- **Revision 29**: First attempt to update database credentials
- **Revision 30**: ✅ **Current** - All microservices updated with Aurora configuration

## 📊 Connection Validation

### Check Database Connection Status
```bash
# Check if pod has correct database URL
oc get pod <pod-name> -n cf-dev -o jsonpath='{.spec.containers[0].env[?(@.name=="SPRING_DATASOURCE_URL")].value}'

# Check if pod has correct password
oc get pod <pod-name> -n cf-dev -o jsonpath='{.spec.containers[0].env[?(@.name=="SPRING_DATASOURCE_PASSWORD")].value}'

# Example for bench-profile
oc get pod bench-profile-service-77659b4dc7-8gw66 -n cf-dev -o jsonpath='{.spec.containers[0].env[?(@.name=="SPRING_DATASOURCE_PASSWORD")].value}'
```

### Connection Test Results
```bash
# Example successful connection log
2025-07-30T20:55:38.123Z  INFO - HikariPool-1 - Starting...
2025-07-30T20:55:40.939Z  INFO - HikariPool-1 - Added connection org.postgresql.jdbc.PgConnection@156f0281
2025-07-30T20:55:40.941Z  INFO - HikariPool-1 - Start completed.
2025-07-30T20:55:41.437Z  INFO - Database version: 15.3
```

### Service Health Status
| Service | Status | Database Connection | Health Check |
|---------|--------|-------------------|--------------|
| bench-profile-service | ✅ Running (2/2) | ✅ Connected | ✅ Passing |
| daily-submissions-service | ✅ Running (2/2) | ✅ Connected | ✅ Passing |
| interviews-service | ✅ Running (2/2) | ✅ Connected | ✅ Passing |
| placements-service | ✅ Running (2/2) | ✅ Connected | ✅ Passing |

## 🔍 Troubleshooting

### Common Issues and Solutions

#### 1. Connection Refused During Startup
**Symptom**: `Readiness probe failed: dial tcp connect: connection refused`
**Solution**: This is normal during startup. Wait 60-90 seconds for application initialization.

#### 2. Wrong Database Password
**Symptom**: Authentication failures in logs
**Solution**: Verify password in values.yaml and redeploy:
```bash
# Check current password
oc get pod <pod-name> -n cf-dev -o jsonpath='{.spec.containers[0].env[?(@.name=="SPRING_DATASOURCE_PASSWORD")].value}'

# Should return: svktekdbdev
```

#### 3. Network Connectivity Issues
**Symptom**: Connection timeouts to Aurora
**Solution**: Verify VPC peering and security groups:
```bash
# Check security group allows traffic from ROSA VPC
aws ec2 describe-security-groups --region us-west-1 --group-ids sg-0d1abc65789e0e29c
```

### Verification Commands
```bash
# Check pod readiness
oc get pods -n cf-dev | grep -E "(bench|daily|interviews|placements)"

# Check deployment status
oc get deployments -n cf-dev | grep -E "(bench|daily|interviews|placements)"

# Check application logs
oc logs -f deployment/bench-profile-service -n cf-dev

# Check database connection in logs
oc logs deployment/bench-profile-service -n cf-dev | grep -i "hikari\|database\|postgresql"
```

## 📈 Performance Monitoring

### Database Connection Pool Settings
Each microservice uses HikariCP connection pool with default settings:
- **Pool Size**: Auto-configured based on CPU cores
- **Connection Timeout**: 30 seconds
- **Idle Timeout**: 600 seconds (10 minutes)
- **Max Lifetime**: 1800 seconds (30 minutes)

### Health Check Endpoints
All database services expose health endpoints:
- **URL**: `http://<service-name>:8080/actuator/health`
- **Response**: JSON with database connectivity status

### Connection String Template
```
jdbc:postgresql://<aurora-endpoint>:5432/<database-name>
```

**Example**:
```
jdbc:postgresql://cf-aurora-pg-cluster-dev.cluster-c5ouqg2i83zv.us-west-1.rds.amazonaws.com:5432/cfdb_dev
```

---
*Last Updated: July 30, 2025*
*Environment: cf-dev*
*Aurora Cluster: cf-aurora-pg-cluster-dev*
*Database Version: PostgreSQL 15.3*