# Validation and Testing Guide

## Overview
This guide provides comprehensive validation and testing procedures for the CF-DB role infrastructure. Use this after deploying any component to ensure everything is working correctly.

## Complete Infrastructure Validation

### 🔍 End-to-End Infrastructure Health Check

#### 1. Quick Status Overview
```bash
# Get overall infrastructure status
cat > validate-infrastructure.sh << 'EOF'
#!/bin/bash

echo "=== CF-DB Infrastructure Validation ==="
echo "Date: $(date)"
echo "Environment: ${1:-dev}"
ENV=${1:-dev}

echo ""
echo "🔍 1. Private Subnets Status"
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=$ENV" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,State,CidrBlock,AvailabilityZone]' --output table

echo ""
echo "🔍 2. NAT Gateway Status"
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=$ENV" --profile svktek --region us-west-1 --query 'NatGateways[*].[NatGatewayId,State,NatGatewayAddresses[0].PublicIp]' --output table

echo ""
echo "🔍 3. Security Groups Status"
aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=$ENV" --profile svktek --region us-west-1 --query 'SecurityGroups[*].[GroupId,GroupName]' --output table

echo ""
echo "🔍 4. Aurora Cluster Status"
aws rds describe-db-clusters --profile svktek --region us-west-1 --query "DBClusters[?starts_with(DBClusterIdentifier, \`cf-aurora-pg-cluster-$ENV\`)].{ClusterID:DBClusterIdentifier,Status:Status,Engine:Engine,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint}" --output table

echo ""
echo "🔍 5. Aurora Instances Status"
aws rds describe-db-instances --profile svktek --region us-west-1 --query "DBInstances[?starts_with(DBInstanceIdentifier, \`cf-aurora-pg\`) && contains(DBInstanceIdentifier, \`$ENV\`)].{InstanceID:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass,AZ:AvailabilityZone}" --output table

echo ""
echo "✅ Infrastructure validation complete!"
EOF

chmod +x validate-infrastructure.sh
./validate-infrastructure.sh dev
```

#### 2. Detailed Component Validation

##### Private Subnets Validation
```bash
# Comprehensive subnet validation
SUBNETS=$(aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].SubnetId' --output text)

echo "=== Private Subnets Detailed Validation ==="
for subnet in $SUBNETS; do
    echo ""
    echo "Subnet: $subnet"
    aws ec2 describe-subnets --subnet-ids $subnet --profile svktek --region us-west-1 --query 'Subnets[0].[SubnetId,State,CidrBlock,AvailabilityZone,VpcId,MapPublicIpOnLaunch]' --output table
    
    echo "Route Table Association:"
    aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$subnet" --profile svktek --region us-west-1 --query 'RouteTables[*].[RouteTableId,Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0]]' --output table
done
```

##### NAT Gateway Validation
```bash
# NAT Gateway comprehensive check
NAT_GW_ID=$(aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[0].NatGatewayId' --output text)

echo "=== NAT Gateway Detailed Validation ==="
echo "NAT Gateway ID: $NAT_GW_ID"

# Check NAT Gateway details
aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_ID --profile svktek --region us-west-1 --query 'NatGateways[0].[NatGatewayId,State,SubnetId,VpcId,CreateTime,NatGatewayAddresses[0].PublicIp,NatGatewayAddresses[0].AllocationId]' --output table

# Check associated Elastic IP
EIP_ALLOC=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_ID --profile svktek --region us-west-1 --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' --output text)
echo ""
echo "Associated Elastic IP:"
aws ec2 describe-addresses --allocation-ids $EIP_ALLOC --profile svktek --region us-west-1 --query 'Addresses[0].[PublicIp,Domain,AssociationId]' --output table
```

##### Security Groups Validation
```bash
# Security Groups comprehensive validation
SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].GroupId' --output text)

echo "=== Security Groups Detailed Validation ==="
echo "Security Group ID: $SG_ID"

# Check ingress rules
echo ""
echo "Ingress Rules:"
aws ec2 describe-security-groups --group-ids $SG_ID --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[*].CidrIp,IpRanges[*].Description]' --output table

# Check egress rules
echo ""
echo "Egress Rules:"
aws ec2 describe-security-groups --group-ids $SG_ID --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissionsEgress[*].[IpProtocol,IpRanges[*].CidrIp]' --output table

# Validate cross-VPC access configuration
echo ""
echo "Cross-VPC Access Validation:"
EXPECTED_CIDRS=("10.0.0.0/16" "172.16.0.0/16" "192.168.0.0/16")
ACTUAL_CIDRS=$(aws ec2 describe-security-groups --group-ids $SG_ID --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[*].IpRanges[*].CidrIp' --output text)

for cidr in "${EXPECTED_CIDRS[@]}"; do
    if echo "$ACTUAL_CIDRS" | grep -q "$cidr"; then
        echo "✅ $cidr access configured"
    else
        echo "❌ $cidr access missing"
    fi
done
```

##### Aurora Cluster Validation
```bash
# Aurora cluster comprehensive validation
CLUSTER_ID="cf-aurora-pg-cluster-dev"

echo "=== Aurora Cluster Detailed Validation ==="

# Cluster status and configuration
aws rds describe-db-clusters --db-cluster-identifier $CLUSTER_ID --profile svktek --region us-west-1 --query 'DBClusters[0].[DBClusterIdentifier,Status,Engine,EngineVersion,DatabaseName,MasterUsername,Port,VpcSecurityGroups[0].VpcSecurityGroupId,DBSubnetGroup,MultiAZ]' --output table

# Instance details
echo ""
echo "Aurora Instances:"
aws rds describe-db-instances --profile svktek --region us-west-1 --query "DBInstances[?starts_with(DBInstanceIdentifier, \`cf-aurora-pg\`) && contains(DBInstanceIdentifier, \`dev\`)].[DBInstanceIdentifier,DBInstanceStatus,DBInstanceClass,AvailabilityZone,PubliclyAccessible,Endpoint.Address]" --output table

# Backup configuration
echo ""
echo "Backup Configuration:"
aws rds describe-db-clusters --db-cluster-identifier $CLUSTER_ID --profile svktek --region us-west-1 --query 'DBClusters[0].[BackupRetentionPeriod,PreferredBackupWindow,PreferredMaintenanceWindow,DeletionProtection]' --output table
```

## Connectivity Testing

### 🔗 Network Connectivity Tests

#### 1. DNS Resolution Test
```bash
# Test Aurora endpoint DNS resolution
WRITER_ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].Endpoint' --output text)
READER_ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].ReaderEndpoint' --output text)

echo "=== DNS Resolution Tests ==="
echo "Writer Endpoint: $WRITER_ENDPOINT"
echo "Reader Endpoint: $READER_ENDPOINT"

echo ""
echo "DNS Resolution Results:"
nslookup $WRITER_ENDPOINT
echo "---"
nslookup $READER_ENDPOINT
```

#### 2. Port Connectivity Test (from within VPC)
```bash
# Note: This test requires running from an EC2 instance within the VPC
# Create test script for EC2 instance execution

cat > aurora-connectivity-test.sh << 'EOF'
#!/bin/bash
# Run this script from an EC2 instance in the same VPC

WRITER_ENDPOINT=$1
READER_ENDPOINT=$2

if [ -z "$WRITER_ENDPOINT" ] || [ -z "$READER_ENDPOINT" ]; then
    echo "Usage: $0 <writer_endpoint> <reader_endpoint>"
    exit 1
fi

echo "=== Aurora Connectivity Test from VPC ==="
echo "Testing from $(hostname -I)"

echo ""
echo "Testing Writer Endpoint connectivity:"
timeout 10 bash -c "</dev/tcp/$WRITER_ENDPOINT/5432" && echo "✅ Writer endpoint reachable on port 5432" || echo "❌ Writer endpoint not reachable"

echo ""
echo "Testing Reader Endpoint connectivity:"
timeout 10 bash -c "</dev/tcp/$READER_ENDPOINT/5432" && echo "✅ Reader endpoint reachable on port 5432" || echo "❌ Reader endpoint not reachable"

echo ""
echo "Network route to writer endpoint:"
traceroute -n -m 5 $WRITER_ENDPOINT || echo "Traceroute not available"
EOF

chmod +x aurora-connectivity-test.sh
echo "✅ Created aurora-connectivity-test.sh - Copy to EC2 instance for connectivity testing"
```

### 🧪 Application Connection Testing

#### 1. PostgreSQL Client Test (from bastion host)
```bash
# Generate connection test script
cat > postgresql-connection-test.sh << 'EOF'
#!/bin/bash
# Test PostgreSQL connectivity using psql client

WRITER_ENDPOINT=$1
READER_ENDPOINT=$2
DB_NAME=${3:-cfdb_dev}
DB_USER=${4:-cfadmin}

if [ -z "$WRITER_ENDPOINT" ] || [ -z "$READER_ENDPOINT" ]; then
    echo "Usage: $0 <writer_endpoint> <reader_endpoint> [db_name] [db_user]"
    exit 1
fi

echo "=== PostgreSQL Connection Test ==="

# Test writer connection
echo "Testing Writer Connection..."
PGPASSWORD="$DB_PASSWORD" psql -h $WRITER_ENDPOINT -U $DB_USER -d $DB_NAME -p 5432 -c "SELECT version();" && echo "✅ Writer connection successful" || echo "❌ Writer connection failed"

echo ""
# Test reader connection
echo "Testing Reader Connection..."
PGPASSWORD="$DB_PASSWORD" psql -h $READER_ENDPOINT -U $DB_USER -d $DB_NAME -p 5432 -c "SELECT version();" && echo "✅ Reader connection successful" || echo "❌ Reader connection failed"

echo ""
# Test write/read operations
echo "Testing Write/Read Operations..."
PGPASSWORD="$DB_PASSWORD" psql -h $WRITER_ENDPOINT -U $DB_USER -d $DB_NAME -p 5432 -c "CREATE TABLE IF NOT EXISTS connection_test (id SERIAL PRIMARY KEY, test_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
PGPASSWORD="$DB_PASSWORD" psql -h $WRITER_ENDPOINT -U $DB_USER -d $DB_NAME -p 5432 -c "INSERT INTO connection_test (test_time) VALUES (NOW());"

# Read from reader endpoint
sleep 2  # Allow for replication lag
PGPASSWORD="$DB_PASSWORD" psql -h $READER_ENDPOINT -U $DB_USER -d $DB_NAME -p 5432 -c "SELECT COUNT(*) FROM connection_test;" && echo "✅ Read replication working" || echo "❌ Read replication failed"

# Cleanup
PGPASSWORD="$DB_PASSWORD" psql -h $WRITER_ENDPOINT -U $DB_USER -d $DB_NAME -p 5432 -c "DROP TABLE IF EXISTS connection_test;"
EOF

chmod +x postgresql-connection-test.sh
echo "✅ Created postgresql-connection-test.sh"
echo "Usage: ./postgresql-connection-test.sh <writer_endpoint> <reader_endpoint> [db_name] [db_user]"
```

## Performance Testing

### 📊 Aurora Performance Validation

#### 1. Basic Performance Metrics
```bash
# CloudWatch metrics collection
cat > collect-aurora-metrics.sh << 'EOF'
#!/bin/bash

CLUSTER_ID=${1:-cf-aurora-pg-cluster-dev}
START_TIME=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

echo "=== Aurora Performance Metrics (Last Hour) ==="
echo "Cluster: $CLUSTER_ID"
echo "Time Range: $START_TIME to $END_TIME"

# CPU Utilization
echo ""
echo "📊 CPU Utilization:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name CPUUtilization \
    --dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 3600 \
    --statistics Average,Maximum \
    --profile svktek --region us-west-1 \
    --query 'Datapoints[*].[Timestamp,Average,Maximum]' --output table

# Database Connections
echo ""
echo "📊 Database Connections:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name DatabaseConnections \
    --dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 3600 \
    --statistics Average,Maximum \
    --profile svktek --region us-west-1 \
    --query 'Datapoints[*].[Timestamp,Average,Maximum]' --output table

# Read/Write IOPS
echo ""
echo "📊 Read IOPS:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name ReadIOPS \
    --dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 3600 \
    --statistics Average,Maximum \
    --profile svktek --region us-west-1 \
    --query 'Datapoints[*].[Timestamp,Average,Maximum]' --output table
EOF

chmod +x collect-aurora-metrics.sh
./collect-aurora-metrics.sh
```

#### 2. Storage and I/O Performance
```bash
# Storage metrics
cat > aurora-storage-metrics.sh << 'EOF'
#!/bin/bash

CLUSTER_ID=${1:-cf-aurora-pg-cluster-dev}

echo "=== Aurora Storage Information ==="

# Current storage usage
aws rds describe-db-clusters --db-cluster-identifier $CLUSTER_ID --profile svktek --region us-west-1 --query 'DBClusters[0].[AllocatedStorage,StorageType,StorageEncrypted]' --output table

# Volume read/write IOPS
echo ""
echo "📊 Volume Read IOPS (Last 24 hours):"
aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name VolumeReadIOPs \
    --dimensions Name=DBClusterIdentifier,Value=$CLUSTER_ID \
    --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 86400 \
    --statistics Average,Maximum \
    --profile svktek --region us-west-1 \
    --query 'Datapoints[*].[Timestamp,Average,Maximum]' --output table
EOF

chmod +x aurora-storage-metrics.sh
./aurora-storage-metrics.sh
```

## Security Validation

### 🔒 Security Configuration Tests

#### 1. Network Security Validation
```bash
# Comprehensive security validation
cat > security-validation.sh << 'EOF'
#!/bin/bash

ENV=${1:-dev}
echo "=== Security Configuration Validation ==="
echo "Environment: $ENV"

# Check Aurora cluster security configuration
CLUSTER_ID="cf-aurora-pg-cluster-$ENV"
echo ""
echo "🔒 Aurora Security Configuration:"
aws rds describe-db-clusters --db-cluster-identifier $CLUSTER_ID --profile svktek --region us-west-1 --query 'DBClusters[0].[StorageEncrypted,DeletionProtection,VpcSecurityGroups[*].VpcSecurityGroupId]' --output table

# Check instance accessibility
echo ""
echo "🔒 Instance Accessibility:"
aws rds describe-db-instances --profile svktek --region us-west-1 --query "DBInstances[?starts_with(DBInstanceIdentifier, \`cf-aurora-pg\`) && contains(DBInstanceIdentifier, \`$ENV\`)].{Instance:DBInstanceIdentifier,PubliclyAccessible:PubliclyAccessible,SubnetGroup:DBSubnetGroup}" --output table

# Validate security group rules
SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=$ENV" --profile svktek --region us-west-1 --query 'SecurityGroups[0].GroupId' --output text)

echo ""
echo "🔒 Security Group Rules Validation:"
echo "Security Group: $SG_ID"

# Check for any public access (should be none)
PUBLIC_RULES=$(aws ec2 describe-security-groups --group-ids $SG_ID --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]' --output json)

if [ "$PUBLIC_RULES" == "[]" ]; then
    echo "✅ No public access rules found"
else
    echo "⚠️ WARNING: Public access rules detected:"
    echo "$PUBLIC_RULES"
fi

# Check for non-standard ports
NON_POSTGRES_RULES=$(aws ec2 describe-security-groups --group-ids $SG_ID --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[?FromPort!=`5432`]' --output json)

if [ "$NON_POSTGRES_RULES" == "[]" ]; then
    echo "✅ Only PostgreSQL port (5432) access configured"
else
    echo "⚠️ WARNING: Non-PostgreSQL ports detected:"
    echo "$NON_POSTGRES_RULES"
fi
EOF

chmod +x security-validation.sh
./security-validation.sh dev
```

#### 2. Backup and Recovery Validation
```bash
# Backup configuration validation
cat > backup-validation.sh << 'EOF'
#!/bin/bash

CLUSTER_ID=${1:-cf-aurora-pg-cluster-dev}

echo "=== Backup and Recovery Validation ==="
echo "Cluster: $CLUSTER_ID"

# Check backup configuration
echo ""
echo "🔄 Backup Configuration:"
aws rds describe-db-clusters --db-cluster-identifier $CLUSTER_ID --profile svktek --region us-west-1 --query 'DBClusters[0].[BackupRetentionPeriod,PreferredBackupWindow,PreferredMaintenanceWindow,DeletionProtection]' --output table

# Check recent backups
echo ""
echo "🔄 Recent Automated Backups:"
aws rds describe-db-cluster-automated-backups --profile svktek --region us-west-1 --query "DbClusterAutomatedBackups[?DbClusterIdentifier=='$CLUSTER_ID'].[DbClusterIdentifier,Status,BackupRetentionPeriod,SourceDbClusterArn]" --output table

# Check snapshots
echo ""
echo "🔄 Manual Snapshots:"
aws rds describe-db-cluster-snapshots --db-cluster-identifier $CLUSTER_ID --snapshot-type manual --profile svktek --region us-west-1 --query 'DBClusterSnapshots[*].[DBClusterSnapshotIdentifier,Status,SnapshotCreateTime,PercentProgress]' --output table
EOF

chmod +x backup-validation.sh
./backup-validation.sh
```

## Monitoring and Alerting

### 📈 Monitoring Setup Validation

#### 1. CloudWatch Logs Validation
```bash
# CloudWatch logs verification
cat > logs-validation.sh << 'EOF'
#!/bin/bash

CLUSTER_ID=${1:-cf-aurora-pg-cluster-dev}

echo "=== CloudWatch Logs Validation ==="

# Check if logs are enabled
echo "📊 Enabled Log Types:"
aws rds describe-db-clusters --db-cluster-identifier $CLUSTER_ID --profile svktek --region us-west-1 --query 'DBClusters[0].EnabledCloudwatchLogsExports' --output json

# List available log groups
echo ""
echo "📊 Available Log Groups:"
aws logs describe-log-groups --profile svktek --region us-west-1 --query "logGroups[?contains(logGroupName, '$CLUSTER_ID')].logGroupName" --output table

# Check recent log events (if logs exist)
LOG_GROUPS=$(aws logs describe-log-groups --profile svktek --region us-west-1 --query "logGroups[?contains(logGroupName, '$CLUSTER_ID')].logGroupName" --output text)

for log_group in $LOG_GROUPS; do
    echo ""
    echo "📊 Recent events in $log_group:"
    aws logs describe-log-streams --log-group-name "$log_group" --profile svktek --region us-west-1 --query 'logStreams[0:3].[logStreamName,lastEventTime]' --output table 2>/dev/null || echo "No log streams found"
done
EOF

chmod +x logs-validation.sh
./logs-validation.sh
```

#### 2. Performance Insights Validation
```bash
# Performance Insights check
cat > performance-insights-check.sh << 'EOF'
#!/bin/bash

ENV=${1:-dev}

echo "=== Performance Insights Validation ==="

# Check Performance Insights status
INSTANCES=$(aws rds describe-db-instances --profile svktek --region us-west-1 --query "DBInstances[?starts_with(DBInstanceIdentifier, \`cf-aurora-pg\`) && contains(DBInstanceIdentifier, \`$ENV\`)].DBInstanceIdentifier" --output text)

for instance in $INSTANCES; do
    echo ""
    echo "Instance: $instance"
    PI_STATUS=$(aws rds describe-db-instances --db-instance-identifier $instance --profile svktek --region us-west-1 --query 'DBInstances[0].PerformanceInsightsEnabled' --output text)
    
    if [ "$PI_STATUS" == "true" ]; then
        echo "✅ Performance Insights enabled"
        
        # Get Performance Insights resource ID
        PI_RESOURCE=$(aws rds describe-db-instances --db-instance-identifier $instance --profile svktek --region us-west-1 --query 'DBInstances[0].DbiResourceId' --output text)
        echo "Performance Insights Resource ID: $PI_RESOURCE"
    else
        echo "❌ Performance Insights disabled"
        echo "💡 Consider enabling for production workloads"
    fi
done
EOF

chmod +x performance-insights-check.sh
./performance-insights-check.sh dev
```

## Cost Monitoring

### 💰 Cost Analysis and Optimization

#### 1. Current Infrastructure Costs
```bash
# Cost estimation script
cat > cost-analysis.sh << 'EOF'
#!/bin/bash

ENV=${1:-dev}

echo "=== Infrastructure Cost Analysis ==="
echo "Environment: $ENV"
echo "Region: us-west-1"
echo ""

# NAT Gateway costs
NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=$ENV" --profile svktek --region us-west-1 --query 'length(NatGateways[?State==`available`])')
echo "📊 NAT Gateways: $NAT_COUNT"
echo "   Monthly cost: \$$(echo "$NAT_COUNT * 45" | bc).00"

# Elastic IP costs
EIP_COUNT=$(aws ec2 describe-addresses --filters "Name=tag:Environment,Values=$ENV" --profile svktek --region us-west-1 --query 'length(Addresses)')
echo "📊 Elastic IPs: $EIP_COUNT"
echo "   Monthly cost: \$$(echo "$EIP_COUNT * 3.65" | bc)"

# Aurora instances
INSTANCES=$(aws rds describe-db-instances --profile svktek --region us-west-1 --query "DBInstances[?starts_with(DBInstanceIdentifier, \`cf-aurora-pg\`) && contains(DBInstanceIdentifier, \`$ENV\`)].[DBInstanceIdentifier,DBInstanceClass]" --output text)

echo "📊 Aurora Instances:"
TOTAL_INSTANCE_COST=0
while IFS=$'\t' read -r instance_id instance_class; do
    case $instance_class in
        "db.t3.medium")
            COST=30
            ;;
        "db.r6g.large")
            COST=150
            ;;
        "db.r6g.xlarge")
            COST=300
            ;;
        *)
            COST=100  # Default estimate
            ;;
    esac
    echo "   $instance_id ($instance_class): \$$COST/month"
    TOTAL_INSTANCE_COST=$((TOTAL_INSTANCE_COST + COST))
done <<< "$INSTANCES"

echo ""
echo "💰 Estimated Monthly Costs:"
echo "   NAT Gateway: \$$(echo "$NAT_COUNT * 45" | bc).00"
echo "   Elastic IPs: \$$(echo "$EIP_COUNT * 3.65" | bc)"
echo "   Aurora Instances: \$$TOTAL_INSTANCE_COST.00"
echo "   Storage (estimated): \$10-50 (depends on usage)"
echo "   Data Transfer: \$5-20 (depends on usage)"
echo ""
TOTAL_BASE=$(echo "$NAT_COUNT * 45 + $EIP_COUNT * 3.65 + $TOTAL_INSTANCE_COST" | bc)
echo "   Total Base Cost: \$$TOTAL_BASE - \$$(echo "$TOTAL_BASE + 70" | bc)/month"
EOF

chmod +x cost-analysis.sh
./cost-analysis.sh dev
```

## Comprehensive Test Suite

### 🧪 Complete Infrastructure Test

#### 1. Full Test Suite Execution
```bash
# Master test script
cat > run-all-tests.sh << 'EOF'
#!/bin/bash

ENV=${1:-dev}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_LOG="validation_results_${ENV}_${TIMESTAMP}.log"

echo "=== CF-DB Infrastructure Complete Test Suite ===" | tee $TEST_LOG
echo "Environment: $ENV" | tee -a $TEST_LOG
echo "Timestamp: $(date)" | tee -a $TEST_LOG
echo "Log file: $TEST_LOG" | tee -a $TEST_LOG
echo "" | tee -a $TEST_LOG

# Function to run test and capture results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "🧪 Running: $test_name" | tee -a $TEST_LOG
    echo "Command: $test_command" | tee -a $TEST_LOG
    echo "---" | tee -a $TEST_LOG
    
    if eval "$test_command" >> $TEST_LOG 2>&1; then
        echo "✅ PASSED: $test_name" | tee -a $TEST_LOG
    else
        echo "❌ FAILED: $test_name" | tee -a $TEST_LOG
    fi
    echo "" | tee -a $TEST_LOG
}

# Run all validation tests
run_test "Infrastructure Overview" "./validate-infrastructure.sh $ENV"
run_test "Security Validation" "./security-validation.sh $ENV"
run_test "Backup Validation" "./backup-validation.sh"
run_test "Performance Insights Check" "./performance-insights-check.sh $ENV"
run_test "Cost Analysis" "./cost-analysis.sh $ENV"

# Generate summary
echo "=== Test Summary ===" | tee -a $TEST_LOG
PASSED=$(grep -c "✅ PASSED" $TEST_LOG)
FAILED=$(grep -c "❌ FAILED" $TEST_LOG)
TOTAL=$((PASSED + FAILED))

echo "Total Tests: $TOTAL" | tee -a $TEST_LOG
echo "Passed: $PASSED" | tee -a $TEST_LOG
echo "Failed: $FAILED" | tee -a $TEST_LOG

if [ $FAILED -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED!" | tee -a $TEST_LOG
else
    echo "⚠️ Some tests failed. Check log for details." | tee -a $TEST_LOG
fi

echo "" | tee -a $TEST_LOG
echo "Full results saved to: $TEST_LOG" | tee -a $TEST_LOG
EOF

chmod +x run-all-tests.sh
```

#### 2. Test Results Documentation
```bash
# Generate test report
cat > generate-test-report.sh << 'EOF'
#!/bin/bash

ENV=${1:-dev}
TIMESTAMP=$(date +%Y-%m-%d)

# Create comprehensive test report
cat > "executions/$ENV/validation-test-report-$TIMESTAMP.md" << EOL
# CF-DB Infrastructure Validation Report

**Date**: $(date)
**Environment**: $ENV
**Executed By**: [Your Name]
**Status**: [To be updated after tests]

## Test Results Summary

### Infrastructure Components Status
- [ ] Private Subnets (Multi-AZ)
- [ ] NAT Gateway and Routing
- [ ] Security Groups (Cross-VPC Access)
- [ ] Aurora PostgreSQL Cluster
- [ ] Aurora Instances (Writer/Reader)

### Security Validation
- [ ] Network Access Controls
- [ ] Database Security Configuration
- [ ] Backup and Recovery Setup
- [ ] Encryption Status

### Performance Validation
- [ ] CloudWatch Metrics Collection
- [ ] Performance Insights Status
- [ ] Resource Utilization
- [ ] Connection Testing

### Cost Analysis
- [ ] Resource Cost Estimation
- [ ] Optimization Recommendations
- [ ] Budget Monitoring Setup

## Detailed Test Results

### Infrastructure Health Check
\`\`\`
[Results to be filled by running ./validate-infrastructure.sh $ENV]
\`\`\`

### Security Configuration
\`\`\`
[Results to be filled by running ./security-validation.sh $ENV]
\`\`\`

### Performance Metrics
\`\`\`
[Results to be filled by running ./collect-aurora-metrics.sh]
\`\`\`

## Recommendations

### Immediate Actions Required
- [ ] [Any critical issues found]

### Performance Optimizations
- [ ] [Performance recommendations]

### Security Enhancements
- [ ] [Security recommendations]

### Cost Optimizations
- [ ] [Cost saving opportunities]

## Next Steps

### Short Term (1-2 weeks)
- [ ] [Immediate action items]

### Medium Term (1-3 months)
- [ ] [Planning and optimization items]

### Long Term (3+ months)
- [ ] [Strategic improvements]

## Notes
- All tests executed successfully without errors
- Infrastructure is ready for application deployment
- Monitoring and alerting recommended for production

---
**Report Generated**: $(date)
**Tool**: CF-DB Validation Suite
EOL

echo "✅ Test report template created: executions/$ENV/validation-test-report-$TIMESTAMP.md"
echo "💡 Fill in the results by running the individual test scripts"
EOF

chmod +x generate-test-report.sh
./generate-test-report.sh dev
```

## Quick Reference Commands

### 🚀 Essential Validation Commands

```bash
# Quick health check
./validate-infrastructure.sh dev

# Security check
./security-validation.sh dev

# Performance check
./collect-aurora-metrics.sh

# Cost analysis
./cost-analysis.sh dev

# Full test suite
./run-all-tests.sh dev

# Generate report template
./generate-test-report.sh dev
```

### 📋 Manual Verification Checklist

#### ✅ Infrastructure Checklist
- [ ] 2 private subnets across different AZs
- [ ] NAT Gateway in available state with public IP
- [ ] Security group with cross-VPC rules (ports 5432)
- [ ] Aurora cluster status = 'available'
- [ ] Writer instance in first AZ, reader in second AZ
- [ ] All resources properly tagged

#### ✅ Security Checklist
- [ ] No public accessibility on database instances
- [ ] Security groups restrict access to specific CIDR blocks
- [ ] Storage encryption enabled
- [ ] Backup retention configured appropriately
- [ ] No unnecessary ports open

#### ✅ Performance Checklist
- [ ] CloudWatch metrics collecting data
- [ ] Performance Insights enabled (recommended for prod)
- [ ] Connection endpoints resolving correctly
- [ ] Multi-AZ deployment confirmed

#### ✅ Operational Checklist
- [ ] Backup window configured for low-impact times
- [ ] Maintenance window configured appropriately
- [ ] Monitoring and alerting planned
- [ ] Documentation updated
- [ ] Cost monitoring in place

## Troubleshooting Common Issues

### ❌ Common Validation Failures

#### 1. DNS Resolution Issues
```bash
# If Aurora endpoints don't resolve
# Check VPC DNS settings
aws ec2 describe-vpcs --vpc-ids vpc-0642a6fba47ae2a28 --profile svktek --region us-west-1 --query 'Vpcs[0].[EnableDnsHostnames,EnableDnsSupport]'

# Should both return true
```

#### 2. Connectivity Issues
```bash
# Check route table associations
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-xxxxxx" --profile svktek --region us-west-1

# Verify NAT Gateway in route table
aws ec2 describe-route-tables --filters "Name=route.nat-gateway-id,Values=nat-xxxxxx" --profile svktek --region us-west-1
```

#### 3. Security Group Issues
```bash
# Verify security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxx --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions'

# Check for conflicting rules
aws ec2 describe-security-groups --group-ids sg-xxxxxx --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissionsEgress'
```

## Key Takeaways

✅ **Validation Best Practices:**
- **Systematic Testing**: Test each component individually and as a whole
- **Automated Validation**: Use scripts for consistent and repeatable testing
- **Documentation**: Record all test results and findings
- **Security Focus**: Always validate security configurations
- **Performance Monitoring**: Establish baseline metrics early

✅ **Monitoring Recommendations:**
- **CloudWatch Metrics**: Monitor CPU, connections, IOPS, and storage
- **Performance Insights**: Enable for production workloads
- **Cost Monitoring**: Track spending and optimize resources
- **Alerting**: Set up alerts for critical metrics
- **Log Analysis**: Enable and monitor CloudWatch logs

The validation and testing procedures ensure your CF-DB infrastructure is production-ready, secure, and performing optimally. Regular validation helps maintain infrastructure health and catch issues early.