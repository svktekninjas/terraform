# Private Subnets Task Execution

## Overview
This guide walks you through executing the private subnets task, which creates multi-AZ private subnets for the Aurora PostgreSQL database.

## Prerequisites

### ✅ Pre-execution Checklist
- [ ] Role implementation completed (following docs/04-private-subnets-task.md)
- [ ] AWS CLI configured with 'svktek' profile
- [ ] Environment configuration files created
- [ ] VPC vpc-0642a6fba47ae2a28 exists and is available
- [ ] You have EC2 permissions for subnet creation

### 🔍 Verify Prerequisites
```bash
# 1. Check VPC exists
aws ec2 describe-vpcs --vpc-ids vpc-0642a6fba47ae2a28 --profile svktek --region us-west-1
# Expected: Should return VPC details with State: available

# 2. Check existing subnets (to avoid CIDR conflicts)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0642a6fba47ae2a28" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table
# Expected: List of current subnets to ensure no CIDR conflicts

# 3. Verify environment configuration
cat environments/dev/cf-db.yml | grep -A 10 private_subnets
# Expected: Should show CIDR blocks 10.0.2.0/24 and 10.0.3.0/24
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
ansible-playbook playbooks/main.yml -t private-subnets --check -v
```

**Expected Output Pattern:**
```
PLAY [ROSA Infrastructure Setup] ***********************************************

TASK [Gathering Facts] *********************************************************
ok: [localhost]

TASK [cf-db : Load environment-specific configuration] *************************
ok: [localhost]

TASK [cf-db : Create private subnets] ******************************************
included: /path/to/roles/cf-db/tasks/private_subnets.yml for localhost

TASK [cf-db : Validate VPC exists for subnet creation] *************************
ok: [localhost]

TASK [cf-db : Ensure VPC exists] ***********************************************
ok: [localhost] => {
    "msg": "VPC vpc-0642a6fba47ae2a28 is available for subnet creation"
}

TASK [cf-db : Create private subnets for Aurora database (Multi-AZ)] ***********
changed: [localhost] => (item={'cidr': '10.0.2.0/24', 'az': 'us-west-1a', 'name': 'cf-private-subnet-dev-1a'})
changed: [localhost] => (item={'cidr': '10.0.3.0/24', 'az': 'us-west-1c', 'name': 'cf-private-subnet-dev-1c'})
```

### Step 3: Execute Private Subnets Task
```bash
# Execute the private subnets task
ansible-playbook playbooks/main.yml -t private-subnets -v
```

**💡 What to Watch For:**
- All tasks should show `ok` or `changed` status
- No `failed` tasks in the output
- Two subnets should be created (one per AZ)

### Step 4: Monitor AWS Console (Optional)
```bash
# In a separate terminal, watch subnet creation in real-time
watch "aws ec2 describe-subnets --filters 'Name=vpc-id,Values=vpc-0642a6fba47ae2a28' 'Name=tag:Component,Values=Database' --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,State,CidrBlock,AvailabilityZone,Tags[?Key==\`Name\`].Value|[0]]' --output table"
```

## Expected Results

### ✅ Successful Execution Output
```
PLAY RECAP *********************************************************
localhost                  : ok=8    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 📊 Expected AWS Resources Created
```bash
# Verify subnets were created
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,State,Tags[?Key==`Name`].Value|[0]]' --output table
```

**Expected Output:**
```
----------------------------------------------------------------------------------
|                               DescribeSubnets                                |
+----------------------+-------------+-------------+-----------+-------------------------+
|  subnet-0582b9dea... |  10.0.2.0/24|  us-west-1a |  available|  cf-private-subnet-dev-1a|
|  subnet-0d6347b494.. |  10.0.3.0/24|  us-west-1c |  available|  cf-private-subnet-dev-1c|
+----------------------+-------------+-------------+-----------+-------------------------+
```

### 🏷️ Verify Resource Tagging
```bash
# Check tags on created subnets
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" --profile svktek --region us-west-1 --query 'Subnets[*].Tags' --output json
```

**Expected Tags:**
- Name: cf-private-subnet-dev-1a / cf-private-subnet-dev-1c  
- Environment: dev
- Project: ConsultingFirm
- Component: Database
- ManagedBy: Ansible
- Purpose: Aurora Database
- Tier: Private

## Verification Steps

### 1. Subnet Count Verification
```bash
# Count created subnets
SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'length(Subnets)')
echo "Created subnets: $SUBNET_COUNT"
# Expected: 2
```

### 2. Multi-AZ Verification
```bash
# Verify subnets span multiple AZs
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].AvailabilityZone' --output text
# Expected: us-west-1a us-west-1c (or similar multi-AZ spread)
```

### 3. CIDR Block Verification
```bash
# Verify CIDR blocks are correct
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].[CidrBlock,AvailabilityZone]' --output table
# Expected: 10.0.2.0/24 and 10.0.3.0/24 in different AZs
```

## Troubleshooting

### ❌ Common Issues and Solutions

#### 1. CIDR Block Conflicts
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "The CIDR '10.0.2.0/24' conflicts with another subnet"}
```

**Solution:**
```bash
# Check existing subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0642a6fba47ae2a28" --profile svktek --region us-west-1 --query 'Subnets[*].CidrBlock'

# Update environment configuration with non-conflicting CIDR blocks
nano environments/dev/cf-db.yml
# Change CIDR blocks to available ranges (e.g., 10.0.8.0/24, 10.0.9.0/24)
```

#### 2. VPC Not Found
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "VPC vpc-0642a6fba47ae2a28 not found"}
```

**Solution:**
```bash
# Verify VPC exists
aws ec2 describe-vpcs --profile svktek --region us-west-1

# Update defaults/main.yml with correct VPC ID
nano defaults/main.yml
# Update cf_db_vpc_defaults.vpc_id with correct VPC ID
```

#### 3. Permission Denied
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "An error occurred (UnauthorizedOperation)"}
```

**Solution:**
```bash
# Test EC2 permissions
aws ec2 describe-vpcs --profile svktek
# If this fails, check AWS credentials and IAM permissions

# Verify profile configuration
aws configure list --profile svktek
```

#### 4. Availability Zone Issues
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "Invalid availability zone: us-west-1b"}
```

**Solution:**
```bash
# Check available AZs in region
aws ec2 describe-availability-zones --region us-west-1 --profile svktek

# Update environment configuration with valid AZs
nano environments/dev/cf-db.yml
```

### 🔧 Debug Commands

```bash
# Run with maximum verbosity
ansible-playbook playbooks/main.yml -t private-subnets -vvv

# Check specific task
ansible-playbook playbooks/main.yml -t private-subnets --start-at-task "Create private subnets"

# Validate only (skip execution)
ansible-playbook playbooks/main.yml -t private-subnets,validation --check
```

## Post-Execution Validation

### ✅ Success Checklist
- [ ] Ansible execution completed without failed tasks
- [ ] 2 private subnets created across different AZs
- [ ] Subnets are in 'available' state
- [ ] Correct CIDR blocks assigned (10.0.2.0/24, 10.0.3.0/24)
- [ ] Proper tags applied to all resources
- [ ] Subnets are in correct VPC (vpc-0642a6fba47ae2a28)

### 📝 Document Your Execution
Create execution log in `executions/dev/` directory:

```bash
# Create execution log
cat > executions/dev/private-subnets-execution-$(date +%Y-%m-%d).md << EOF
# Private Subnets Execution Log

**Date**: $(date)
**Environment**: dev
**Executed By**: [Your Name]
**Status**: SUCCESS

## Resources Created
$(aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table)

## Execution Time
Start: [timestamp]
End: [timestamp]
Duration: ~2 minutes

## Notes
- All subnets created successfully
- Multi-AZ deployment confirmed
- Ready for NAT Gateway task
EOF
```

## Clean Up (If Needed)

⚠️ **Only if you need to remove the subnets:**

```bash
# Get subnet IDs
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].SubnetId' --output text)

# Delete subnets (WARNING: This will remove the infrastructure)
for subnet_id in $SUBNET_IDS; do
    echo "Deleting subnet: $subnet_id"
    aws ec2 delete-subnet --subnet-id $subnet_id --profile svktek --region us-west-1
done
```

## Next Steps

✅ **Private Subnets Task Complete!**

The private subnets are now created and ready for the next component. Proceed to:

**[NAT Gateway Execution](03-nat-gateway-execution.md)** - Set up internet access and routing for the private subnets.

## Key Takeaways

- ✅ Multi-AZ private subnets provide high availability
- ✅ Proper tagging enables resource management and cost tracking  
- ✅ CIDR planning prevents network conflicts
- ✅ Validation at each step ensures deployment success

The private subnets form the foundation for your Aurora database deployment by providing isolated, secure network segments across multiple availability zones.