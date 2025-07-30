# NAT Gateway Task Execution

## Overview
This guide walks you through executing the NAT Gateway task, which provides internet access for private subnets and configures routing for Aurora PostgreSQL database.

## Prerequisites

### ✅ Pre-execution Checklist
- [ ] Private subnets task completed successfully
- [ ] Public subnet subnet-021b476409dfe66ba exists and is available
- [ ] AWS CLI configured with 'svktek' profile
- [ ] You have EC2 permissions for NAT Gateway, EIP, and Route Table creation

### 🔍 Verify Prerequisites
```bash
# 1. Verify private subnets exist (from previous task)
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,State]' --output table
# Expected: 2 subnets in 'available' state

# 2. Verify public subnet exists for NAT Gateway
aws ec2 describe-subnets --subnet-ids subnet-021b476409dfe66ba --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,State,MapPublicIpOnLaunch]' --output table  
# Expected: Subnet exists, available, and has public IP mapping

# 3. Check current EIP quota and usage
aws ec2 describe-account-attributes --attribute-names default-vpc --profile svktek --region us-west-1
# Expected: Should show account attributes without errors
```

## Execution Steps

### Step 1: Verify Dependencies
```bash
# Check if private subnet IDs are available (should be from previous task)
ansible-playbook playbooks/main.yml -t nat-gateway --check -v | grep "private_subnet_ids"
# Expected: Should show private subnet IDs from previous task execution
```

### Step 2: Dry Run (Check Mode)
```bash
# Execute in check mode to see what would be created
ansible-playbook playbooks/main.yml -t nat-gateway --check -v
```

**Expected Output Pattern:**
```
TASK [cf-db : Check if private subnet IDs are available] ***********************
ok: [localhost]

TASK [cf-db : Validate private subnet dependencies] ****************************
ok: [localhost] => {
    "msg": "Private subnet dependencies satisfied."
}

TASK [cf-db : Validate public subnet exists for NAT Gateway] *******************
ok: [localhost]

TASK [cf-db : Allocate Elastic IP for NAT Gateway] *****************************
changed: [localhost]

TASK [cf-db : Create NAT Gateway in public subnet] *****************************
changed: [localhost]

TASK [cf-db : Create route table for private subnets with NAT Gateway route] ***
changed: [localhost]
```

### Step 3: Execute NAT Gateway Task
```bash
# Execute the NAT Gateway task
ansible-playbook playbooks/main.yml -t nat-gateway -v
```

**💡 What to Watch For:**
- EIP allocation should complete quickly (1-30 seconds)
- NAT Gateway creation takes 3-5 minutes
- Route table creation and association should complete quickly
- All tasks should show `ok` or `changed` status

### Step 4: Monitor Progress (Optional)
```bash
# In a separate terminal, monitor NAT Gateway creation
watch "aws ec2 describe-nat-gateways --filter 'Name=tag:Environment,Values=dev' --profile svktek --region us-west-1 --query 'NatGateways[*].[NatGatewayId,State,SubnetId,NatGatewayAddresses[0].PublicIp]' --output table"

# Monitor route table creation
watch "aws ec2 describe-route-tables --filters 'Name=tag:Environment,Values=dev' 'Name=tag:Component,Values=Database' --profile svktek --region us-west-1 --query 'RouteTables[*].[RouteTableId,Routes[?DestinationCidrBlock==\`0.0.0.0/0\`].NatGatewayId|[0]]' --output table"
```

## Expected Results

### ✅ Successful Execution Output
```
PLAY RECAP *********************************************************
localhost                  : ok=12   changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 📊 Expected AWS Resources Created

#### 1. Elastic IP
```bash
aws ec2 describe-addresses --filters "Name=tag:Environment,Values=dev" "Name=tag:Purpose,Values=NAT Gateway" --profile svktek --region us-west-1 --query 'Addresses[*].[PublicIp,AllocationId,AssociationId]' --output table
```

**Expected Output:**
```
-------------------------------------------------------
|                DescribeAddresses                   |
+----------------+------------------+-----------------+
|  3.101.xxx.xxx |  eipalloc-xxx... |  eipassoc-xxx...|
+----------------+------------------+-----------------+
```

#### 2. NAT Gateway
```bash
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[*].[NatGatewayId,State,SubnetId,NatGatewayAddresses[0].PublicIp]' --output table
```

**Expected Output:**
```
-------------------------------------------------------------------
|                       DescribeNatGateways                       |
+---------------------+-----------+-------------------+-----------+
|  nat-0a1b2c3d4e5f... |  available|  subnet-021b476...| 3.101...|
+---------------------+-----------+-------------------+-----------+
```

#### 3. Route Table
```bash
aws ec2 describe-route-tables --filters "Name=tag:Environment,Values=dev" "Name=tag:Purpose,Values=Private Subnet Routing" --profile svktek --region us-west-1 --query 'RouteTables[*].[RouteTableId,Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0],Associations[*].SubnetId]' --output table
```

**Expected Output:**
```
--------------------------------------------------------------------------------
|                            DescribeRouteTables                              |
+---------------------+---------------------+----------------------------------+
|  rtb-0a1b2c3d4e5f...|  nat-0a1b2c3d4e5f...|  subnet-0582b9..., subnet-0d63..|
+---------------------+---------------------+----------------------------------+
```

### 🏷️ Verify Resource Tagging
```bash
# Check NAT Gateway tags
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[*].Tags' --output json

# Check EIP tags  
aws ec2 describe-addresses --filters "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Addresses[*].Tags' --output json

# Check route table tags
aws ec2 describe-route-tables --filters "Name=tag:Environment,Values=dev" "Name=tag:Purpose,Values=Private Subnet Routing" --profile svktek --region us-west-1 --query 'RouteTables[*].Tags' --output json
```

## Verification Steps

### 1. Internet Connectivity Test
```bash
# Get NAT Gateway public IP
NAT_PUBLIC_IP=$(aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[0].NatGatewayAddresses[0].PublicIp' --output text)
echo "NAT Gateway Public IP: $NAT_PUBLIC_IP"
# Expected: Should show a public IP address
```

### 2. Route Table Association Verification
```bash
# Verify private subnets are associated with the route table
aws ec2 describe-route-tables --filters "Name=tag:Environment,Values=dev" "Name=tag:Purpose,Values=Private Subnet Routing" --profile svktek --region us-west-1 --query 'RouteTables[*].Associations[*].[SubnetId,Main]' --output table
# Expected: Should show both private subnet IDs with Main=false
```

### 3. Default Route Verification
```bash
# Verify default route points to NAT Gateway
aws ec2 describe-route-tables --filters "Name=tag:Environment,Values=dev" "Name=tag:Purpose,Values=Private Subnet Routing" --profile svktek --region us-west-1 --query 'RouteTables[*].Routes[?DestinationCidrBlock==`0.0.0.0/0`].[NatGatewayId,State]' --output table
# Expected: Should show NAT Gateway ID with State=active
```

## Troubleshooting

### ❌ Common Issues and Solutions

#### 1. EIP Allocation Limit Exceeded
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "AddressLimitExceeded: The maximum number of addresses has been reached"}
```

**Solution:**
```bash
# Check current EIP usage
aws ec2 describe-addresses --profile svktek --region us-west-1 --query 'length(Addresses)'

# Release unused EIPs or request limit increase
aws ec2 describe-addresses --filters "Name=association-id,Values=" --profile svktek --region us-west-1
# These are unassociated EIPs that can be released
```

#### 2. Public Subnet Not Found
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "Public subnet subnet-021b476409dfe66ba not found"}
```

**Solution:**
```bash
# Verify public subnet exists
aws ec2 describe-subnets --profile svktek --region us-west-1 --query 'Subnets[?MapPublicIpOnLaunch==`true`].[SubnetId,CidrBlock,AvailabilityZone]' --output table

# Update configuration with correct public subnet ID
nano defaults/main.yml
# Update cf_db_vpc_defaults.public_subnet_id
```

#### 3. NAT Gateway Creation Timeout
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "Timeout waiting for NAT Gateway to become available"}
```

**Solution:**
```bash
# Check NAT Gateway status manually
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1

# If state is 'pending', wait longer or increase timeout in task
# If state is 'failed', check AWS service health dashboard
```

#### 4. Route Table Association Failures
**Error:**
```
fatal: [localhost]: FAILED! => {"msg": "Route table association failed"}
```

**Solution:**
```bash
# Check if subnets are already associated with another route table
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-0582b9dea4735e4ef" --profile svktek --region us-west-1

# If associated, the task should handle this automatically due to idempotency
```

### 🔧 Debug Commands

```bash
# Run with dependency resolution debug
ansible-playbook playbooks/main.yml -t nat-gateway -vvv --start-at-task "Get private subnet IDs"

# Test only validation tasks
ansible-playbook playbooks/main.yml -t nat-gateway,validation --check

# Check NAT Gateway connectivity from AWS side
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxxxxxx --profile svktek --region us-west-1
```

## Cost Implications

### 💰 Monthly Costs (Approximate)
- **NAT Gateway**: ~$45/month (24/7 operation)
- **Elastic IP**: ~$3.65/month (when associated)
- **Data Transfer**: $0.045 per GB processed

### 💡 Cost Optimization Tips
1. **Development**: Consider shutting down NAT Gateway after hours
2. **Monitoring**: Track data transfer usage
3. **Alternatives**: For dev, consider using NAT instances for lower cost

## Post-Execution Validation

### ✅ Success Checklist
- [ ] Ansible execution completed without failed tasks
- [ ] Elastic IP allocated and available
- [ ] NAT Gateway created and in 'available' state
- [ ] Route table created with default route to NAT Gateway
- [ ] Private subnets associated with the route table
- [ ] All resources properly tagged

### 📝 Document Your Execution
Create execution log in `executions/dev/` directory:

```bash
# Get resource details for documentation
EIP_INFO=$(aws ec2 describe-addresses --filters "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Addresses[0].[PublicIp,AllocationId]' --output text)
NAT_INFO=$(aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[0].[NatGatewayId,State]' --output text)

# Create execution log
cat > executions/dev/nat-gateway-execution-$(date +%Y-%m-%d).md << EOF
# NAT Gateway Execution Log

**Date**: $(date)
**Environment**: dev
**Executed By**: [Your Name]
**Status**: SUCCESS

## Resources Created
- **Elastic IP**: ${EIP_INFO}
- **NAT Gateway**: ${NAT_INFO}
- **Route Table**: Created with default route to NAT Gateway

## Execution Time
Start: [timestamp]
End: [timestamp]
Duration: ~5 minutes

## Monthly Cost Estimate
- NAT Gateway: ~\$45
- Elastic IP: ~\$3.65
- Total: ~\$48.65/month

## Notes
- NAT Gateway provides internet access for private subnets
- Route table configured for both private subnets
- Ready for Security Groups task
EOF
```

## Clean Up (If Needed)

⚠️ **Only if you need to remove the NAT Gateway infrastructure:**

```bash
# Get resource IDs
NAT_GW_ID=$(aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[0].NatGatewayId' --output text)
RT_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Environment,Values=dev" "Name=tag:Purpose,Values=Private Subnet Routing" --profile svktek --region us-west-1 --query 'RouteTables[0].RouteTableId' --output text)
EIP_ALLOC=$(aws ec2 describe-addresses --filters "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Addresses[0].AllocationId' --output text)

# Delete in reverse order
echo "Deleting NAT Gateway: $NAT_GW_ID"
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --profile svktek --region us-west-1

# Wait for NAT Gateway deletion (takes several minutes)
echo "Waiting for NAT Gateway deletion..."
aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_GW_ID --profile svktek --region us-west-1

echo "Deleting Route Table: $RT_ID"
aws ec2 delete-route-table --route-table-id $RT_ID --profile svktek --region us-west-1

echo "Releasing Elastic IP: $EIP_ALLOC"
aws ec2 release-address --allocation-id $EIP_ALLOC --profile svktek --region us-west-1
```

## Next Steps

✅ **NAT Gateway Task Complete!**

Your private subnets now have internet access through the NAT Gateway. The infrastructure is ready for the next component. Proceed to:

**[Security Groups Execution](04-security-groups-execution.md)** - Configure cross-VPC access control for the Aurora database.

## Key Takeaways

- ✅ NAT Gateway enables secure internet access from private subnets
- ✅ Route tables control traffic flow and internet routing
- ✅ Elastic IPs provide stable public addresses for NAT Gateways
- ✅ Proper tagging enables cost tracking and resource management
- ✅ Dependencies are automatically resolved when running tasks independently

The NAT Gateway infrastructure enables your Aurora database instances to access the internet for updates and patches while remaining in secure private subnets.