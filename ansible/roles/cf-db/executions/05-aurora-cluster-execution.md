# Aurora Cluster Task Execution

## Overview
This guide walks you through executing the Aurora cluster task, which deploys the Aurora PostgreSQL database cluster with writer and reader instances across multiple availability zones.

## Prerequisites

### ✅ Pre-execution Checklist
- [ ] Private subnets, NAT Gateway, and security groups tasks completed successfully
- [ ] AWS CLI configured with 'svktek' profile
- [ ] You have RDS permissions for cluster and instance creation
- [ ] Environment configuration includes database settings

### 🔍 Verify Prerequisites
```bash
# 1. Verify private subnets exist (required for DB subnet group)
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,State,AvailabilityZone]' --output table
# Expected: 2 subnets in 'available' state across different AZs

# 2. Verify security group exists (required for Aurora cluster)
aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'SecurityGroups[*].[GroupId,GroupName]' --output table
# Expected: cf-aurora-db-sg-dev security group

# 3. Check RDS permissions and quotas
aws rds describe-account-attributes --profile svktek --region us-west-1
# Expected: Should show RDS service limits

# 4. Verify database configuration
cat environments/dev/cf-db.yml | grep -A 20 database
# Expected: Should show Aurora PostgreSQL configuration
```

## Execution Steps

### Step 1: Dependency Validation
```bash
# Navigate to project root
cd /path/to/your/ansible/project

# Validate that dependencies are available
ansible-playbook playbooks/main.yml -t db-cluster --check -v | grep -E "(private_subnet_ids|aurora_sg)"
# Expected: Should show private subnet IDs and security group ID
```

### Step 2: Dry Run (Check Mode)
```bash
# Execute in check mode to see what would be created
ansible-playbook playbooks/main.yml -t db-cluster --check -v
```

**Expected Output Pattern:**
```
TASK [cf-db : Display dependency status] ***************************************
ok: [localhost] => {
    "msg": [
        "=== DB Cluster Dependency Status ===",
        "Private Subnets: 2 found - ['subnet-0582b9dea4735e4ef', 'subnet-0d6347b494691099c']",
        "Aurora Security Group: sg-04d00fe7bd9d27fe2",
        "Region: us-west-1",
        "Availability Zones: ['us-west-1a', 'us-west-1c']"
    ]
}

TASK [cf-db : Create DB Subnet Group for Aurora (Multi-AZ)] ********************
changed: [localhost]

TASK [cf-db : Create Aurora PostgreSQL Cluster] ********************************
changed: [localhost]

TASK [cf-db : Create Aurora Cluster Writer Instance] ***************************
changed: [localhost]

TASK [cf-db : Create Aurora Cluster Reader Instance] ****************************
changed: [localhost]
```

### Step 3: Execute Aurora Cluster Task
```bash
# Execute the Aurora cluster task (this will take 10-15 minutes)
ansible-playbook playbooks/main.yml -t db-cluster -v
```

**💡 What to Watch For:**
- DB Subnet Group creation is fast (< 1 minute)
- Aurora cluster creation takes 5-8 minutes
- Writer instance creation takes 5-10 minutes
- Reader instance creation takes 5-10 minutes
- Total time: 15-25 minutes

### Step 4: Monitor Progress (Recommended)
```bash
# In separate terminals, monitor Aurora deployment progress

# Terminal 1: Monitor cluster status
watch "aws rds describe-db-clusters --profile svktek --region us-west-1 --query 'DBClusters[?starts_with(DBClusterIdentifier, \`cf-aurora-pg-cluster-dev\`)].[DBClusterIdentifier,Status,Endpoint]' --output table"

# Terminal 2: Monitor instance status
watch "aws rds describe-db-instances --profile svktek --region us-west-1 --query 'DBInstances[?starts_with(DBInstanceIdentifier, \`cf-aurora-pg\`) && contains(DBInstanceIdentifier, \`dev\`)].[DBInstanceIdentifier,DBInstanceStatus,AvailabilityZone]' --output table"

# Terminal 3: Monitor subnet group
watch "aws rds describe-db-subnet-groups --profile svktek --region us-west-1 --query 'DBSubnetGroups[?starts_with(DBSubnetGroupName, \`cf-private-db-subnet-group-dev\`)].[DBSubnetGroupName,SubnetGroupStatus]' --output table"
```

## Expected Results

### ✅ Successful Execution Output
```
PLAY RECAP *********************************************************
localhost                  : ok=15   changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 📊 Expected AWS Resources Created

#### 1. DB Subnet Group
```bash
aws rds describe-db-subnet-groups --db-subnet-group-name cf-private-db-subnet-group-dev --profile svktek --region us-west-1 --query 'DBSubnetGroups[0].[DBSubnetGroupName,SubnetGroupStatus,Subnets[*].SubnetIdentifier]' --output table
```

**Expected Output:**
```
---------------------------------------------------------------------------------
|                           DescribeDBSubnetGroups                            |
+-------------------------------+-----------+----------------------------------+
|  cf-private-db-subnet-group-dev|  Complete |  subnet-0582b9..., subnet-0d63..|
+-------------------------------+-----------+----------------------------------+
```

#### 2. Aurora Cluster
```bash
aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].[DBClusterIdentifier,Status,Engine,EngineVersion,Endpoint,ReaderEndpoint,DatabaseName]' --output table
```

**Expected Output:**
```
-----------------------------------------------------------------------------------------------------------------
|                                        DescribeDBClusters                                                    |
+---------------------------+-----------+-------------------+-------+---------------------------+---------------+
|  cf-aurora-pg-cluster-dev |  available|  aurora-postgresql|  15.3 |  cf-aurora-pg-cluster-...|  cfdb_dev     |
+---------------------------+-----------+-------------------+-------+---------------------------+---------------+
```

#### 3. Aurora Instances
```bash
aws rds describe-db-instances --profile svktek --region us-west-1 --query 'DBInstances[?starts_with(DBInstanceIdentifier, `cf-aurora-pg`) && contains(DBInstanceIdentifier, `dev`)].[DBInstanceIdentifier,DBInstanceStatus,DBInstanceClass,AvailabilityZone,Endpoint.Address]' --output table
```

**Expected Output:**
```
----------------------------------------------------------------------------------------------------
|                                    DescribeDBInstances                                          |
+----------------------------+------------+---------------+-------------+-------------------------+
|  cf-aurora-pg-writer-dev   |  available |  db.t3.medium |  us-west-1a |  cf-aurora-pg-writer... |
|  cf-aurora-pg-reader-dev   |  available |  db.t3.medium |  us-west-1c |  cf-aurora-pg-reader... |
+----------------------------+------------+---------------+-------------+-------------------------+
```

### 🏷️ Verify Resource Tagging
```bash
# Check cluster tags
aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].TagList' --output json

# Check instance tags
aws rds describe-db-instances --db-instance-identifier cf-aurora-pg-writer-dev --profile svktek --region us-west-1 --query 'DBInstances[0].TagList' --output json
```

**Expected Tags:**
- Name: cf-aurora-pg-cluster-dev / cf-aurora-pg-writer-dev / cf-aurora-pg-reader-dev
- Environment: dev
- Project: ConsultingFirm
- Component: Database
- ManagedBy: Ansible

## Verification Steps

### 1. Cluster Availability Verification
```bash
# Verify cluster is available and accessible
CLUSTER_STATUS=$(aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].Status' --output text)
echo "Aurora Cluster Status: $CLUSTER_STATUS"
# Expected: available
```

### 2. Multi-AZ Deployment Verification  
```bash
# Verify instances are deployed across multiple AZs
aws rds describe-db-instances --profile svktek --region us-west-1 --query 'DBInstances[?starts_with(DBInstanceIdentifier, `cf-aurora-pg`) && contains(DBInstanceIdentifier, `dev`)].AvailabilityZone' --output text
# Expected: us-west-1a us-west-1c (or similar multi-AZ distribution)
```

### 3. Database Connectivity Test
```bash
# Get connection endpoints
WRITER_ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].Endpoint' --output text)
READER_ENDPOINT=$(aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].ReaderEndpoint' --output text)

echo "Writer Endpoint: $WRITER_ENDPOINT"
echo "Reader Endpoint: $READER_ENDPOINT"

# Test DNS resolution (should resolve to private IPs)
nslookup $WRITER_ENDPOINT
nslookup $READER_ENDPOINT
```

### 4. Security Group Association Verification
```bash
# Verify cluster is using the correct security group
aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].VpcSecurityGroups[*].[VpcSecurityGroupId,Status]' --output table
# Expected: Should show sg-04d00fe7bd9d27fe2 with Status: active
```

## Troubleshooting

### ❌ Common Issues and Solutions

#### 1. Insufficient DB Subnet Groups in AZ
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "DB Subnet Group doesn't meet availability zone coverage requirement"}
```

**Solution:**
```bash
# Check subnet distribution across AZs
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,AvailabilityZone]' --output table

# Ensure subnets span at least 2 different AZs
# If not, check private subnets task configuration
```

#### 2. Security Group Not Found
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "InvalidGroup.NotFound: The security group 'sg-xxxxxxxxx' does not exist"}
```

**Solution:**
```bash
# Verify security group exists
aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" --profile svktek --region us-west-1

# If missing, run security groups task first
ansible-playbook playbooks/main.yml -t security-groups
```

#### 3. DB Instance Class Not Available
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "InvalidDBInstanceClass: DB instance class 'db.t3.medium' is not available"}
```

**Solution:**
```bash
# Check available instance classes for Aurora PostgreSQL
aws rds describe-orderable-db-instance-options --engine aurora-postgresql --profile svktek --region us-west-1 --query 'OrderableDBInstanceOptions[*].DBInstanceClass' --output text | tr '\t' '\n' | sort -u

# Update environment configuration with available instance class
nano environments/dev/cf-db.yml
```

#### 4. Aurora Cluster Creation Timeout
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "Timeout waiting for Aurora cluster to become available"}
```

**Solution:**
```bash
# Check cluster status manually
aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].[Status,ClusterCreateTime]'

# If still creating, wait longer or check AWS service health
# Cluster creation can take 10-15 minutes
```

#### 5. Master Password Issues
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "InvalidParameterValue: The parameter MasterUserPassword is not a valid password"}
```

**Solution:**
```bash
# Verify password meets AWS requirements:
# - 8-128 characters
# - No spaces, /, ", @, or \
# Update environment configuration or use external variable
ansible-playbook playbooks/main.yml -t db-cluster -e cf_db_password='MySecurePassword123!'
```

### 🔧 Debug Commands

```bash
# Run with maximum verbosity to see detailed AWS API calls
ansible-playbook playbooks/main.yml -t db-cluster -vvv

# Test dependency resolution
ansible-playbook playbooks/main.yml -t db-cluster --start-at-task "Check if private subnet IDs are available"

# Test only validation tasks
ansible-playbook playbooks/main.yml -t db-cluster,validation --check

# Check specific Aurora cluster details
aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1
```

## Database Connection Testing

### 🔗 Connection Details
```bash
# Get complete connection information
CLUSTER_INFO=$(aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0]')

echo "=== Aurora Cluster Connection Details ==="
echo "Cluster ID: $(echo $CLUSTER_INFO | jq -r '.DBClusterIdentifier')"
echo "Writer Endpoint: $(echo $CLUSTER_INFO | jq -r '.Endpoint')"
echo "Reader Endpoint: $(echo $CLUSTER_INFO | jq -r '.ReaderEndpoint')"
echo "Database Name: $(echo $CLUSTER_INFO | jq -r '.DatabaseName')"
echo "Master Username: $(echo $CLUSTER_INFO | jq -r '.MasterUsername')"
echo "Port: $(echo $CLUSTER_INFO | jq -r '.Port')"
echo "Engine Version: $(echo $CLUSTER_INFO | jq -r '.EngineVersion')"
```

### 🧪 Connection Test (from EC2 instance in same VPC)
```bash
# If you have an EC2 instance in the same VPC, test connectivity:
# psql -h cf-aurora-pg-cluster-dev.cluster-xxxxxxxxx.us-west-1.rds.amazonaws.com -U cfadmin -d cfdb_dev -p 5432

# Test with telnet (should connect if security groups are correct)
# telnet cf-aurora-pg-cluster-dev.cluster-xxxxxxxxx.us-west-1.rds.amazonaws.com 5432
```

## Performance and Monitoring

### 📊 Aurora Performance Insights
```bash
# Check if Performance Insights is enabled
aws rds describe-db-instances --db-instance-identifier cf-aurora-pg-writer-dev --profile svktek --region us-west-1 --query 'DBInstances[0].PerformanceInsightsEnabled'
# Expected: false (can be enabled post-deployment)
```

### 📈 CloudWatch Metrics
```bash
# List available CloudWatch metrics for Aurora
aws cloudwatch list-metrics --namespace AWS/RDS --profile svktek --region us-west-1 --dimensions Name=DBClusterIdentifier,Value=cf-aurora-pg-cluster-dev
```

## Cost Analysis

### 💰 Development Environment Costs (Monthly Estimates)
- **Aurora Cluster**: Base cost included with instances
- **Writer Instance (db.t3.medium)**: ~$25-35/month
- **Reader Instance (db.t3.medium)**: ~$25-35/month  
- **Storage**: ~$0.10/GB-month for Aurora storage
- **Backup Storage**: First 100% of storage free, then $0.02/GB-month
- **Data Transfer**: Within AZ free, cross-AZ $0.01/GB

**Total Estimated Cost**: ~$50-75/month for development Aurora cluster

### 📊 Cost Optimization Tips
1. **Right-sizing**: Use appropriate instance types per environment
2. **Backup Management**: Configure appropriate retention periods
3. **Monitoring**: Set up billing alerts
4. **Scheduling**: Consider stopping dev instances during non-work hours (manual)

## Post-Execution Validation

### ✅ Success Checklist
- [ ] Ansible execution completed without failed tasks
- [ ] DB Subnet Group created and spans multiple AZs
- [ ] Aurora cluster status = 'available'
- [ ] Writer instance status = 'available' in first AZ
- [ ] Reader instance status = 'available' in second AZ
- [ ] Cluster endpoints are accessible via DNS
- [ ] Security groups properly associated
- [ ] All resources properly tagged
- [ ] Database connection details documented

### 📝 Document Your Execution
Create execution log in `executions/dev/` directory:

```bash
# Gather Aurora cluster details for documentation
CLUSTER_DETAILS=$(aws rds describe-db-clusters --db-cluster-identifier cf-aurora-pg-cluster-dev --profile svktek --region us-west-1 --query 'DBClusters[0].[DBClusterIdentifier,Status,Endpoint,ReaderEndpoint,DatabaseName,MasterUsername,Port]' --output text)
INSTANCE_DETAILS=$(aws rds describe-db-instances --profile svktek --region us-west-1 --query 'DBInstances[?starts_with(DBInstanceIdentifier, `cf-aurora-pg`) && contains(DBInstanceIdentifier, `dev`)].[DBInstanceIdentifier,DBInstanceStatus,DBInstanceClass,AvailabilityZone]' --output text)

# Create execution log
cat > executions/dev/aurora-cluster-execution-$(date +%Y-%m-%d).md << EOF
# Aurora Cluster Execution Log

**Date**: $(date)
**Environment**: dev
**Executed By**: [Your Name]
**Status**: SUCCESS

## Aurora Cluster Details
$CLUSTER_DETAILS

## Aurora Instances
$INSTANCE_DETAILS

## Connection Information
- **Writer Endpoint**: $(echo $CLUSTER_DETAILS | cut -f3)
- **Reader Endpoint**: $(echo $CLUSTER_DETAILS | cut -f4)
- **Database Name**: $(echo $CLUSTER_DETAILS | cut -f5)
- **Username**: $(echo $CLUSTER_DETAILS | cut -f6)
- **Port**: $(echo $CLUSTER_DETAILS | cut -f7)

## High Availability Configuration
- **Multi-AZ**: Yes (writer in us-west-1a, reader in us-west-1c)
- **Automatic Failover**: Enabled
- **Backup Retention**: 7 days
- **Backup Window**: 07:00-09:00 UTC
- **Maintenance Window**: sun:05:00-sun:06:00 UTC

## Security Configuration
- **VPC**: vpc-0642a6fba47ae2a28
- **Subnets**: Private subnets only
- **Security Group**: cf-aurora-db-sg-dev
- **Publicly Accessible**: No
- **Deletion Protection**: No (development environment)

## Monthly Cost Estimate
- Writer Instance: ~\$30
- Reader Instance: ~\$30  
- Storage: ~\$5-10 (depends on usage)
- **Total**: ~\$65-70/month

## Post-Deployment Tasks
- [ ] Test database connectivity from applications
- [ ] Create application databases and users
- [ ] Configure monitoring and alerting
- [ ] Set up backup verification
- [ ] Document connection strings for applications

## Execution Time
Start: [timestamp]
End: [timestamp]
Duration: ~15 minutes

## Notes
- Aurora cluster deployed successfully with multi-AZ configuration
- Cross-VPC access configured for ROSA integration
- Database ready for application deployment
- Consider enabling Performance Insights for production workloads
EOF
```

## Clean Up (If Needed)

⚠️ **WARNING**: This will destroy the Aurora database and all data

```bash
# Delete in correct order to avoid dependency issues
# 1. Delete Aurora instances first
WRITER_ID="cf-aurora-pg-writer-dev"
READER_ID="cf-aurora-pg-reader-dev"
CLUSTER_ID="cf-aurora-pg-cluster-dev"

echo "Deleting Aurora instances..."
aws rds delete-db-instance --db-instance-identifier $WRITER_ID --skip-final-snapshot --profile svktek --region us-west-1
aws rds delete-db-instance --db-instance-identifier $READER_ID --skip-final-snapshot --profile svktek --region us-west-1

# Wait for instances to be deleted
echo "Waiting for instances to be deleted..."
aws rds wait db-instance-deleted --db-instance-identifier $WRITER_ID --profile svktek --region us-west-1
aws rds wait db-instance-deleted --db-instance-identifier $READER_ID --profile svktek --region us-west-1

# 2. Delete Aurora cluster
echo "Deleting Aurora cluster..."
aws rds delete-db-cluster --db-cluster-identifier $CLUSTER_ID --skip-final-snapshot --profile svktek --region us-west-1

# 3. Delete DB subnet group
echo "Deleting DB subnet group..."
aws rds delete-db-subnet-group --db-subnet-group-name cf-private-db-subnet-group-dev --profile svktek --region us-west-1
```

## Next Steps

✅ **Aurora Cluster Task Complete!**

Your Aurora PostgreSQL database is now fully operational with high availability across multiple zones. The database infrastructure is complete and ready for applications. 

For complete infrastructure deployment, proceed to:

**[Full Role Execution](06-full-role-execution.md)** - Execute all components together, or start using your database!

## Key Takeaways

- ✅ Aurora provides managed PostgreSQL with automatic failover
- ✅ Multi-AZ deployment ensures high availability and durability
- ✅ Private subnet deployment enhances security
- ✅ Cross-VPC security groups enable ROSA cluster connectivity
- ✅ Proper tagging enables resource management and cost tracking
- ✅ Automated backups provide point-in-time recovery capabilities

Your Aurora PostgreSQL cluster is now ready to support applications running in ROSA clusters across different VPCs, providing a robust, scalable, and secure database foundation.