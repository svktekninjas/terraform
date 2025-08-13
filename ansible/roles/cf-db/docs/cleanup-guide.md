# CF-DB Role Cleanup Guide

## Overview

The `db_cleanup.yml` task provides comprehensive cleanup of all Aurora database resources and associated network infrastructure created by the cf-db role. This task leverages all existing role variables and configurations to systematically remove resources in the correct dependency order.

## ⚠️ Important Safety Warnings

- **DATA LOSS**: This cleanup will **PERMANENTLY DELETE** all database data
- **IRREVERSIBLE**: Once executed, resources cannot be recovered
- **PRODUCTION RISK**: Use extreme caution in production environments
- **CONFIRMATION REQUIRED**: Interactive confirmation prompt prevents accidental execution

## Resources Cleaned Up

### Phase 1: Database Resources
- Aurora DB cluster instances (writer and reader)
- Aurora DB cluster
- DB subnet group

### Phase 2: VPC Peering (if enabled)
- VPC peering connection
- Cross-VPC routing entries

### Phase 3: Security Groups
- Aurora-specific security groups
- Associated ingress/egress rules

### Phase 4: NAT Gateway Resources
- NAT Gateway
- Elastic IP allocation

### Phase 5: Network Subnets
- Private subnets (all AZs)
- Subnet route table associations

### Phase 6: Route Tables
- Private route tables
- Custom routing entries

### Resources Preserved
- ✅ Main VPC (untouched)
- ✅ Public subnets (untouched)
- ✅ ROSA cluster resources (untouched)
- ✅ Internet Gateway (untouched)

## Usage Examples

### Basic Cleanup (Interactive)
```bash
# Full cleanup with interactive confirmation
ansible-playbook playbooks/main.yml -t db-cleanup -e cf_db_environment=dev

# Target specific environment
ansible-playbook playbooks/main.yml -t db-cleanup -e cf_db_environment=prod
```

### Automated Cleanup (Non-Interactive)
```bash
# Skip confirmation prompt (dangerous!)
ansible-playbook playbooks/main.yml -t db-cleanup -e cf_db_environment=dev -e cf_db_cleanup_confirmation=DELETE
```

### Selective Phase Cleanup
```bash
# Database resources only
ansible-playbook playbooks/main.yml -t cleanup-database -e cf_db_environment=dev

# VPC peering only
ansible-playbook playbooks/main.yml -t cleanup-vpc-peering -e cf_db_environment=dev

# Security groups only
ansible-playbook playbooks/main.yml -t cleanup-security-groups -e cf_db_environment=dev

# NAT Gateway only
ansible-playbook playbooks/main.yml -t cleanup-nat-gateway -e cf_db_environment=dev

# Subnets only
ansible-playbook playbooks/main.yml -t cleanup-subnets -e cf_db_environment=dev

# Route tables only
ansible-playbook playbooks/main.yml -t cleanup-route-tables -e cf_db_environment=dev
```

## Configuration Variables Used

The cleanup task leverages all existing cf-db role variables:

### From `defaults/main.yml`:
- `cf_db_defaults.region`
- `cf_db_defaults.profile`
- `cf_db_defaults.availability_zones`

### From Environment Config (`environments/{env}/cf-db.yml`):
- `cf_db_config.database.cluster_name`
- `cf_db_config.database.instances[]`
- `cf_db_config.db_subnet_group.name`
- `cf_db_config.security_group.name`
- `cf_db_config.private_subnets[]`
- `cf_db_config.route_table.name`
- `cf_db_config.vpc_peering.*`
- `cf_db_config.common_tags.Environment`

## Execution Flow

1. **Pre-Cleanup Validation**
   - Display warning and resource summary
   - Interactive confirmation (unless bypassed)
   - Validate environment variables

2. **Resource Deletion** (7 Phases)
   - Phase 1: Aurora instances → cluster → subnet group
   - Phase 2: VPC peering connections and routes
   - Phase 3: Security groups and rules
   - Phase 4: NAT Gateway → wait for deletion → release EIP
   - Phase 5: Private subnets (all AZs)
   - Phase 6: Custom route tables
   - Phase 7: Verification and summary

3. **Post-Cleanup Verification**
   - Verify critical resources are deleted
   - Display cleanup summary
   - Show preserved resources
   - Provide next steps

## Safety Features

### Interactive Confirmation
```
⚠️  DANGER ZONE ⚠️

You are about to PERMANENTLY DELETE all Aurora database resources!
This action CANNOT be undone and will result in DATA LOSS.

Type 'DELETE' (in capitals) to confirm destruction, or press Ctrl+C to cancel:
```

### Dependency-Aware Deletion
- DB instances deleted before cluster
- NAT Gateway deletion waits for completion before EIP release
- Security groups deleted after DB resources
- Subnets deleted after NAT Gateway

### Error Handling
- `ignore_errors: yes` prevents partial failures from stopping cleanup
- Multiple retries with delays for AWS API eventual consistency
- Graceful handling of already-deleted resources

## Environment Examples

### Development Environment
```bash
# Safe cleanup for dev environment
ansible-playbook playbooks/main.yml -t db-cleanup -e cf_db_environment=dev
```

### Production Environment
```bash
# Extra caution recommended for production
ansible-playbook playbooks/main.yml -t db-cleanup -e cf_db_environment=prod

# Consider taking final backup first:
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier cf-aurora-pg-cluster-prod \
  --db-cluster-snapshot-identifier final-backup-$(date +%Y%m%d-%H%M%S)
```

## Troubleshooting

### Common Issues

**Resource Dependencies**
```
Error: Cannot delete subnet - dependencies exist
Solution: Re-run cleanup, dependency order will resolve automatically
```

**VPC Peering Routes**
```
Error: Route table route not found
Solution: Expected behavior - routes may already be deleted
```

**Aurora Instance Deletion Timeout**
```
Error: Instance still deleting after 15 minutes
Solution: Increase timeout or check AWS console for manual intervention
```

### Verification Commands

Check remaining resources:
```bash
# Check Aurora resources
aws rds describe-db-clusters --region us-west-1 \
  --db-cluster-identifier cf-aurora-pg-cluster-dev

# Check subnets
aws ec2 describe-subnets --region us-west-1 \
  --filters "Name=tag:Name,Values=cf-private-subnet-dev-*"

# Check security groups
aws ec2 describe-security-groups --region us-west-1 \
  --filters "Name=group-name,Values=cf-aurora-db-sg-dev"
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Cleanup Development Database
  run: |
    ansible-playbook playbooks/main.yml \
      -t db-cleanup \
      -e cf_db_environment=dev \
      -e cf_db_cleanup_confirmation=DELETE
  when: github.event.inputs.cleanup_dev == 'true'
```

### Terraform Integration
```hcl
resource "null_resource" "db_cleanup" {
  triggers = {
    cleanup_trigger = var.cleanup_database
  }
  
  provisioner "local-exec" {
    command = "ansible-playbook playbooks/main.yml -t db-cleanup -e cf_db_environment=${var.environment} -e cf_db_cleanup_confirmation=DELETE"
  }
}
```

## Best Practices

1. **Always backup before cleanup** (if data is valuable)
2. **Test cleanup in dev environment first**
3. **Use selective phase cleanup for troubleshooting**
4. **Verify cleanup completion with AWS console**
5. **Update application configurations after cleanup**
6. **Monitor AWS billing to confirm resource removal**

## Next Steps After Cleanup

1. Remove database connection strings from applications
2. Update DNS entries if custom endpoints were used
3. Clean up any secrets or ConfigMaps in OpenShift
4. Remove monitoring dashboards for deleted resources
5. Update documentation to reflect infrastructure changes