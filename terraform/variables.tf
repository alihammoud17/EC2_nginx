# terraform/variables.tf

# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"

  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format: us-west-2, eu-west-1, etc."
  }
}

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "myapp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# Networking Configuration
variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets"
  type        = bool
  default     = false
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition = can(regex("^[tm][3-7]\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", var.instance_type))
    error_message = "Instance type must be a valid EC2 instance type (e.g., t3.micro, m5.large)."
  }
}

variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "Root volume size must be between 8 and 1000 GB."
  }
}

variable "public_key" {
  description = "Public key for EC2 key pair"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3}( .*)?$", var.public_key))
    error_message = "Public key must be a valid SSH RSA public key."
  }
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000

  validation {
    condition     = var.app_port > 1024 && var.app_port < 65535
    error_message = "Application port must be between 1024 and 65535."
  }
}

# Database Configuration
variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15.4"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.postgres_version))
    error_message = "PostgreSQL version must be in format X.Y (e.g., 15.4)."
  }
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition = can(regex("^db\\.[tm][3-7]\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", var.db_instance_class))
    error_message = "DB instance class must be a valid RDS instance type (e.g., db.t3.micro, db.m5.large)."
  }
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 65536
    error_message = "DB allocated storage must be between 20 and 65536 GB."
  }
}

variable "db_max_allocated_storage" {
  description = "RDS maximum allocated storage in GB"
  type        = number
  default     = 100

  validation {
    condition     = var.db_max_allocated_storage >= var.db_allocated_storage
    error_message = "DB maximum allocated storage must be greater than or equal to allocated storage."
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "dbadmin"

  validation {
    condition     = length(var.db_username) >= 1 && length(var.db_username) <= 63
    error_message = "Database username must be between 1 and 63 characters."
  }
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 128
    error_message = "Database password must be between 8 and 128 characters long."
  }
}

variable "db_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "enable_performance_insights" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "RDS enhanced monitoring interval in seconds"
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

# S3 Configuration
variable "s3_enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_enable_encryption" {
  description = "Enable S3 bucket encryption"
  type        = bool
  default     = true
}

# Load Balancer Configuration
variable "enable_alb_logs" {
  description = "Enable ALB access logs"
  type        = bool
  default     = false
}

# Monitoring and Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14

  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}