# terraform/environments/dev.tfvars
# Development environment configuration

aws_region   = "us-west-2"
project_name = "myapp"
environment  = "dev"

# Use smaller instances for development
instance_type         = "t3.micro"
instance_count        = 1
root_volume_size      = 20

# Database settings for dev
db_instance_class             = "db.t3.micro"
db_allocated_storage          = 20
db_backup_retention_period    = 1
enable_performance_insights   = false
monitoring_interval          = 0

# Networking
allowed_ssh_cidrs = ["0.0.0.0/0"] # Should be restricted to your office/VPN IP
enable_nat_gateway = false

# Logging
log_retention_days = 7
enable_alb_logs = false

additional_tags = {
  Environment = "development"
  AutoShutdown = "yes"
}