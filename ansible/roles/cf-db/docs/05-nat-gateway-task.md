# Step 5: NAT Gateway Task Implementation

## Overview
This guide walks you through creating the NAT Gateway task that provides internet access for private subnets and configures routing for the Aurora PostgreSQL database infrastructure.

## Prerequisites
- Completed Step 4 (Private Subnets Task)
- Understanding of AWS NAT Gateway and Route Tables
- Knowledge of dependency handling in Ansible

## Step 5.1: Understanding NAT Gateway Task

### What This Task Does
- Creates Elastic IP for NAT Gateway
- Deploys NAT Gateway in public subnet
- Creates route table for private subnets
- Associates private subnets with the route table
- Enables internet access from private subnets

### AWS Resources Created
- 1x Elastic IP (EIP)
- 1x NAT Gateway
- 1x Route Table with routes
- Route table associations

### Task Dependencies
- **Requires**: `private_subnet_ids` from private subnets task
- **Requires**: Existing public subnet
- **Provides**: Internet access for Aurora database

## Step 5.2: Create NAT Gateway Task File

Navigate to the tasks directory and create the NAT Gateway task:

```bash
cd roles/cf-db/tasks
nano nat_gateway.yml
```

### Section 1: Task Header and Dependencies

```yaml
---
# NAT Gateway Creation Tasks
# Dependencies: Requires private_subnet_ids from private_subnets.yml

- name: Check if private subnet IDs are available
  set_fact:
    private_subnet_ids: "{{ private_subnet_ids | default([]) }}"
  tags:
    - cf-db
    - nat-gateway
    - networking
```

**Explanation:**
- Documents task dependencies clearly
- Initializes private_subnet_ids if not already defined
- Enables independent task execution

### Section 2: Dependency Resolution

```yaml
- name: Get private subnet IDs if not available (dependency check)
  amazon.aws.ec2_vpc_subnet_info:
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    filters:
      "vpc-id": "{{ cf_db_config.vpc_id }}"
      "tag:Component": "Database"
      "tag:Environment": "{{ cf_db_config.common_tags.Environment }}"
  register: existing_private_subnets
  when: private_subnet_ids | length == 0
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Set private subnet IDs from existing subnets
  set_fact:
    private_subnet_ids: "{{ existing_private_subnets.subnets | map(attribute='subnet_id') | list }}"
  when: private_subnet_ids | length == 0 and existing_private_subnets.subnets is defined
  tags:
    - cf-db
    - nat-gateway
    - networking
```

**Explanation:**
- Resolves dependencies by querying existing resources
- Allows task to run independently if subnets already exist
- Filters by tags to find correct subnets

### Section 3: Dependency Validation

```yaml
- name: Validate private subnet dependencies
  assert:
    that:
      - private_subnet_ids is defined
      - private_subnet_ids | length > 0
    fail_msg: "NAT Gateway task requires private subnets to be created first. Run with tags: private-subnets,nat-gateway"
    success_msg: "Private subnet dependencies satisfied."
  tags:
    - cf-db
    - nat-gateway
    - networking
```

**Explanation:**
- Validates required dependencies exist
- Provides helpful error message with solution
- Ensures task prerequisites are met

### Section 4: Public Subnet Validation

```yaml
- name: Validate public subnet exists for NAT Gateway
  amazon.aws.ec2_vpc_subnet_info:
    subnet_ids:
      - "{{ cf_db_config.public_subnet_id }}"
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
  register: public_subnet_info
  tags:
    - cf-db
    - nat-gateway
    - networking
    - validation

- name: Ensure public subnet is available
  assert:
    that:
      - public_subnet_info.subnets | length > 0
      - public_subnet_info.subnets[0].state == 'available'
    fail_msg: "Public subnet {{ cf_db_config.public_subnet_id }} not found or not available"
    success_msg: "Public subnet {{ cf_db_config.public_subnet_id }} is available for NAT Gateway"
  tags:
    - cf-db
    - nat-gateway
    - networking
    - validation
```

**Explanation:**
- Validates public subnet exists for NAT Gateway placement
- Ensures subnet is in available state
- Prevents deployment failures

### Section 5: Allocate Elastic IP

```yaml
- name: Allocate Elastic IP for NAT Gateway
  amazon.aws.ec2_eip:
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    in_vpc: true
    state: present
    tags:
      Name: "cf-nat-eip-{{ cf_db_config.common_tags.Environment }}"
      Environment: "{{ cf_db_config.common_tags.Environment }}"
      Project: "{{ cf_db_config.common_tags.Project }}"
      Component: "{{ cf_db_config.common_tags.Component }}"
      ManagedBy: "{{ cf_db_config.common_tags.ManagedBy }}"
      Purpose: "NAT Gateway"
  register: eip
  tags:
    - cf-db
    - nat-gateway
    - networking
```

**Explanation:**
- Creates Elastic IP for NAT Gateway
- Uses VPC-specific EIP (in_vpc: true)
- Tags for proper resource management
- Registers result for NAT Gateway creation

### Section 6: Create NAT Gateway

```yaml
- name: Create NAT Gateway in public subnet
  amazon.aws.ec2_vpc_nat_gateway:
    subnet_id: "{{ cf_db_config.public_subnet_id }}"
    allocation_id: "{{ eip.allocation_id }}"
    state: present
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    wait: true
    wait_timeout: "{{ cf_db_timeouts.nat_gateway_timeout | default(600) }}"
    tags:
      Name: "cf-nat-gateway-{{ cf_db_config.common_tags.Environment }}"
      Environment: "{{ cf_db_config.common_tags.Environment }}"
      Project: "{{ cf_db_config.common_tags.Project }}"
      Component: "{{ cf_db_config.common_tags.Component }}"
      ManagedBy: "{{ cf_db_config.common_tags.ManagedBy }}"
      Purpose: "Database Internet Access"
  register: nat_gateway
  tags:
    - cf-db
    - nat-gateway
    - networking
```

**Explanation:**
- Creates NAT Gateway with allocated EIP
- Waits for completion with configurable timeout
- Comprehensive tagging for management
- Registers result for route table creation

### Section 7: Create Route Table with NAT Gateway Route

```yaml
- name: Create route table for private subnets with NAT Gateway route
  amazon.aws.ec2_vpc_route_table:
    vpc_id: "{{ cf_db_config.vpc_id }}"
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    routes:
      - dest: 0.0.0.0/0
        nat_gateway_id: "{{ nat_gateway.nat_gateway_id }}"
    subnets: "{{ private_subnet_ids }}"
    tags:
      Name: "{{ cf_db_config.route_table.name }}"
      Environment: "{{ cf_db_config.common_tags.Environment }}"
      Project: "{{ cf_db_config.common_tags.Project }}"
      Component: "{{ cf_db_config.common_tags.Component }}"
      ManagedBy: "{{ cf_db_config.common_tags.ManagedBy }}"
      Purpose: "Private Subnet Routing"
  register: private_route_table
  tags:
    - cf-db
    - nat-gateway
    - networking
```

**Explanation:**
- Creates route table with default route to NAT Gateway
- Associates with all private subnets
- Enables internet access from private subnets
- Uses environment-specific naming

### Section 8: Display NAT Gateway Information

```yaml
- name: Display NAT Gateway creation results
  debug:
    msg:
      - "=== NAT Gateway Configuration Complete ==="
      - "Elastic IP: {{ eip.public_ip }} ({{ eip.allocation_id }})"
      - "NAT Gateway ID: {{ nat_gateway.nat_gateway_id }}"
      - "Public Subnet: {{ cf_db_config.public_subnet_id }}"
      - "Route Table: {{ private_route_table.route_table_id }}"
      - "Associated Private Subnets: {{ private_subnet_ids | length }}"
      - "  {% for subnet_id in private_subnet_ids %}"
      - "  - {{ subnet_id }}"
      - "  {% endfor %}"
      - "============================================"
  tags:
    - cf-db
    - nat-gateway
    - networking
```

**Explanation:**
- Provides comprehensive deployment information
- Shows all created resources and their relationships
- Useful for verification and troubleshooting

### Section 9: Validation and Testing

```yaml
- name: Validate NAT Gateway deployment
  assert:
    that:
      - nat_gateway.nat_gateway_id is defined
      - nat_gateway.state == 'available'
      - private_route_table.route_table_id is defined
      - eip.public_ip is defined
    fail_msg: "NAT Gateway deployment validation failed"
    success_msg: "NAT Gateway successfully deployed and configured"
  tags:
    - cf-db
    - nat-gateway
    - networking
    - validation
```

**Explanation:**
- Validates all resources were created successfully
- Checks NAT Gateway is in available state
- Ensures route table and EIP are properly configured

## Step 5.3: Complete NAT Gateway Task

Here's the complete `tasks/nat_gateway.yml` file:

```yaml
---
# NAT Gateway Creation Tasks
# Dependencies: Requires private_subnet_ids from private_subnets.yml

- name: Check if private subnet IDs are available
  set_fact:
    private_subnet_ids: "{{ private_subnet_ids | default([]) }}"
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Get private subnet IDs if not available (dependency check)
  amazon.aws.ec2_vpc_subnet_info:
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    filters:
      "vpc-id": "{{ cf_db_config.vpc_id }}"
      "tag:Component": "Database"
      "tag:Environment": "{{ cf_db_config.common_tags.Environment }}"
  register: existing_private_subnets
  when: private_subnet_ids | length == 0
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Set private subnet IDs from existing subnets
  set_fact:
    private_subnet_ids: "{{ existing_private_subnets.subnets | map(attribute='subnet_id') | list }}"
  when: private_subnet_ids | length == 0 and existing_private_subnets.subnets is defined
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Validate private subnet dependencies
  assert:
    that:
      - private_subnet_ids is defined
      - private_subnet_ids | length > 0
    fail_msg: "NAT Gateway task requires private subnets to be created first. Run with tags: private-subnets,nat-gateway"
    success_msg: "Private subnet dependencies satisfied."
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Validate public subnet exists for NAT Gateway
  amazon.aws.ec2_vpc_subnet_info:
    subnet_ids:
      - "{{ cf_db_config.public_subnet_id }}"
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
  register: public_subnet_info
  tags:
    - cf-db
    - nat-gateway
    - networking
    - validation

- name: Ensure public subnet is available
  assert:
    that:
      - public_subnet_info.subnets | length > 0
      - public_subnet_info.subnets[0].state == 'available'
    fail_msg: "Public subnet {{ cf_db_config.public_subnet_id }} not found or not available"
    success_msg: "Public subnet {{ cf_db_config.public_subnet_id }} is available for NAT Gateway"
  tags:
    - cf-db
    - nat-gateway
    - networking
    - validation

- name: Allocate Elastic IP for NAT Gateway
  amazon.aws.ec2_eip:
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    in_vpc: true
    state: present
    tags:
      Name: "cf-nat-eip-{{ cf_db_config.common_tags.Environment }}"
      Environment: "{{ cf_db_config.common_tags.Environment }}"
      Project: "{{ cf_db_config.common_tags.Project }}"
      Component: "{{ cf_db_config.common_tags.Component }}"
      ManagedBy: "{{ cf_db_config.common_tags.ManagedBy }}"
      Purpose: "NAT Gateway"
  register: eip
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Create NAT Gateway in public subnet
  amazon.aws.ec2_vpc_nat_gateway:
    subnet_id: "{{ cf_db_config.public_subnet_id }}"
    allocation_id: "{{ eip.allocation_id }}"
    state: present
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    wait: true
    wait_timeout: "{{ cf_db_timeouts.nat_gateway_timeout | default(600) }}"
    tags:
      Name: "cf-nat-gateway-{{ cf_db_config.common_tags.Environment }}"
      Environment: "{{ cf_db_config.common_tags.Environment }}"
      Project: "{{ cf_db_config.common_tags.Project }}"
      Component: "{{ cf_db_config.common_tags.Component }}"
      ManagedBy: "{{ cf_db_config.common_tags.ManagedBy }}"
      Purpose: "Database Internet Access"
  register: nat_gateway
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Create route table for private subnets with NAT Gateway route
  amazon.aws.ec2_vpc_route_table:
    vpc_id: "{{ cf_db_config.vpc_id }}"
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    routes:
      - dest: 0.0.0.0/0
        nat_gateway_id: "{{ nat_gateway.nat_gateway_id }}"
    subnets: "{{ private_subnet_ids }}"
    tags:
      Name: "{{ cf_db_config.route_table.name }}"
      Environment: "{{ cf_db_config.common_tags.Environment }}"
      Project: "{{ cf_db_config.common_tags.Project }}"
      Component: "{{ cf_db_config.common_tags.Component }}"
      ManagedBy: "{{ cf_db_config.common_tags.ManagedBy }}"
      Purpose: "Private Subnet Routing"
  register: private_route_table
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Display NAT Gateway creation results
  debug:
    msg:
      - "=== NAT Gateway Configuration Complete ==="
      - "Elastic IP: {{ eip.public_ip }} ({{ eip.allocation_id }})"
      - "NAT Gateway ID: {{ nat_gateway.nat_gateway_id }}"
      - "Public Subnet: {{ cf_db_config.public_subnet_id }}"
      - "Route Table: {{ private_route_table.route_table_id }}"
      - "Associated Private Subnets: {{ private_subnet_ids | length }}"
      - "  {% for subnet_id in private_subnet_ids %}"
      - "  - {{ subnet_id }}"
      - "  {% endfor %}"
      - "============================================"
  tags:
    - cf-db
    - nat-gateway
    - networking

- name: Validate NAT Gateway deployment
  assert:
    that:
      - nat_gateway.nat_gateway_id is defined
      - nat_gateway.state == 'available'
      - private_route_table.route_table_id is defined
      - eip.public_ip is defined
    fail_msg: "NAT Gateway deployment validation failed"
    success_msg: "NAT Gateway successfully deployed and configured"
  tags:
    - cf-db
    - nat-gateway
    - networking
    - validation
```

## Step 5.4: Create Independent Test Playbook

Create a test playbook for NAT Gateway task:

```bash
cd ../../..
nano test-nat-gateway.yml
```

```yaml
---
- name: Test NAT Gateway Creation
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    cf_db_environment: dev
  
  tasks:
    - name: Load environment-specific configuration
      include_vars: "environments/{{ cf_db_environment }}/cf-db.yml"
    
    - name: Create NAT Gateway and routing
      include_tasks: roles/cf-db/tasks/nat_gateway.yml
```

## Step 5.5: Test NAT Gateway Task

### 1. Test with existing private subnets
```bash
# First create private subnets
ansible-playbook test-private-subnets.yml

# Then test NAT Gateway
ansible-playbook test-nat-gateway.yml -v
```

### 2. Test independent execution
```bash
# Test NAT Gateway task independently (with dependency resolution)
ansible-playbook test-nat-gateway.yml -v
```

### 3. Verify NAT Gateway in AWS
```bash
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --query 'NatGateways[*].[NatGatewayId,State,SubnetId,NatGatewayAddresses[0].PublicIp]' --output table --region us-west-1 --profile svktek
```

## Step 5.6: Understanding NAT Gateway Cost

### Cost Components
- **NAT Gateway**: ~$45/month (24/7 operation)
- **Elastic IP**: ~$3.65/month (when associated)
- **Data Transfer**: $0.045 per GB processed

### Cost Optimization Tips
1. **Single NAT Gateway**: Use one NAT Gateway for dev environments
2. **Scheduled Shutdown**: Consider shutting down dev NAT Gateway after hours
3. **Monitor Usage**: Track data transfer costs

## Step 5.7: Troubleshooting

### Common Issues

1. **Public Subnet Not Found**
   ```bash
   aws ec2 describe-subnets --subnet-ids subnet-021b476409dfe66ba --profile svktek
   ```

2. **EIP Allocation Limit**
   ```bash
   aws ec2 describe-account-attributes --attribute-names default-vpc --profile svktek
   ```

3. **NAT Gateway Creation Timeout**
   - Increase wait_timeout value
   - Check AWS service health
   - Verify subnet has internet gateway route

4. **Route Table Association Issues**
   ```bash
   aws ec2 describe-route-tables --filters "Name=tag:Environment,Values=dev" --profile svktek
   ```

### Debug Commands

```bash
# Test with dependency resolution
ansible-playbook test-nat-gateway.yml -v --start-at-task "Get private subnet IDs"

# Run only validation tasks
ansible-playbook test-nat-gateway.yml -t validation

# Check NAT Gateway connectivity
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxxxxxx --profile svktek
```

## Step 5.8: Advanced Features

### Optional Enhancements

1. **Multiple NAT Gateways** (High Availability)
   ```yaml
   # Create one NAT Gateway per AZ for production
   - name: Create NAT Gateway per AZ
     amazon.aws.ec2_vpc_nat_gateway:
       subnet_id: "{{ item.public_subnet_id }}"
       allocation_id: "{{ item.eip_allocation_id }}"
     loop: "{{ availability_zones }}"
   ```

2. **Internet Connectivity Test**
   ```yaml
   - name: Test internet connectivity from private subnet
     uri:
       url: "https://httpbin.org/ip"
       method: GET
     delegate_to: "{{ private_instance_ip }}"
   ```

3. **Cost Monitoring Tags**
   ```yaml
   tags:
     CostCenter: "{{ cf_db_config.common_tags.CostCenter }}"
     BillingProject: "{{ cf_db_config.common_tags.Project }}"
     AutoShutdown: "{{ cf_db_features.enable_auto_shutdown | default('false') }}"
   ```

## Next Steps

1. ✅ NAT Gateway task implemented with dependency resolution
2. ✅ Route table and internet access configured
3. ✅ Comprehensive validation and error handling added
4. ✅ Independent testing capability created

**Next**: Continue to **[06-security-groups-task.md](06-security-groups-task.md)** to implement cross-VPC security groups.

## Summary

You have successfully:
- Created a robust NAT Gateway task with dependency resolution
- Implemented proper internet routing for private subnets
- Added comprehensive validation and error handling
- Created independent testing functionality
- Established cost-awareness and optimization considerations

The NAT Gateway task enables internet access for the Aurora database while maintaining security by keeping the database in private subnets.