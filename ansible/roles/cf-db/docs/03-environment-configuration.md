# Step 3: Environment Configuration

## Overview
This guide walks you through creating environment-specific configuration files that inherit from defaults but override values for specific environments (dev, test, prod).

## Prerequisites
- Completed Step 1 (Role Setup)
- Completed Step 2 (Defaults Configuration)
- Understanding of Ansible variable inheritance

## Step 3.1: Understanding Environment Configuration

### Why Environment-Specific Configs?
- Different resource names per environment
- Environment-specific instance sizes
- Different backup/maintenance windows
- Environment-specific security settings
- Cost optimization per environment

### Configuration Strategy
- **Inherit from defaults**: Use default values as base
- **Override specific values**: Only change what's different
- **Environment naming**: Consistent naming conventions
- **Security variance**: Different security levels per environment

## Step 3.2: Create Development Environment Configuration

Navigate to the environments directory and create the dev configuration:

```bash
cd ../../environments/dev
nano cf-db.yml
```

### Development Configuration Content

Add the following content line by line:

#### Section 1: Header and Basic Configuration
```yaml
---
# Development Environment Configuration for CF-DB Role
cf_db_config:
  region: "{{ cf_db_defaults.region }}"
  profile: "{{ cf_db_defaults.profile }}"
  availability_zones: "{{ cf_db_defaults.availability_zones }}"
```

**Explanation:**
- `cf_db_config`: Main configuration block for this environment
- Uses Jinja2 templating to inherit from defaults
- Maintains consistency with default AWS settings

#### Section 2: VPC Configuration
```yaml
  # VPC Configuration (inheriting from defaults)
  vpc_id: "{{ cf_db_vpc_defaults.vpc_id }}"
  public_subnet_id: "{{ cf_db_vpc_defaults.public_subnet_id }}"
  openshift_sg_id: "{{ cf_db_vpc_defaults.openshift_sg_id }}"
```

**Explanation:**
- Inherits VPC settings from defaults
- Allows for easy environment-specific overrides if needed
- Maintains connection to existing infrastructure

#### Section 3: Private Subnets Configuration
```yaml
  # Private Subnets Configuration (2 AZs)
  private_subnets:
    - cidr: "10.0.2.0/24"
      az: "us-west-1a"
      name: "cf-private-subnet-dev-1a"
    - cidr: "10.0.3.0/24"
      az: "us-west-1c"
      name: "cf-private-subnet-dev-1c"
```

**Explanation:**
- Environment-specific subnet names (includes 'dev')
- Maintains same CIDR blocks as defaults
- Multi-AZ deployment for high availability

#### Section 4: Route Table Configuration
```yaml
  # Route Table Configuration
  route_table:
    name: "cf-private-rt-dev"
```

**Explanation:**
- Environment-specific route table name
- Simple but clear naming convention

#### Section 5: Security Group Configuration
```yaml
  # Security Group Configuration
  security_group:
    name: "cf-aurora-db-sg-dev"
    description: "Aurora DB Security Group for Development - Cross VPC Access"
    db_port: 5432
    allowed_cidrs:
      - "10.0.0.0/16"    # Current VPC CIDR
      - "172.16.0.0/16"  # ROSA cluster VPC CIDR (example)
      - "192.168.0.0/16" # Additional VPC CIDR (example)
    allowed_security_groups:
      - "{{ cf_db_vpc_defaults.openshift_sg_id }}"  # OpenShift security group
```

**Explanation:**
- Development-specific security group name
- Cross-VPC access configuration
- Allows access from multiple CIDR ranges
- References OpenShift security group for integration

#### Section 6: Database Configuration
```yaml
  # Database Configuration
  database:
    engine: "aurora-postgresql"
    engine_version: "15.3"
    instance_class: "db.t3.medium"
    cluster_name: "cf-aurora-pg-cluster-dev"
    database_name: "cfdb_dev"
    master_username: "cfadmin"
    master_password: "{{ cf_db_password | default('ChangeMeInProduction!') }}"
    backup_retention_period: 7
    preferred_backup_window: "07:00-09:00"
    preferred_maintenance_window: "sun:05:00-sun:06:00"
    publicly_accessible: false
    deletion_protection: false
```

**Explanation:**
- Development-specific cluster and database names
- Password can be overridden with external variable
- Reasonable backup settings for development
- Deletion protection disabled for easy cleanup

#### Section 7: Aurora Instances Configuration
```yaml
    # Aurora Cluster Instances (2 AZs)
    instances:
      - identifier: "cf-aurora-pg-writer-dev"
        instance_class: "db.t3.medium"
        az: "us-west-1a"
      - identifier: "cf-aurora-pg-reader-dev"
        instance_class: "db.t3.medium"
        az: "us-west-1c"
```

**Explanation:**
- Development-specific instance identifiers
- Cost-effective instance class for development
- Instances spread across multiple AZs

#### Section 8: DB Subnet Group and Tagging
```yaml
  # DB Subnet Group Configuration
  db_subnet_group:
    name: "cf-private-db-subnet-group-dev"
    description: "Aurora DB subnet group for Development - 2 AZs"

  # Tagging Strategy
  common_tags:
    Environment: "dev"
    Project: "ConsultingFirm"
    Component: "Database"
    ManagedBy: "Ansible"
    CostCenter: "Engineering"
```

**Explanation:**
- Environment-specific subnet group
- Consistent tagging with environment identifier
- Helps with cost tracking and resource management

## Step 3.3: Complete Development Configuration

Here's the complete `environments/dev/cf-db.yml` file:

```yaml
---
# Development Environment Configuration for CF-DB Role
cf_db_config:
  region: "{{ cf_db_defaults.region }}"
  profile: "{{ cf_db_defaults.profile }}"
  availability_zones: "{{ cf_db_defaults.availability_zones }}"
  
  # VPC Configuration (inheriting from defaults)
  vpc_id: "{{ cf_db_vpc_defaults.vpc_id }}"
  public_subnet_id: "{{ cf_db_vpc_defaults.public_subnet_id }}"
  openshift_sg_id: "{{ cf_db_vpc_defaults.openshift_sg_id }}"
  
  # Private Subnets Configuration (2 AZs)
  private_subnets:
    - cidr: "10.0.2.0/24"
      az: "us-west-1a"
      name: "cf-private-subnet-dev-1a"
    - cidr: "10.0.3.0/24"
      az: "us-west-1c"
      name: "cf-private-subnet-dev-1c"
  
  # Route Table Configuration
  route_table:
    name: "cf-private-rt-dev"
  
  # Security Group Configuration
  security_group:
    name: "cf-aurora-db-sg-dev"
    description: "Aurora DB Security Group for Development - Cross VPC Access"
    db_port: 5432
    allowed_cidrs:
      - "10.0.0.0/16"    # Current VPC CIDR
      - "172.16.0.0/16"  # ROSA cluster VPC CIDR (example)
      - "192.168.0.0/16" # Additional VPC CIDR (example)
    allowed_security_groups:
      - "{{ cf_db_vpc_defaults.openshift_sg_id }}"  # OpenShift security group
  
  # Database Configuration
  database:
    engine: "aurora-postgresql"
    engine_version: "15.3"
    instance_class: "db.t3.medium"
    cluster_name: "cf-aurora-pg-cluster-dev"
    database_name: "cfdb_dev"
    master_username: "cfadmin"
    master_password: "{{ cf_db_password | default('ChangeMeInProduction!') }}"
    backup_retention_period: 7
    preferred_backup_window: "07:00-09:00"
    preferred_maintenance_window: "sun:05:00-sun:06:00"
    publicly_accessible: false
    deletion_protection: false
    
    # Aurora Cluster Instances (2 AZs)
    instances:
      - identifier: "cf-aurora-pg-writer-dev"
        instance_class: "db.t3.medium"
        az: "us-west-1a"
      - identifier: "cf-aurora-pg-reader-dev"
        instance_class: "db.t3.medium"
        az: "us-west-1c"
    
  # DB Subnet Group Configuration
  db_subnet_group:
    name: "cf-private-db-subnet-group-dev"
    description: "Aurora DB subnet group for Development - 2 AZs"

  # Tagging Strategy
  common_tags:
    Environment: "dev"
    Project: "ConsultingFirm"
    Component: "Database"
    ManagedBy: "Ansible"
    CostCenter: "Engineering"
```

## Step 3.4: Create Test Environment Configuration

Create the test environment configuration:

```bash
nano ../test/cf-db.yml
```

### Test Environment Differences
- Higher instance classes for performance testing
- Longer backup retention
- Deletion protection enabled
- Different maintenance window

Here's the complete test configuration:

```yaml
---
# Test Environment Configuration for CF-DB Role
cf_db_config:
  region: "{{ cf_db_defaults.region }}"
  profile: "{{ cf_db_defaults.profile }}"
  availability_zones: "{{ cf_db_defaults.availability_zones }}"
  
  # VPC Configuration (inheriting from defaults)
  vpc_id: "{{ cf_db_vpc_defaults.vpc_id }}"
  public_subnet_id: "{{ cf_db_vpc_defaults.public_subnet_id }}"
  openshift_sg_id: "{{ cf_db_vpc_defaults.openshift_sg_id }}"
  
  # Private Subnets Configuration (2 AZs)
  private_subnets:
    - cidr: "10.0.4.0/24"
      az: "us-west-1a"
      name: "cf-private-subnet-test-1a"
    - cidr: "10.0.5.0/24"
      az: "us-west-1c"
      name: "cf-private-subnet-test-1c"
  
  # Route Table Configuration
  route_table:
    name: "cf-private-rt-test"
  
  # Security Group Configuration
  security_group:
    name: "cf-aurora-db-sg-test"
    description: "Aurora DB Security Group for Test - Cross VPC Access"
    db_port: 5432
    allowed_cidrs:
      - "10.0.0.0/16"
      - "172.16.0.0/16"
      - "192.168.0.0/16"
    allowed_security_groups:
      - "{{ cf_db_vpc_defaults.openshift_sg_id }}"
  
  # Database Configuration
  database:
    engine: "aurora-postgresql"
    engine_version: "15.3"
    instance_class: "db.r6g.large"  # Higher performance for testing
    cluster_name: "cf-aurora-pg-cluster-test"
    database_name: "cfdb_test"
    master_username: "cfadmin"
    master_password: "{{ cf_db_password | default('ChangeMeInProduction!') }}"
    backup_retention_period: 14  # Longer retention for testing
    preferred_backup_window: "03:00-05:00"  # Different window
    preferred_maintenance_window: "sat:05:00-sat:06:00"
    publicly_accessible: false
    deletion_protection: true  # Protect test data
    
    # Aurora Cluster Instances (2 AZs)
    instances:
      - identifier: "cf-aurora-pg-writer-test"
        instance_class: "db.r6g.large"
        az: "us-west-1a"
      - identifier: "cf-aurora-pg-reader-test"
        instance_class: "db.r6g.large"
        az: "us-west-1c"
    
  # DB Subnet Group Configuration
  db_subnet_group:
    name: "cf-private-db-subnet-group-test"
    description: "Aurora DB subnet group for Test - 2 AZs"

  # Tagging Strategy
  common_tags:
    Environment: "test"
    Project: "ConsultingFirm"
    Component: "Database"
    ManagedBy: "Ansible"
    CostCenter: "Engineering"
```

## Step 3.5: Create Production Environment Configuration

Create the production environment configuration:

```bash
nano ../prod/cf-db.yml
```

### Production Environment Characteristics
- High-performance instance classes
- Maximum backup retention
- Deletion protection enabled
- Production-grade security settings

Here's the complete production configuration:

```yaml
---
# Production Environment Configuration for CF-DB Role
cf_db_config:
  region: "{{ cf_db_defaults.region }}"
  profile: "{{ cf_db_defaults.profile }}"
  availability_zones: "{{ cf_db_defaults.availability_zones }}"
  
  # VPC Configuration (inheriting from defaults)
  vpc_id: "{{ cf_db_vpc_defaults.vpc_id }}"
  public_subnet_id: "{{ cf_db_vpc_defaults.public_subnet_id }}"
  openshift_sg_id: "{{ cf_db_vpc_defaults.openshift_sg_id }}"
  
  # Private Subnets Configuration (2 AZs)
  private_subnets:
    - cidr: "10.0.6.0/24"
      az: "us-west-1a"
      name: "cf-private-subnet-prod-1a"
    - cidr: "10.0.7.0/24"
      az: "us-west-1c"
      name: "cf-private-subnet-prod-1c"
  
  # Route Table Configuration
  route_table:
    name: "cf-private-rt-prod"
  
  # Security Group Configuration
  security_group:
    name: "cf-aurora-db-sg-prod"
    description: "Aurora DB Security Group for Production - Cross VPC Access"
    db_port: 5432
    allowed_cidrs:
      - "10.0.0.0/16"
      - "172.16.0.0/16"
      - "192.168.0.0/16"
    allowed_security_groups:
      - "{{ cf_db_vpc_defaults.openshift_sg_id }}"
  
  # Database Configuration
  database:
    engine: "aurora-postgresql"
    engine_version: "15.3"
    instance_class: "db.r6g.xlarge"  # High performance for production
    cluster_name: "cf-aurora-pg-cluster-prod"
    database_name: "cfdb_prod"
    master_username: "cfadmin"
    master_password: "{{ cf_db_password | default('ChangeMeInProduction!') }}"
    backup_retention_period: 30  # Maximum retention
    preferred_backup_window: "02:00-04:00"
    preferred_maintenance_window: "sun:02:00-sun:03:00"
    publicly_accessible: false
    deletion_protection: true  # Critical for production
    
    # Aurora Cluster Instances (2 AZs)
    instances:
      - identifier: "cf-aurora-pg-writer-prod"
        instance_class: "db.r6g.xlarge"
        az: "us-west-1a"
      - identifier: "cf-aurora-pg-reader-prod"
        instance_class: "db.r6g.xlarge"
        az: "us-west-1c"
    
  # DB Subnet Group Configuration
  db_subnet_group:
    name: "cf-private-db-subnet-group-prod"
    description: "Aurora DB subnet group for Production - 2 AZs"

  # Tagging Strategy
  common_tags:
    Environment: "prod"
    Project: "ConsultingFirm"
    Component: "Database"
    ManagedBy: "Ansible"
    CostCenter: "Engineering"
```

## Step 3.6: Validate Environment Configurations

### 1. Check all environment files exist
```bash
ls -la ../*/cf-db.yml
```

Expected output:
```
../dev/cf-db.yml
../prod/cf-db.yml
../test/cf-db.yml
```

### 2. Validate YAML syntax for all environments
```bash
for env in dev test prod; do
    echo "Validating $env environment..."
    python3 -c "import yaml; yaml.safe_load(open('../$env/cf-db.yml'))" && echo "✅ $env YAML is valid" || echo "❌ $env YAML has errors"
done
```

### 3. Compare configurations
```bash
# Check that each environment has unique resource names
grep "cluster_name" ../*/cf-db.yml
grep "name.*subnet.*dev\|test\|prod" ../*/cf-db.yml
```

## Step 3.7: Environment Configuration Summary

### Configuration Differences by Environment

| Setting | Dev | Test | Prod |
|---------|-----|------|------|
| Instance Class | db.t3.medium | db.r6g.large | db.r6g.xlarge |
| Backup Retention | 7 days | 14 days | 30 days |
| Deletion Protection | false | true | true |
| CIDR Blocks | 10.0.2-3.0/24 | 10.0.4-5.0/24 | 10.0.6-7.0/24 |
| Maintenance Window | Sunday 5-6 AM | Saturday 5-6 AM | Sunday 2-3 AM |

### Cost Implications
- **Dev**: ~$50-100/month (t3.medium instances)
- **Test**: ~$200-400/month (r6g.large instances)
- **Prod**: ~$500-1000/month (r6g.xlarge instances)

## Troubleshooting

### Common Issues

1. **CIDR Block Conflicts**
   ```bash
   # Check existing subnets in your VPC
   aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0642a6fba47ae2a28" --query 'Subnets[].CidrBlock' --profile svktek
   ```

2. **Invalid Instance Classes**
   ```bash
   # Check available instance classes in your region
   aws rds describe-db-engine-versions --engine aurora-postgresql --query 'DBEngineVersions[0].ValidUpgradeTarget[*].Engine' --region us-west-1 --profile svktek
   ```

3. **Template Variable Errors**
   ```bash
   # Test variable resolution
   ansible-playbook --syntax-check -i localhost, /dev/null --extra-vars "@../dev/cf-db.yml" --extra-vars "cf_db_environment=dev" -e "ansible_python_interpreter=python3" -c local
   ```

## Best Practices

1. **Consistent Naming**: Follow environment-specific naming conventions
2. **Resource Isolation**: Use different CIDR blocks per environment
3. **Security Gradation**: Increase security controls in higher environments
4. **Cost Optimization**: Use appropriate instance sizes per environment
5. **Backup Strategy**: Align retention with business requirements

## Next Steps

1. ✅ Development environment configured
2. ✅ Test environment configured  
3. ✅ Production environment configured
4. ✅ Environment-specific differences established

**Next**: Continue to **[04-private-subnets-task.md](04-private-subnets-task.md)** to implement the first infrastructure task.

## Summary

You have successfully:
- Created environment-specific configurations for dev, test, and prod
- Established proper variable inheritance from defaults
- Configured environment-appropriate instance sizes and settings
- Set up unique resource naming conventions
- Validated all environment configurations

The environment configurations provide the foundation for deploying the same infrastructure pattern across different environments with appropriate variations for each use case.