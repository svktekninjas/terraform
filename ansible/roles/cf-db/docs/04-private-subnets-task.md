# Step 4: Private Subnets Task Implementation

## Overview
This guide walks you through creating the private subnets task that creates multi-AZ private subnets for the Aurora PostgreSQL database deployment.

## Prerequisites
- Completed Step 1 (Role Setup)
- Completed Step 2 (Defaults Configuration)
- Completed Step 3 (Environment Configuration)
- Understanding of AWS VPC subnets and Ansible EC2 modules

## Step 4.1: Understanding Private Subnets Task

### What This Task Does
- Creates private subnets across multiple Availability Zones
- Tags subnets appropriately for identification
- Returns subnet IDs for use by other tasks
- Validates subnet creation success

### AWS Resources Created
- 2x EC2 Private Subnets (one per AZ)
- Appropriate tags for resource management

### Task Dependencies
- **Requires**: Existing VPC
- **Provides**: `private_subnet_ids` variable for other tasks

## Step 4.2: Create the Private Subnets Task File

Navigate to the tasks directory and create the private subnets task:

```bash
cd roles/cf-db/tasks
nano private_subnets.yml
```

### Section 1: Task Header and Documentation

Add the following content line by line:

```yaml
---
# Private Subnets Creation Tasks
# Creates multi-AZ private subnets for Aurora PostgreSQL database
# Dependencies: Requires existing VPC
# Outputs: private_subnet_ids variable
```

**Explanation:**
- Clear documentation of task purpose
- Dependency and output information
- Helps other developers understand the task

### Section 2: VPC Validation

```yaml
- name: Validate VPC exists for subnet creation
  amazon.aws.ec2_vpc_info:
    vpc_ids:
      - "{{ cf_db_config.vpc_id }}"
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
  register: vpc_info
  tags:
    - cf-db
    - private-subnets
    - networking
    - validation
```

**Explanation:**
- Validates that the specified VPC exists
- Uses the amazon.aws collection for AWS operations
- Registers result for validation
- Tagged for selective execution

### Section 3: VPC Existence Check

```yaml
- name: Ensure VPC exists
  assert:
    that:
      - vpc_info.vpcs | length > 0
      - vpc_info.vpcs[0].state == 'available'
    fail_msg: "VPC {{ cf_db_config.vpc_id }} not found or not available"
    success_msg: "VPC {{ cf_db_config.vpc_id }} is available for subnet creation"
  tags:
    - cf-db
    - private-subnets
    - networking
    - validation
```

**Explanation:**
- Asserts VPC exists and is available
- Provides clear success/failure messages
- Fails fast if prerequisites aren't met

### Section 4: Create Private Subnets

```yaml
- name: Create private subnets for Aurora database (Multi-AZ)
  amazon.aws.ec2_vpc_subnet:
    state: present
    vpc_id: "{{ cf_db_config.vpc_id }}"
    cidr: "{{ item.cidr }}"
    availability_zone: "{{ item.az }}"
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    tags:
      Name: "{{ item.name }}"
      Environment: "{{ cf_db_config.common_tags.Environment }}"
      Project: "{{ cf_db_config.common_tags.Project }}"
      Component: "{{ cf_db_config.common_tags.Component }}"
      ManagedBy: "{{ cf_db_config.common_tags.ManagedBy }}"
      Purpose: "Aurora Database"
      Tier: "Private"
    wait: true
    wait_timeout: 300
  loop: "{{ cf_db_config.private_subnets }}"
  register: private_subnets_result
  tags:
    - cf-db
    - private-subnets
    - networking
```

**Explanation:**
- Creates one subnet per item in private_subnets list
- Uses comprehensive tagging strategy
- Waits for subnet creation to complete
- Registers results for further processing

### Section 5: Extract Subnet IDs

```yaml
- name: Extract private subnet IDs
  set_fact:
    private_subnet_ids: "{{ private_subnets_result.results | map(attribute='subnet') | map(attribute='id') | list }}"
  tags:
    - cf-db
    - private-subnets
    - networking
```

**Explanation:**
- Extracts subnet IDs from creation results
- Creates a list for use by other tasks
- Uses Jinja2 filters for data transformation

### Section 6: Display Results

```yaml
- name: Display private subnet creation results
  debug:
    msg:
      - "Created {{ private_subnet_ids | length }} private subnets:"
      - "{% for subnet in private_subnets_result.results %}"
      - "  - {{ subnet.subnet.tags.Name }}: {{ subnet.subnet.id }} ({{ subnet.subnet.availability_zone }})"
      - "{% endfor %}"
      - "Private subnet IDs: {{ private_subnet_ids }}"
  tags:
    - cf-db
    - private-subnets
    - networking
```

**Explanation:**
- Provides clear feedback on subnet creation
- Shows subnet names, IDs, and availability zones
- Useful for debugging and verification

### Section 7: Validation Check

```yaml
- name: Validate private subnet creation
  assert:
    that:
      - private_subnet_ids | length == cf_db_config.private_subnets | length
      - private_subnet_ids | length >= 2
    fail_msg: "Expected {{ cf_db_config.private_subnets | length }} subnets, got {{ private_subnet_ids | length }}"
    success_msg: "Successfully created {{ private_subnet_ids | length }} private subnets across multiple AZs"
  tags:
    - cf-db
    - private-subnets
    - networking
    - validation
```

**Explanation:**
- Validates correct number of subnets created
- Ensures multi-AZ requirement is met
- Provides clear validation feedback

## Step 4.3: Complete Private Subnets Task

Here's the complete `tasks/private_subnets.yml` file:

```yaml
---
# Private Subnets Creation Tasks
# Creates multi-AZ private subnets for Aurora PostgreSQL database
# Dependencies: Requires existing VPC
# Outputs: private_subnet_ids variable

- name: Validate VPC exists for subnet creation
  amazon.aws.ec2_vpc_info:
    vpc_ids:
      - "{{ cf_db_config.vpc_id }}"
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
  register: vpc_info
  tags:
    - cf-db
    - private-subnets
    - networking
    - validation

- name: Ensure VPC exists
  assert:
    that:
      - vpc_info.vpcs | length > 0
      - vpc_info.vpcs[0].state == 'available'
    fail_msg: "VPC {{ cf_db_config.vpc_id }} not found or not available"
    success_msg: "VPC {{ cf_db_config.vpc_id }} is available for subnet creation"
  tags:
    - cf-db
    - private-subnets
    - networking
    - validation

- name: Create private subnets for Aurora database (Multi-AZ)
  amazon.aws.ec2_vpc_subnet:
    state: present
    vpc_id: "{{ cf_db_config.vpc_id }}"
    cidr: "{{ item.cidr }}"
    availability_zone: "{{ item.az }}"
    region: "{{ cf_db_config.region }}"
    profile: "{{ cf_db_config.profile }}"
    tags:
      Name: "{{ item.name }}"
      Environment: "{{ cf_db_config.common_tags.Environment }}"
      Project: "{{ cf_db_config.common_tags.Project }}"
      Component: "{{ cf_db_config.common_tags.Component }}"
      ManagedBy: "{{ cf_db_config.common_tags.ManagedBy }}"
      Purpose: "Aurora Database"
      Tier: "Private"
    wait: true
    wait_timeout: 300
  loop: "{{ cf_db_config.private_subnets }}"
  register: private_subnets_result
  tags:
    - cf-db
    - private-subnets
    - networking

- name: Extract private subnet IDs
  set_fact:
    private_subnet_ids: "{{ private_subnets_result.results | map(attribute='subnet') | map(attribute='id') | list }}"
  tags:
    - cf-db
    - private-subnets
    - networking

- name: Display private subnet creation results
  debug:
    msg:
      - "Created {{ private_subnet_ids | length }} private subnets:"
      - "{% for subnet in private_subnets_result.results %}"
      - "  - {{ subnet.subnet.tags.Name }}: {{ subnet.subnet.id }} ({{ subnet.subnet.availability_zone }})"
      - "{% endfor %}"
      - "Private subnet IDs: {{ private_subnet_ids }}"
  tags:
    - cf-db
    - private-subnets
    - networking

- name: Validate private subnet creation
  assert:
    that:
      - private_subnet_ids | length == cf_db_config.private_subnets | length
      - private_subnet_ids | length >= 2
    fail_msg: "Expected {{ cf_db_config.private_subnets | length }} subnets, got {{ private_subnet_ids | length }}"
    success_msg: "Successfully created {{ private_subnet_ids | length }} private subnets across multiple AZs"
  tags:
    - cf-db
    - private-subnets
    - networking
    - validation
```

## Step 4.4: Create Test Playbook for Private Subnets

To test this task independently, create a simple test playbook:

```bash
cd ../../..
nano test-private-subnets.yml
```

Add the following content:

```yaml
---
- name: Test Private Subnets Creation
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    cf_db_environment: dev
  
  tasks:
    - name: Load environment-specific configuration
      include_vars: "environments/{{ cf_db_environment }}/cf-db.yml"
    
    - name: Create private subnets
      include_tasks: roles/cf-db/tasks/private_subnets.yml
```

## Step 4.5: Test the Private Subnets Task

### 1. Validate YAML syntax
```bash
ansible-playbook --syntax-check test-private-subnets.yml
```

### 2. Run the task in check mode
```bash
ansible-playbook test-private-subnets.yml --check -v
```

### 3. Execute the task
```bash
ansible-playbook test-private-subnets.yml -v
```

### 4. Verify subnets in AWS Console
```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0642a6fba47ae2a28" "Name=tag:Component,Values=Database" --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' --output table --region us-west-1 --profile svktek
```

Expected output:
```
-------------------------------------------------------------
|                    DescribeSubnets                     |
+-----------------------+-------------+-------------+------+
|  subnet-xxxxxxxxx     |  10.0.2.0/24|  us-west-1a | cf-private-subnet-dev-1a |
|  subnet-xxxxxxxxx     |  10.0.3.0/24|  us-west-1c | cf-private-subnet-dev-1c |
+-----------------------+-------------+-------------+------+
```

## Step 4.6: Understanding Task Execution Flow

### Execution Steps
1. **Validation**: Check VPC exists and is available
2. **Creation**: Create subnets with proper tags
3. **Processing**: Extract subnet IDs from results
4. **Display**: Show creation results
5. **Validation**: Verify correct number of subnets

### Variable Flow
```
Input: cf_db_config.private_subnets (from environment)
  ↓
Process: amazon.aws.ec2_vpc_subnet module
  ↓
Output: private_subnet_ids (list of subnet IDs)
  ↓
Used by: NAT Gateway and DB Cluster tasks
```

## Step 4.7: Error Handling and Troubleshooting

### Common Issues and Solutions

1. **VPC Not Found**
   ```bash
   # Verify VPC exists
   aws ec2 describe-vpcs --vpc-ids vpc-0642a6fba47ae2a28 --profile svktek
   ```

2. **CIDR Block Conflicts**
   ```bash
   # Check existing subnets
   aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0642a6fba47ae2a28" --query 'Subnets[*].CidrBlock' --profile svktek
   ```

3. **Availability Zone Issues**
   ```bash
   # Verify AZs exist in region
   aws ec2 describe-availability-zones --region us-west-1 --profile svktek
   ```

4. **Permission Issues**
   ```bash
   # Test EC2 permissions
   aws ec2 describe-vpcs --profile svktek
   ```

### Debug Commands

```bash
# Run with maximum verbosity
ansible-playbook test-private-subnets.yml -vvv

# Check specific task
ansible-playbook test-private-subnets.yml --start-at-task "Create private subnets"

# Run only validation tasks
ansible-playbook test-private-subnets.yml -t validation
```

## Step 4.8: Task Enhancement Options

### Optional Enhancements (Advanced)

1. **Idempotency Check**
   ```yaml
   - name: Check if subnets already exist
     amazon.aws.ec2_vpc_subnet_info:
       filters:
         vpc-id: "{{ cf_db_config.vpc_id }}"
         tag:Component: Database
       region: "{{ cf_db_config.region }}"
       profile: "{{ cf_db_config.profile }}"
     register: existing_subnets
   ```

2. **CIDR Validation**
   ```yaml
   - name: Validate CIDR blocks don't overlap
     assert:
       that:
         - item.cidr | ipaddr('network') != ''
       fail_msg: "Invalid CIDR block: {{ item.cidr }}"
     loop: "{{ cf_db_config.private_subnets }}"
   ```

3. **Dynamic AZ Selection**
   ```yaml
   - name: Get available AZs
     amazon.aws.aws_az_info:
       region: "{{ cf_db_config.region }}"
       profile: "{{ cf_db_config.profile }}"
     register: az_info
   ```

## Troubleshooting Checklist

- [ ] VPC exists and is available
- [ ] CIDR blocks don't conflict with existing subnets
- [ ] Availability zones are valid for the region
- [ ] AWS credentials have appropriate permissions
- [ ] YAML syntax is valid
- [ ] Environment configuration is loaded

## Next Steps

1. ✅ Private subnets task implemented
2. ✅ Task validation and error handling added
3. ✅ Independent testing capability created
4. ✅ AWS resource creation verified

**Next**: Continue to **[05-nat-gateway-task.md](05-nat-gateway-task.md)** to implement NAT Gateway and routing.

## Summary

You have successfully:
- Created a comprehensive private subnets task with validation
- Implemented proper error handling and AWS best practices
- Added detailed logging and debugging capabilities
- Created independent testing functionality
- Validated subnet creation across multiple availability zones

The private subnets task provides the foundation for the Aurora database deployment by creating the isolated network infrastructure required for secure database operations.