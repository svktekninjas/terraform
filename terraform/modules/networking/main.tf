# Networking Module for ROSA CLI Integration
# Creates VPC and subnets that will be passed to ROSA CLI via --subnet-ids

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Use provided AZs or get first 3 available ones
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
  
  # Tags
  common_tags = merge(
    var.tags,
    {
      Module = "networking"
      Purpose = "ROSA-Infrastructure"
    }
  )
}

# =============================================================================
# VPC CONFIGURATION
# =============================================================================

resource "aws_vpc" "rosa_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "rosa_igw" {
  vpc_id = aws_vpc.rosa_vpc.id
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# =============================================================================
# PUBLIC SUBNETS (for Load Balancers and NAT Gateways)
# =============================================================================

resource "aws_subnet" "public_subnets" {
  count = length(local.azs)
  
  vpc_id                  = aws_vpc.rosa_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-subnet-${count.index + 1}"
    Type = "Public"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# =============================================================================
# PRIVATE SUBNETS (for ROSA Cluster Nodes)
# =============================================================================

resource "aws_subnet" "private_subnets" {
  count = length(local.azs)
  
  vpc_id            = aws_vpc.rosa_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-private-subnet-${count.index + 1}"
    Type = "Private"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# =============================================================================
# NAT GATEWAYS (for Private Subnet Internet Access)
# =============================================================================

resource "aws_eip" "nat_eips" {
  count = var.single_nat_gateway ? 1 : length(local.azs)
  
  domain = "vpc"
  depends_on = [aws_internet_gateway.rosa_igw]
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "nat_gateways" {
  count = var.single_nat_gateway ? 1 : length(local.azs)
  
  allocation_id = aws_eip.nat_eips[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-gw-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.rosa_igw]
}

# =============================================================================
# ROUTE TABLES
# =============================================================================

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.rosa_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rosa_igw.id
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

# Private Route Tables
resource "aws_route_table" "private_rt" {
  count = var.single_nat_gateway ? 1 : length(local.azs)
  
  vpc_id = aws_vpc.rosa_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateways[var.single_nat_gateway ? 0 : count.index].id
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-private-rt-${count.index + 1}"
  })
}

# =============================================================================
# ROUTE TABLE ASSOCIATIONS
# =============================================================================

# Public Subnet Associations
resource "aws_route_table_association" "public_rta" {
  count = length(aws_subnet.public_subnets)
  
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Private Subnet Associations
resource "aws_route_table_association" "private_rta" {
  count = length(aws_subnet.private_subnets)
  
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt[var.single_nat_gateway ? 0 : count.index].id
}

# =============================================================================
# VPC ENDPOINTS (Optional - for Private Clusters)
# =============================================================================

# S3 Gateway Endpoint (Free)
resource "aws_vpc_endpoint" "s3_endpoint" {
  count = var.enable_s3_endpoint ? 1 : 0
  
  vpc_id       = aws_vpc.rosa_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  
  route_table_ids = concat(
    [aws_route_table.public_rt.id],
    aws_route_table.private_rt[*].id
  )
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-s3-endpoint"
  })
}

# EC2 Interface Endpoint (for private clusters)
resource "aws_vpc_endpoint" "ec2_endpoint" {
  count = var.enable_private_endpoints ? 1 : 0
  
  vpc_id            = aws_vpc.rosa_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_endpoint_type = "Interface"
  
  subnet_ids = aws_subnet.private_subnets[*].id
  
  security_group_ids = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-ec2-endpoint"
  })
}

# ELB Interface Endpoint (for private clusters)
resource "aws_vpc_endpoint" "elb_endpoint" {
  count = var.enable_private_endpoints ? 1 : 0
  
  vpc_id            = aws_vpc.rosa_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.elasticloadbalancing"
  vpc_endpoint_type = "Interface"
  
  subnet_ids = aws_subnet.private_subnets[*].id
  
  security_group_ids = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-elb-endpoint"
  })
}

# =============================================================================
# SECURITY GROUP FOR VPC ENDPOINTS
# =============================================================================

resource "aws_security_group" "vpc_endpoint_sg" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name_prefix = "${var.cluster_name}-vpc-endpoint-"
  vpc_id      = aws_vpc.rosa_vpc.id
  description = "Security group for VPC endpoints"
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTP from VPC"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc-endpoint-sg"
  })
}