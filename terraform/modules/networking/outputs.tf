# Outputs for Networking Module
# These will be used by ROSA CLI via --subnet-ids parameter

output "vpc_id" {
  description = "ID of the VPC created for ROSA cluster"
  value       = aws_vpc.rosa_vpc.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.rosa_vpc.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of private subnets (pass to ROSA CLI --subnet-ids)"
  value       = aws_subnet.private_subnets[*].id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  value       = aws_subnet.private_subnets[*].cidr_block
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = aws_subnet.public_subnets[*].cidr_block
}

output "availability_zones" {
  description = "Availability zones used"
  value       = aws_subnet.private_subnets[*].availability_zone
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.rosa_igw.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = aws_nat_gateway.nat_gateways[*].id
}

output "rosa_subnet_ids_string" {
  description = "Comma-separated string of private subnet IDs for ROSA CLI --subnet-ids parameter"
  value       = join(",", aws_subnet.private_subnets[*].id)
}

output "rosa_availability_zones_string" {
  description = "Comma-separated string of availability zones for ROSA CLI --availability-zones parameter"
  value       = join(",", aws_subnet.private_subnets[*].availability_zone)
}