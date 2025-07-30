# Security Groups Task Execution

## Overview
This guide walks you through executing the security groups task, which creates cross-VPC security groups to allow ROSA clusters in other VPCs to access the Aurora PostgreSQL database.

## Prerequisites

### ✅ Pre-execution Checklist
- [ ] Private subnets and NAT Gateway tasks completed successfully
- [ ] VPC vpc-0642a6fba47ae2a28 exists and is available
- [ ] AWS CLI configured with 'svktek' profile
- [ ] You have EC2 permissions for Security Group creation and rule management

### 🔍 Verify Prerequisites
```bash
# 1. Verify VPC exists
aws ec2 describe-vpcs --vpc-ids vpc-0642a6fba47ae2a28 --profile svktek --region us-west-1 --query 'Vpcs[*].[VpcId,State]' --output table
# Expected: VPC in 'available' state

# 2. Check existing security groups (to avoid naming conflicts)
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-0642a6fba47ae2a28" --profile svktek --region us-west-1 --query 'SecurityGroups[*].[GroupId,GroupName,Description]' --output table
# Expected: List of current security groups

# 3. Verify environment configuration includes security group settings
cat environments/dev/cf-db.yml | grep -A 15 security_group
# Expected: Should show security group configuration with CIDR blocks
```

## Execution Steps

### Step 1: Syntax Validation
```bash
# Navigate to project root
cd /path/to/your/ansible/project

# Validate playbook syntax
ansible-playbook playbooks/main.yml --syntax-check
# Expected: "playbook: playbooks/main.yml"
```

### Step 2: Dry Run (Check Mode)
```bash
# Execute in check mode to see what would be created
ansible-playbook playbooks/main.yml -t security-groups --check -v
```

**Expected Output Pattern:**
```
TASK [cf-db : Validate VPC exists for security group creation] *****************
ok: [localhost]

TASK [cf-db : Create Security Group for Aurora DB (Cross-VPC Access)] **********
changed: [localhost]

TASK [cf-db : Add OpenShift security group rule (if available)] ****************
skipping: [localhost]

TASK [cf-db : Display Aurora security group information] ***********************
ok: [localhost] => {
    "msg": [
        "Created Aurora DB security group with ID: sg-xxxxxxxxx",
        "Security group allows cross-VPC access from:",
        "  - Current VPC CIDR: 10.0.0.0/16",
        "  - ROSA cluster VPC CIDR: 172.16.0.0/16",
        "  - Additional VPC CIDR: 192.168.0.0/16",
        "  - OpenShift security group: Not configured (optional)"
    ]
}
```

### Step 3: Execute Security Groups Task
```bash
# Execute the security groups task
ansible-playbook playbooks/main.yml -t security-groups -v
```

**💡 What to Watch For:**
- Security group creation should complete quickly (< 1 minute)
- Rules should be added for each CIDR block specified
- OpenShift security group rule may be skipped if not configured
- All tasks should show `ok` or `changed` status

### Step 4: Monitor Progress (Optional)
```bash
# In a separate terminal, monitor security group creation
watch "aws ec2 describe-security-groups --filters 'Name=tag:Component,Values=Database' 'Name=tag:Environment,Values=dev' --profile svktek --region us-west-1 --query 'SecurityGroups[*].[GroupId,GroupName,Description]' --output table"

# Monitor security group rules
watch "aws ec2 describe-security-groups --filters 'Name=group-name,Values=cf-aurora-db-sg-dev' --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[*].CidrIp]' --output table"
```

## Expected Results

### ✅ Successful Execution Output
```
PLAY RECAP *********************************************************
localhost                  : ok=8    changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### 📊 Expected AWS Resources Created

#### 1. Security Group
```bash
aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'SecurityGroups[*].[GroupId,GroupName,Description,VpcId]' --output table
```

**Expected Output:**
```
--------------------------------------------------------------------------------------
|                               DescribeSecurityGroups                             |
+---------------------+---------------------+----------------------------------+----+
|  sg-04d00fe7bd9d... |  cf-aurora-db-sg-dev|  Aurora DB Security Group for...|vpc-|
+---------------------+---------------------+----------------------------------+----+
```

#### 2. Security Group Rules
```bash
aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[*].CidrIp,IpRanges[*].Description]' --output table
```

**Expected Output:**
```
-----------------------------------------------------------------------------------------
|                                DescribeSecurityGroups                                |
+-----+------+------+------------------------------------------------------------+-----+
| tcp |  5432|  5432|  10.0.0.0/16                                              |Allow|
| tcp |  5432|  5432|  172.16.0.0/16                                            |Allow|
| tcp |  5432|  5432|  192.168.0.0/16                                           |Allow|
+-----+------+------+------------------------------------------------------------+-----+
```

#### 3. Egress Rules
```bash
aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissionsEgress[*].[IpProtocol,IpRanges[*].CidrIp]' --output table
```

**Expected Output:**
```
-----------------------------------------------
|          DescribeSecurityGroups            |
+------+-------------------------------------+
|  -1  |  0.0.0.0/0                         |
+------+-------------------------------------+
```

### 🏷️ Verify Resource Tagging
```bash
# Check security group tags
aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].Tags' --output json
```

**Expected Tags:**
- Name: cf-aurora-db-sg-dev
- Environment: dev
- Project: ConsultingFirm
- Component: Database
- ManagedBy: Ansible

## Verification Steps

### 1. Security Group Existence Verification
```bash
# Verify security group was created
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].GroupId' --output text)
echo "Security Group ID: $SG_ID"
# Expected: Should show security group ID (sg-xxxxxxxxx)
```

### 2. Ingress Rules Verification
```bash
# Count ingress rules
RULE_COUNT=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'length(SecurityGroups[0].IpPermissions)')
echo "Ingress rules count: $RULE_COUNT"
# Expected: 3 (one for each CIDR block)
```

### 3. Port and Protocol Verification
```bash
# Verify PostgreSQL port access
aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort,IpProtocol]' --output table
# Expected: All rules should show port 5432 and TCP protocol
```

### 4. CIDR Block Verification  
```bash
# Verify all expected CIDR blocks are included
aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[*].IpRanges[*].CidrIp' --output text
# Expected: Should show 10.0.0.0/16 172.16.0.0/16 192.168.0.0/16
```

## Troubleshooting

### ❌ Common Issues and Solutions

#### 1. Security Group Name Already Exists
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "InvalidGroup.Duplicate: The security group 'cf-aurora-db-sg-dev' already exists"}
```

**Solution:**
```bash
# Check existing security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1

# If it exists, the task should be idempotent. Check for configuration differences
# Or delete existing group if safe to recreate:
# aws ec2 delete-security-group --group-name cf-aurora-db-sg-dev --profile svktek --region us-west-1
```

#### 2. VPC Not Found
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "InvalidVpcID.NotFound: The vpc ID 'vpc-0642a6fba47ae2a28' does not exist"}
```

**Solution:**
```bash
# Verify VPC exists
aws ec2 describe-vpcs --profile svktek --region us-west-1

# Update configuration with correct VPC ID
nano defaults/main.yml
# Update cf_db_vpc_defaults.vpc_id
```

#### 3. Invalid CIDR Block
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "InvalidParameterValue: Invalid CIDR block"}
```

**Solution:**
```bash
# Verify CIDR blocks in configuration
cat environments/dev/cf-db.yml | grep -A 10 allowed_cidrs

# Ensure CIDR blocks are valid format (x.x.x.x/xx)
# Update environment configuration if needed
nano environments/dev/cf-db.yml
```

#### 4. Permission Denied
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "UnauthorizedOperation: You are not authorized to perform this operation"}
```

**Solution:**
```bash
# Test EC2 security group permissions
aws ec2 describe-security-groups --profile svktek

# Verify IAM permissions include:
# - ec2:CreateSecurityGroup
# - ec2:AuthorizeSecurityGroupIngress
# - ec2:DescribeSecurityGroups
```

### 🔧 Debug Commands

```bash
# Run with maximum verbosity
ansible-playbook playbooks/main.yml -t security-groups -vvv

# Test only validation tasks
ansible-playbook playbooks/main.yml -t security-groups,validation --check

# Check specific security group details
aws ec2 describe-security-groups --group-ids sg-04d00fe7bd9d27fe2 --profile svktek --region us-west-1
```

## Cross-VPC Access Testing

### 🔬 Connectivity Verification

#### 1. Test from Different CIDR Ranges
```bash
# From current VPC (10.0.0.0/16) - Should work
# From ROSA cluster VPC (172.16.0.0/16) - Should work  
# From additional VPC (192.168.0.0/16) - Should work
# From any other range - Should be blocked

# Example test (when Aurora database is deployed):
# telnet aurora-endpoint.region.rds.amazonaws.com 5432
```

#### 2. Security Group Rule Analysis
```bash
# Analyze security group effectiveness
aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[*].CidrIp,IpRanges[*].Description]' --output json | jq '.'
```

## Post-Execution Validation

### ✅ Success Checklist
- [ ] Ansible execution completed without failed tasks
- [ ] Security group created in correct VPC
- [ ] 3 ingress rules created for CIDR blocks (10.0.0.0/16, 172.16.0.0/16, 192.168.0.0/16)
- [ ] All rules allow TCP port 5432 (PostgreSQL)
- [ ] Egress rule allows all outbound traffic (0.0.0.0/0)
- [ ] Proper tags applied to security group
- [ ] OpenShift security group rule skipped (optional)

### 📝 Document Your Execution
Create execution log in `executions/dev/` directory:

```bash
# Get security group details for documentation  
SG_INFO=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].[GroupId,GroupName]' --output text)

# Create execution log
cat > executions/dev/security-groups-execution-$(date +%Y-%m-%d).md << EOF
# Security Groups Execution Log

**Date**: $(date)
**Environment**: dev
**Executed By**: [Your Name]
**Status**: SUCCESS

## Resources Created
- **Security Group**: ${SG_INFO}
- **Ingress Rules**: 3 rules for cross-VPC access
  - 10.0.0.0/16 → TCP 5432 (Current VPC)
  - 172.16.0.0/16 → TCP 5432 (ROSA Cluster VPC)
  - 192.168.0.0/16 → TCP 5432 (Additional VPC)
- **Egress Rules**: Allow all outbound (0.0.0.0/0)

## Cross-VPC Access Configuration
- Aurora database will be accessible from ROSA clusters
- Secure access limited to specified CIDR ranges
- PostgreSQL port (5432) specifically allowed

## Execution Time
Start: [timestamp]
End: [timestamp]
Duration: ~1 minute

## Notes
- Security group ready for Aurora database deployment
- Cross-VPC access configured for ROSA integration
- OpenShift security group rule skipped (not configured)
- Ready for Aurora Cluster task
EOF
```

## Clean Up (If Needed)

⚠️ **Only if you need to remove the security group:**

```bash
# Get security group ID
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].GroupId' --output text)

# Delete security group (WARNING: This will remove access control)
echo "Deleting security group: $SG_ID"
aws ec2 delete-security-group --group-id $SG_ID --profile svktek --region us-west-1
```

## Security Considerations

### 🔒 Security Best Practices Applied
- ✅ **Principle of Least Privilege**: Only PostgreSQL port (5432) allowed
- ✅ **Network Segmentation**: Specific CIDR blocks defined
- ✅ **Default Deny**: Only specified sources can access
- ✅ **Egress Control**: Outbound traffic allowed for database operations

### 🛡️ Additional Security Recommendations
- Consider using more specific CIDR blocks for production
- Implement VPC Flow Logs for traffic monitoring
- Use AWS Security Groups as additional defense layer
- Regular security group rule auditing

## Next Steps

✅ **Security Groups Task Complete!**

Cross-VPC access control is now configured for your Aurora database. The security infrastructure is ready for the database deployment. Proceed to:

**[Aurora Cluster Execution](05-aurora-cluster-execution.md)** - Deploy the Aurora PostgreSQL database cluster.

## Key Takeaways

- ✅ Security groups provide stateful firewall rules at the instance level
- ✅ Cross-VPC access enables ROSA clusters to connect to Aurora database
- ✅ Specific port and protocol restrictions enhance security
- ✅ CIDR-based rules provide network-level access control
- ✅ Proper tagging enables security group management and auditing

The security groups create a secure access boundary that allows authorized ROSA clusters to connect to your Aurora database while blocking unauthorized access.