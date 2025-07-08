# ROSA Terraform Infrastructure as Code

Complete Terraform infrastructure solution for Red Hat OpenShift Service on AWS (ROSA) deployment with ROSA CLI integration.

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- ROSA CLI installed and logged in
- Terraform >= 1.0
- jq for JSON processing

### 1. Validate Environment
```bash
./scripts/validate-rosa.sh prod us-east-1
```

### 2. Configure Variables
```bash
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific configuration
```

### 3. Deploy ROSA Cluster
```bash
./scripts/deploy-rosa.sh prod my-rosa-cluster us-east-1
```

## 📁 Project Structure

```
├── terraform/
│   ├── variables.tf                    # Master variables for ROSA CLI
│   ├── modules/
│   │   ├── networking/                 # VPC, subnets, security groups
│   │   ├── security/                   # KMS keys, security groups
│   │   ├── storage/                    # S3 buckets for registry/backup
│   │   ├── compute/                    # ROSA cluster via CLI
│   │   ├── monitoring/                 # CloudWatch logs, alarms
│   │   ├── backup/                     # AWS Backup, S3 lifecycle
│   │   └── validation/                 # Pre/post deployment checks
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/                       # Production configuration
├── scripts/
│   ├── deploy-rosa.sh                  # Main deployment script
│   ├── validate-rosa.sh                # Prerequisites validation
│   └── cleanup-rosa.sh                 # Safe cluster deletion
└── docs/
    ├── README.md                       # This file
    └── [additional documentation]
```

## 🔧 How It Works

This solution follows **Option 2** approach: Pre-create networking infrastructure, then pass subnet IDs to ROSA CLI for cluster creation.

### Integration Flow:
1. **Terraform creates**: VPC, subnets, security groups, KMS keys, S3 buckets
2. **ROSA CLI creates**: Cluster, IAM roles, OIDC provider, admin user
3. **Terraform manages**: Monitoring, backup, validation

### Key Features:
- ✅ **ROSA CLI Integration**: Full cluster lifecycle management
- ✅ **Networking Control**: Custom VPC or use existing subnets
- ✅ **Security**: KMS encryption, STS authentication
- ✅ **Production Ready**: Multi-AZ, autoscaling, monitoring
- ✅ **Validation**: Pre/post deployment checks
- ✅ **Automation**: Complete deployment scripts

## 📊 Module Overview

### Core Modules (High Priority)
| Module | Purpose | ROSA CLI Integration |
|--------|---------|---------------------|
| `networking` | VPC, subnets, NAT gateways | Subnet IDs via `--subnet-ids` |
| `security` | KMS keys, security groups | KMS ARN via `--kms-key-arn` |
| `storage` | S3 buckets (optional) | ROSA auto-creates registry |
| `compute` | ROSA cluster creation | Executes all ROSA CLI commands |

### Operational Modules (Medium Priority)
| Module | Purpose | Integration |
|--------|---------|-------------|
| `monitoring` | CloudWatch logs, alarms | Complements ROSA monitoring |
| `backup` | AWS Backup, S3 lifecycle | Backup cluster data |
| `validation` | Pre/post deployment checks | Validates configuration |

## 🌐 Deployment Options

### Option 1: Use Existing Subnets
```hcl
# In terraform.tfvars
subnet_ids = [
  "subnet-12345678",  # Private subnet AZ-1
  "subnet-87654321",  # Private subnet AZ-2
  "subnet-11111111"   # Private subnet AZ-3
]
```

### Option 2: Create New VPC
```hcl
# In terraform.tfvars
subnet_ids = []  # Empty = create new VPC
machine_cidr = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
```

## 🔐 Security Configuration

### STS Authentication (Recommended)
```hcl
enable_sts = true
# Leave role ARNs empty for auto-creation
role_arn = ""
support_role_arn = ""
operator_roles_prefix = ""
oidc_config_id = ""
```

### KMS Encryption
```hcl
# Security module creates KMS key
# Compute module uses it via --kms-key-arn
```

## 📈 Production Configuration

### Sizing (Production)
- **Control Plane**: 3x m5.2xlarge (managed by ROSA)
- **Infrastructure**: 2x r5.xlarge (managed by ROSA)
- **Workers**: 6x m5.xlarge (autoscaling 6-20)

### Features Enabled
- Multi-AZ deployment
- FIPS mode
- etcd encryption
- Cross-region backup
- CloudWatch monitoring
- Automatic scaling

## 🛠️ Manual Operations

### Check Cluster Status
```bash
rosa describe cluster --cluster=my-rosa-cluster
```

### Create Admin User
```bash
rosa create admin --cluster=my-rosa-cluster
```

### View Install Logs
```bash
rosa logs install --cluster=my-rosa-cluster --watch
```

### Scale Workers
```bash
rosa edit machinepool --cluster=my-rosa-cluster --replicas=10 worker
```

## 🚨 Troubleshooting

### Common Issues

1. **Cluster Creation Fails**
   ```bash
   # Check quota
   rosa verify quota --region=us-east-1
   
   # Check permissions
   rosa verify permissions
   
   # View logs
   rosa logs install --cluster=my-cluster --watch
   ```

2. **Terraform State Issues**
   ```bash
   # Refresh state
   terraform refresh
   
   # Import existing resources
   terraform import module.networking.aws_vpc.rosa_vpc vpc-12345678
   ```

3. **Network Connectivity**
   ```bash
   # Check VPC endpoints
   aws ec2 describe-vpc-endpoints --region=us-east-1
   
   # Check security groups
   aws ec2 describe-security-groups --region=us-east-1
   ```

### Validation Commands
```bash
# Pre-deployment validation
./scripts/validate-rosa.sh prod us-east-1

# Check all resources
terraform plan
terraform show

# Test cluster connectivity
oc get nodes
oc get clusteroperators
```

## 💰 Cost Optimization

### Estimated Monthly Costs (Production)
- **Cluster Base**: ~$300-400 (control plane)
- **Worker Nodes**: ~$600-2000 (6-20 m5.xlarge)
- **Storage**: ~$50-200 (EBS + S3)
- **Monitoring**: ~$10-50 (CloudWatch)
- **Backup**: ~$20-100 (AWS Backup)
- **Total**: ~$980-2750/month

### Cost Savings
- Use spot instances for dev/test
- Enable cluster autoscaling
- Optimize storage with lifecycle policies
- Use Reserved Instances for predictable workloads

## 📋 Environment-Specific Configurations

### Development
```hcl
worker_node_count = 2
enable_autoscaling = false
enable_cross_region_backup = false
cloudwatch_log_retention_days = 7
single_nat_gateway = true
```

### Staging
```hcl
worker_node_count = 3
enable_autoscaling = true
enable_cross_region_backup = false
cloudwatch_log_retention_days = 30
single_nat_gateway = false
```

### Production
```hcl
worker_node_count = 6
enable_autoscaling = true
enable_cross_region_backup = true
cloudwatch_log_retention_days = 90
single_nat_gateway = false
```

## 🔄 Maintenance

### Cluster Updates
```bash
# List available versions
rosa list versions

# Upgrade cluster
rosa upgrade cluster --cluster=my-cluster --version=4.14.8

# Upgrade machine pools
rosa upgrade machinepool --cluster=my-cluster --version=4.14.8 worker
```

### Infrastructure Updates
```bash
# Update Terraform
terraform plan
terraform apply

# Update variables
vim terraform/environments/prod/terraform.tfvars
terraform plan
terraform apply
```

## 🗑️ Cleanup

### Delete Cluster
```bash
./scripts/cleanup-rosa.sh my-rosa-cluster prod false us-east-1
```

### Force Delete (No Prompts)
```bash
./scripts/cleanup-rosa.sh my-rosa-cluster prod true us-east-1
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review ROSA documentation
3. Check AWS service limits
4. Validate prerequisites with `./scripts/validate-rosa.sh`

---

**Note**: This infrastructure solution is designed for production use but should be tested in development environments first. Always validate configurations and understand the implications of infrastructure changes.