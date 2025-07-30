# Step 2: Defaults Configuration

## Overview
This guide walks you through creating the defaults/main.yml file that contains all default variables for the CF-DB role. These values serve as fallbacks and can be overridden by environment-specific configurations.

## Prerequisites
- Completed Step 1 (Role Setup)
- Understanding of Ansible variables
- Knowledge of AWS resource naming conventions

## Step 2.1: Understanding Default Variables

### What are defaults?
- Lowest priority variables in Ansible
- Provide fallback values when not overridden
- Should contain safe, working values for development
- Can be overridden by environment-specific configurations

### Our defaults will include:
- AWS configuration (region, profile, AZs)
- VPC and networking defaults
- Database configuration defaults
- Security group settings
- Tagging strategy

## Step 2.2: Create defaults/main.yml

Open your text editor and create the complete defaults configuration:

```bash
nano defaults/main.yml
```

Add the following content line by line:

### Section 1: Header and AWS Configuration
```yaml
---
# CF-DB Role Default Variables
# These are fallback values that can be overridden by environment-specific configs

# Default AWS Configuration
cf_db_defaults:
  region: "us-west-1"
  profile: "svktek"
  availability_zones:
    - "us-west-1a"
    - "us-west-1c"

# Default Environment
cf_db_environment: "dev"
```

**Explanation:**
- `cf_db_defaults`: Main configuration block for AWS settings
- `region`: AWS region where resources will be created
- `profile`: AWS CLI profile to use for authentication
- `availability_zones`: List of AZs for multi-AZ deployment
- `cf_db_environment`: Default environment name

### Section 2: VPC Configuration
```yaml
# Default VPC Configuration (using actual AWS resource IDs)
cf_db_vpc_defaults:
  vpc_id: "vpc-0642a6fba47ae2a28"
  public_subnet_id: "subnet-021b476409dfe66ba"  # Public subnet for NAT Gateway
  openshift_sg_id: ""  # Optional: OpenShift security group ID (set when available)
```

**Explanation:**
- `vpc_id`: Existing VPC where resources will be created
- `public_subnet_id`: Public subnet for NAT Gateway placement
- `openshift_sg_id`: Optional security group for OpenShift integration

### Section 3: Private Subnets Configuration
```yaml
# Default Private Subnets Configuration
cf_db_private_subnets_defaults:
  - cidr: "10.0.2.0/24"
    az: "us-west-1a"
    name: "cf-private-subnet-default-1a"
  - cidr: "10.0.3.0/24"
    az: "us-west-1c"
    name: "cf-private-subnet-default-1c"
```

**Explanation:**
- Defines two private subnets across different AZs
- Uses non-overlapping CIDR blocks
- Follows naming convention for easy identification

### Section 4: Route Table Configuration
```yaml
# Default Route Table Configuration
cf_db_route_table_defaults:
  name: "cf-private-rt-default"
```

**Explanation:**
- Default name for the private route table
- Will be associated with private subnets

### Section 5: Security Group Configuration
```yaml
# Default Security Group Configuration
cf_db_security_group_defaults:
  name: "cf-aurora-db-sg-default"
  description: "Aurora DB Security Group - Default"
  db_port: 5432
  allowed_cidrs:
    - "10.0.0.0/16"
    - "172.16.0.0/16"
    - "192.168.0.0/16"
```

**Explanation:**
- `name`: Security group name
- `description`: Human-readable description
- `db_port`: PostgreSQL default port
- `allowed_cidrs`: CIDR blocks allowed to access the database

### Section 6: Database Configuration
```yaml
# Default Database Configuration
cf_db_database_defaults:
  engine: "aurora-postgresql"
  engine_version: "15.3"
  instance_class: "db.t3.medium"
  cluster_name: "cf-aurora-pg-cluster-default"
  database_name: "cfdb_default"
  master_username: "cfadmin"
  master_password: "ChangeMeInProduction!"
  backup_retention_period: 7
  preferred_backup_window: "07:00-09:00"
  preferred_maintenance_window: "sun:05:00-sun:06:00"
  publicly_accessible: false
  deletion_protection: false
  
  # Default Aurora Instances
  instances:
    - identifier: "cf-aurora-pg-writer-default"
      instance_class: "db.t3.medium"
      az: "us-west-1a"
    - identifier: "cf-aurora-pg-reader-default"
      instance_class: "db.t3.medium"
      az: "us-west-1c"
```

**Explanation:**
- Complete Aurora PostgreSQL configuration
- Writer and reader instances in different AZs
- Default backup and maintenance windows
- Security settings (not publicly accessible)

### Section 7: DB Subnet Group Configuration
```yaml
# Default DB Subnet Group Configuration
cf_db_subnet_group_defaults:
  name: "cf-private-db-subnet-group-default"
  description: "Aurora DB subnet group - Default"
```

**Explanation:**
- Subnet group required for Aurora deployment
- Groups private subnets for database placement

### Section 8: Tagging Strategy
```yaml
# Default Tagging Strategy
cf_db_common_tags_defaults:
  Environment: "default"
  Project: "ConsultingFirm"
  Component: "Database"
  ManagedBy: "Ansible"
  CostCenter: "Engineering"
```

**Explanation:**
- Consistent tagging across all resources
- Helps with cost tracking and resource management
- Environment tag will be overridden by specific environments

### Section 9: Timeouts and Features
```yaml
# Timeout and Retry Defaults
cf_db_timeouts:
  nat_gateway_timeout: 600  # seconds
  db_cluster_timeout: 1800  # seconds
  db_instance_timeout: 1200 # seconds

# Feature Flags
cf_db_features:
  enable_cross_vpc_access: true
  enable_deletion_protection: false
  enable_backup_retention: true
  enable_monitoring: true
```

**Explanation:**
- Timeout values for long-running operations
- Feature flags for optional functionality

### Section 10: Validation Rules
```yaml
# Validation Rules
cf_db_validation:
  required_vars:
    - vpc_id
    - public_subnet_id
    - region
  min_backup_retention_days: 1
  max_backup_retention_days: 35
  supported_regions:
    - us-east-1
    - us-west-1
    - us-west-2
    - eu-west-1
  supported_engines:
    - aurora-postgresql
    - aurora-mysql
```

**Explanation:**
- Validation rules for input checking
- Supported regions and engines
- Backup retention limits

## Step 2.3: Complete defaults/main.yml File

Here's the complete file content:

```yaml
---
# CF-DB Role Default Variables
# These are fallback values that can be overridden by environment-specific configs

# Default AWS Configuration
cf_db_defaults:
  region: "us-west-1"
  profile: "svktek"
  availability_zones:
    - "us-west-1a"
    - "us-west-1c"

# Default Environment
cf_db_environment: "dev"

# Default VPC Configuration (using actual AWS resource IDs)
cf_db_vpc_defaults:
  vpc_id: "vpc-0642a6fba47ae2a28"
  public_subnet_id: "subnet-021b476409dfe66ba"  # Public subnet for NAT Gateway
  openshift_sg_id: ""  # Optional: OpenShift security group ID (set when available)

# Default Private Subnets Configuration
cf_db_private_subnets_defaults:
  - cidr: "10.0.2.0/24"
    az: "us-west-1a"
    name: "cf-private-subnet-default-1a"
  - cidr: "10.0.3.0/24"
    az: "us-west-1c"
    name: "cf-private-subnet-default-1c"

# Default Route Table Configuration
cf_db_route_table_defaults:
  name: "cf-private-rt-default"

# Default Security Group Configuration
cf_db_security_group_defaults:
  name: "cf-aurora-db-sg-default"
  description: "Aurora DB Security Group - Default"
  db_port: 5432
  allowed_cidrs:
    - "10.0.0.0/16"
    - "172.16.0.0/16"
    - "192.168.0.0/16"

# Default Database Configuration
cf_db_database_defaults:
  engine: "aurora-postgresql"
  engine_version: "15.3"
  instance_class: "db.t3.medium"
  cluster_name: "cf-aurora-pg-cluster-default"
  database_name: "cfdb_default"
  master_username: "cfadmin"
  master_password: "ChangeMeInProduction!"
  backup_retention_period: 7
  preferred_backup_window: "07:00-09:00"
  preferred_maintenance_window: "sun:05:00-sun:06:00"
  publicly_accessible: false
  deletion_protection: false
  
  # Default Aurora Instances
  instances:
    - identifier: "cf-aurora-pg-writer-default"
      instance_class: "db.t3.medium"
      az: "us-west-1a"
    - identifier: "cf-aurora-pg-reader-default"
      instance_class: "db.t3.medium"
      az: "us-west-1c"

# Default DB Subnet Group Configuration
cf_db_subnet_group_defaults:
  name: "cf-private-db-subnet-group-default"
  description: "Aurora DB subnet group - Default"

# Default Tagging Strategy
cf_db_common_tags_defaults:
  Environment: "default"
  Project: "ConsultingFirm"
  Component: "Database"
  ManagedBy: "Ansible"
  CostCenter: "Engineering"

# Timeout and Retry Defaults
cf_db_timeouts:
  nat_gateway_timeout: 600  # seconds
  db_cluster_timeout: 1800  # seconds
  db_instance_timeout: 1200 # seconds

# Feature Flags
cf_db_features:
  enable_cross_vpc_access: true
  enable_deletion_protection: false
  enable_backup_retention: true
  enable_monitoring: true

# Validation Rules
cf_db_validation:
  required_vars:
    - vpc_id
    - public_subnet_id
    - region
  min_backup_retention_days: 1
  max_backup_retention_days: 35
  supported_regions:
    - us-east-1
    - us-west-1
    - us-west-2
    - eu-west-1
  supported_engines:
    - aurora-postgresql
    - aurora-mysql
```

## Step 2.4: Save and Validate

### 1. Save the file
```bash
# If using nano, press Ctrl+X, then Y, then Enter
```

### 2. Validate YAML syntax
```bash
ansible-playbook --syntax-check -i localhost, /dev/null --extra-vars "cf_db_environment=dev" -e "ansible_python_interpreter=python3" -c local -M defaults/ --list-tasks 2>/dev/null || echo "Checking YAML syntax..."
python3 -c "import yaml; yaml.safe_load(open('defaults/main.yml'))" && echo "✅ YAML syntax is valid" || echo "❌ YAML syntax error"
```

### 3. View the file structure
```bash
wc -l defaults/main.yml
echo "Total lines in defaults/main.yml"
```

## Step 2.5: Understanding Variable Precedence

When you override these defaults, Ansible follows this precedence (lowest to highest):
1. **defaults/main.yml** ← (We just created this)
2. inventory variables
3. host_vars
4. group_vars
5. **environment-specific vars** ← (Next step)
6. play vars
7. task vars
8. command line --extra-vars

## Troubleshooting

### Common Issues

1. **YAML Syntax Errors**
   ```bash
   # Check for indentation issues
   python3 -c "import yaml; print(yaml.safe_load(open('defaults/main.yml')))"
   ```

2. **Invalid Resource IDs**
   ```bash
   # Verify your VPC and subnet IDs exist
   aws ec2 describe-vpcs --vpc-ids vpc-0642a6fba47ae2a28 --profile svktek
   aws ec2 describe-subnets --subnet-ids subnet-021b476409dfe66ba --profile svktek
   ```

3. **Region/AZ Mismatch**
   ```bash
   # Ensure AZs exist in your region
   aws ec2 describe-availability-zones --region us-west-1 --profile svktek
   ```

## Best Practices

1. **Use Descriptive Names**: All resource names should be clear and follow conventions
2. **Document Everything**: Add comments for complex configurations
3. **Environment-Neutral**: Defaults should work across environments
4. **Security First**: Use secure defaults (no public access, encryption enabled)
5. **Cost Optimization**: Use cost-effective instance types for defaults

## Next Steps

1. ✅ Default variables configured
2. ✅ AWS resource references set
3. ✅ Database configuration defined
4. ✅ Tagging strategy established

**Next**: Continue to **[03-environment-configuration.md](03-environment-configuration.md)** to create environment-specific configurations.

## Summary

You have successfully:
- Created comprehensive default variables for the CF-DB role
- Configured AWS resource references and networking defaults
- Set up database configuration with Aurora PostgreSQL
- Established consistent tagging and timeout strategies
- Validated YAML syntax

The defaults configuration provides a solid foundation that can be customized for different environments while maintaining consistency and security.