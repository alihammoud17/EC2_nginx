# terraform/outputs.tf

# Network Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

# Security Group Outputs
output "web_security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

# EC2 Outputs
output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = aws_instance.web[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of the EC2 instances"
  value       = aws_instance.web[*].public_ip
}

output "instance_private_ips" {
  description = "Private IP addresses of the EC2 instances"
  value       = aws_instance.web[*].private_ip
}

output "instance_dns_names" {
  description = "Public DNS names of the EC2 instances"
  value       = aws_instance.web[*].public_dns
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.web.id
}

# Key Pair Output
output "key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.main.key_name
}

# Load Balancer Outputs
output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "load_balancer_url" {
  description = "URL of the load balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.web.arn
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "RDS username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.postgres.identifier
}

output "rds_resource_id" {
  description = "RDS instance resource ID"
  value       = aws_db_instance.postgres.resource_id
}

output "rds_availability_zone" {
  description = "RDS instance availability zone"
  value       = aws_db_instance.postgres.availability_zone
}

output "database_connection_string" {
  description = "Database connection string"
  value       = "postgresql://${aws_db_instance.postgres.username}:${var.db_password}@${aws_db_instance.postgres.endpoint}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app_storage.bucket
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.app_storage.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.app_storage.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.app_storage.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.app_storage.bucket_regional_domain_name
}

output "s3_bucket_hosted_zone_id" {
  description = "Hosted zone ID of the S3 bucket"
  value       = aws_s3_bucket.app_storage.hosted_zone_id
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.app_storage.region
}

# ALB Logs S3 Bucket (if enabled)
output "alb_logs_bucket_name" {
  description = "Name of the ALB logs S3 bucket"
  value       = var.enable_alb_logs ? aws_s3_bucket.alb_logs[0].bucket : null
}

# IAM Outputs
output "ec2_iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2_s3_role.arn
}

output "ec2_iam_role_name" {
  description = "Name of the EC2 IAM role"
  value       = aws_iam_role.ec2_s3_role.name
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_logs.arn
}

# Application Information
output "application_urls" {
  description = "Application URLs"
  value = {
    load_balancer = "http://${aws_lb.main.dns_name}"
    health_check  = "http://${aws_lb.main.dns_name}/health"
    instances = [
      for instance in aws_instance.web :
      "http://${instance.public_ip}"
    ]
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = [
    for i, instance in aws_instance.web :
    "ssh -i ~/.ssh/${aws_key_pair.main.key_name}.pem ubuntu@${instance.public_ip}"
  ]
  sensitive = true
}

# Environment Information
output "environment_info" {
  description = "Environment information"
  value = {
    project_name = var.project_name
    environment  = var.environment
    region       = var.aws_region
    instance_count = var.instance_count
    database_engine = "postgres"
    database_version = var.postgres_version
  }
}

# Resource Tags
output "common_tags" {
  description = "Common tags applied to resources"
  value = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}