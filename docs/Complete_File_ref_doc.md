# Complete File Reference Documentation

This document provides comprehensive documentation for all files in the Infrastructure as Code project, including their purpose, structure, and key configurations.

## 📁 Project Structure Overview

```
infrastructure-project/
├── terraform/                 # Infrastructure definitions (8 files)
├── ansible/                   # Configuration management (25+ files)
├── deployment-scripts/        # Automation scripts (2 files)
├── docs/                      # Documentation (this file)
├── backups/                   # State backups (generated)
├── Makefile                   # Project automation
├── README.md                  # Project overview
├── .gitignore                 # Git ignore patterns
└── .env.example              # Environment variables template
```

---

## 🏗️ Terraform Infrastructure Files

### `terraform/main.tf`

**Purpose**: Main Terraform configuration defining all AWS infrastructure resources.

**Key Resources**:

- **VPC and Networking**: VPC, public/private subnets, internet gateway, NAT gateway, route tables
- **Security Groups**: Web servers, RDS database, Application Load Balancer
- **Compute**: EC2 instances with launch templates, auto-scaling ready
- **Database**: RDS PostgreSQL with multi-AZ, encryption, automated backups
- **Storage**: S3 buckets with versioning, encryption, lifecycle policies
- **Load Balancing**: Application Load Balancer with health checks
- **Monitoring**: CloudWatch log groups, enhanced RDS monitoring
- **IAM**: EC2 instance profiles, S3 access roles, RDS monitoring roles

**Key Features**:

- Multi-AZ deployment for high availability
- Encrypted storage (EBS, RDS, S3)
- Network isolation with private subnets for databases
- Auto-scaling capable with launch templates
- Comprehensive tagging strategy

```hcl
# Example resource structure
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  # ... tags and configuration
}
```

### `terraform/variables.tf`

**Purpose**: Defines all input variables with validation rules and default values.

**Variable Categories**:

- **AWS Configuration**: Region, credentials
- **Project Settings**: Name, environment, tags
- **Networking**: CIDR blocks, NAT gateway settings
- **Compute**: Instance types, counts, storage sizes
- **Database**: Engine versions, instance classes, backup settings
- **Storage**: S3 versioning, encryption settings
- **Security**: SSH key pairs, allowed CIDR ranges

**Key Features**:

- Input validation for all critical variables
- Environment-specific defaults
- Security-focused constraints (password complexity, CIDR validation)
- Resource sizing guidelines

### `terraform/outputs.tf`

**Purpose**: Defines infrastructure outputs for Ansible integration and external consumption.

**Output Categories**:

- **Network Information**: VPC ID, subnet IDs, security groups
- **Compute Details**: Instance IPs, DNS names, SSH commands
- **Database Connection**: Endpoints, ports, connection strings
- **Storage Access**: S3 bucket names, ARNs, regional endpoints
- **Load Balancer**: DNS names, health check URLs
- **Application URLs**: Complete access information

**Integration Points**:

```hcl
output "application_urls" {
  value = {
    load_balancer = "http://${aws_lb.main.dns_name}"
    health_check  = "http://${aws_lb.main.dns_name}/health"
    instances     = [for instance in aws_instance.web : "http://${instance.public_ip}"]
  }
}
```

### `terraform/user_data.sh`

**Purpose**: EC2 initialization script that bootstraps instances with required software and configuration.

**Installation Steps**:

1. System updates and essential packages
2. AWS CLI v2 installation and configuration
3. CloudWatch Agent setup
4. Docker installation and configuration
5. Node.js 18.x runtime setup
6. PM2 process manager installation
7. PostgreSQL client tools
8. Nginx web server configuration
9. Security tools (fail2ban, ufw firewall)

**Configuration Features**:

- Application directory structure creation
- Environment variables setup from Terraform
- Database and S3 connectivity testing
- Sample Node.js application deployment
- System service creation and startup
- Monitoring and health check scripts
- Log rotation configuration

### `terraform/terraform.tfvars.example`

**Purpose**: Template file showing all configurable variables with examples and documentation.

**Sections**:

- AWS region and credentials configuration
- Project naming and environment settings
- Instance sizing and networking
- Database configuration with security notes
- S3 storage options
- Monitoring and logging settings
- Environment-specific examples (dev/staging/prod)

### Environment-Specific Configuration Files

#### `terraform/environments/dev.tfvars`

**Purpose**: Development environment configuration with minimal resources.

- Small instance types (t3.micro)
- Single instance deployment
- Minimal database storage
- Reduced backup retention
- Development-friendly security settings

#### `terraform/environments/staging.tfvars`

**Purpose**: Staging environment configuration mirroring production.

- Medium instance types (t3.small)
- Multi-instance deployment
- Production-like database settings
- Standard backup retention
- Production security practices

#### `terraform/environments/prod.tfvars`

**Purpose**: Production environment configuration optimized for performance and reliability.

- Larger instance types (t3.medium)
- Multi-AZ deployment
- Enhanced monitoring enabled
- Extended backup retention
- Strict security configurations

---

## ⚙️ Ansible Configuration Management Files

### Core Configuration Files

#### `ansible/ansible.cfg`

**Purpose**: Ansible behavior configuration and performance optimization.

**Key Settings**:

- **Connection**: SSH optimization, connection pooling, timeouts
- **Performance**: Parallel execution (forks), pipelining
- **Security**: Host key checking, privilege escalation
- **Output**: YAML callback, logging configuration
- **Inventory**: Plugin configuration, fact caching

#### `ansible/requirements.yml`

**Purpose**: Defines required Ansible collections and roles.

**Collections**:

- `community.general`: General-purpose modules
- `community.postgresql`: Database management
- `amazon.aws`: AWS service integration
- `community.crypto`: SSL/TLS certificate management
- `community.docker`: Container management

#### `ansible/site.yml`

**Purpose**: Main deployment playbook orchestrating complete server configuration.

**Deployment Phases**:

1. **Pre-tasks**: System updates, user creation, directory structure
2. **AWS Services**: AWS CLI, CloudWatch agent installation
3. **Database Setup**: PostgreSQL client, connectivity testing
4. **Application Runtime**: Node.js, PM2, Docker installation
5. **Web Server**: Nginx configuration and security headers
6. **SSL/TLS**: Certificate management (self-signed/Let's Encrypt)
7. **Application**: Environment configuration, service setup
8. **Monitoring**: Health checks, system monitoring, log rotation
9. **Security**: Firewall, Fail2Ban, SSH hardening
10. **Verification**: Service checks, connectivity testing

### Inventory Configuration

#### `ansible/inventory/hosts.yml`

**Purpose**: Static inventory template with comprehensive variable structure.

**Host Groups**:

- **webservers**: Application servers with load balancing
- **databases**: RDS metadata and connection information
- **loadbalancers**: ALB configuration and health checks

**Variable Hierarchy**:

```yaml
all:
  vars:         # Global variables
  children:
    webservers:
      hosts:    # Individual server configuration
      vars:     # Group-specific variables
```

#### `ansible/inventory/group_vars/all/main.yml`

**Purpose**: Global variables applied to all hosts.

**Categories**:

- **System Configuration**: Timezone, NTP servers, kernel parameters
- **Security Settings**: SSH configuration, user management
- **Logging**: Centralized logging, retention policies
- **Monitoring**: Metrics collection, alert thresholds
- **Backup**: Automated backup schedules and retention

#### `ansible/inventory/group_vars/webservers.yml`

**Purpose**: Web server specific configuration and optimization.

**Features**:

- Nginx configuration templates
- Node.js application settings
- PM2 process management
- System service definitions
- Firewall rules and security policies

#### `ansible/inventory/host_vars/web-1.yml` & `ansible/inventory/host_vars/web-2.yml`

**Purpose**: Host-specific configurations for primary and secondary servers.

**Primary Server (web-1)**:

- Database backup responsibilities
- Cron job management
- Enhanced monitoring and alerting
- Master configuration for distributed tasks

**Secondary Server (web-2)**:

- Minimal cron jobs
- Standard monitoring
- Follower configuration
- Resource optimization

### Ansible Templates

#### `ansible/templates/nginx.conf.j2`

**Purpose**: Nginx reverse proxy configuration with security and performance optimization.

**Features**:

- **Security Headers**: XSS protection, content type validation, frame options
- **Rate Limiting**: API endpoint protection, login attempt limiting
- **SSL/TLS Support**: Modern cipher suites, HSTS headers
- **Performance**: Gzip compression, static file caching, connection optimization
- **Health Checks**: Dedicated health check endpoints
- **Logging**: Structured access and error logging

```nginx
# Example security configuration
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
```

#### `ansible/templates/app.env.j2`

**Purpose**: Application environment configuration with comprehensive variable management.

**Configuration Sections**:

- **Database**: Connection strings, pool settings, SSL configuration
- **S3 Storage**: Bucket configuration, path structures, regional settings
- **Application**: Runtime settings, feature flags, performance tuning
- **Security**: JWT secrets, encryption settings, session management
- **Monitoring**: Metrics endpoints, logging levels, health check timeouts
- **External Services**: Redis, Elasticsearch, SMTP configuration

#### `ansible/templates/app.service.j2`

**Purpose**: Systemd service definition for application process management.

**Service Features**:

- **Process Management**: Restart policies, timeout configuration
- **Security**: Sandboxing, privilege restrictions, resource limits
- **Monitoring**: Process tracking, log management
- **Dependencies**: Service ordering, requirement definitions
- **Resource Limits**: Memory, CPU, file descriptor limits

#### `ansible/templates/health_check.sh.j2`

**Purpose**: Comprehensive health monitoring script for all system components.

**Health Check Components**:

- **Application**: HTTP endpoint testing, process verification
- **Database**: Connection testing, query execution
- **Storage**: S3 connectivity, permission verification
- **System Resources**: Disk space, memory usage, load average
- **Services**: Nginx, Docker, application process status
- **Logging**: Structured logging with timestamps and severity levels

#### `ansible/templates/system_monitor.sh.j2`

**Purpose**: System metrics collection and CloudWatch integration.

**Metrics Collection**:

- **CPU**: Usage percentages, load averages
- **Memory**: Total, used, free, percentage utilization
- **Disk**: Space usage, I/O statistics
- **Network**: Bytes transferred, connection counts
- **Application**: Process counts, resource usage
- **CloudWatch**: Metric publishing, custom namespace

#### `ansible/templates/init_db.sql.j2`

**Purpose**: Database initialization with complete application schema.

**Database Structure**:

- **Extensions**: UUID generation, cryptographic functions, statistics
- **Schema**: Application-specific schema with proper permissions
- **Tables**: Users, sessions, files (S3 integration), settings, notifications, API keys
- **Indexes**: Performance optimization for common queries
- **Triggers**: Automated timestamp updates, audit logging
- **Views**: Active users, simplified data access
- **Security**: Role-based access, permission management

```sql
-- Example table with S3 integration
CREATE TABLE IF NOT EXISTS files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    s3_key VARCHAR(500) NOT NULL,
    s3_bucket VARCHAR(100) NOT NULL DEFAULT 'app-bucket',
    -- ... other fields
);
```

#### `ansible/templates/s3_setup.sh.j2`

**Purpose**: S3 bucket structure initialization and permission testing.

**Setup Features**:

- **Directory Structure**: Organized folder hierarchy for different file types
- **Permission Testing**: Write/read verification with cleanup
- **Lifecycle Policies**: Automated file management and cost optimization
- **CORS Configuration**: Web application upload support
- **Logging**: Comprehensive setup logging with error handling

### Ansible Playbooks

#### `ansible/playbooks/verify.yml`

**Purpose**: Comprehensive deployment verification and system validation.

**Verification Components**:

- **Service Health**: All required services running and accessible
- **Network Connectivity**: Database and S3 access verification
- **Performance Metrics**: System resource utilization checks
- **Security Validation**: SSL certificates, firewall rules
- **Application Testing**: HTTP endpoints, health checks
- **Reporting**: JSON output for integration with monitoring systems

#### `ansible/playbooks/backup.yml`

**Purpose**: Automated backup system for applications, configurations, and data.

**Backup Components**:

- **Application Files**: Code, configuration, static assets
- **Database**: PostgreSQL dumps with compression
- **System Configuration**: Service definitions, certificates
- **Log Files**: Application and system logs
- **S3 Integration**: Cloud storage with metadata
- **Retention Management**: Automated cleanup of old backups

#### `ansible/playbooks/security.yml`

**Purpose**: Security hardening and compliance implementation.

**Security Measures**:

- **System Updates**: Automated security patch installation
- **SSH Hardening**: Key-only authentication, connection limits
- **Firewall Configuration**: UFW rules, port restrictions
- **Intrusion Detection**: AIDE, rkhunter, chkrootkit installation
- **Audit Logging**: System activity monitoring
- **Compliance**: Security baseline implementation

#### `ansible/playbooks/ssl.yml`

**Purpose**: SSL/TLS certificate management and HTTPS configuration.

**SSL Features**:

- **Certificate Generation**: Self-signed for development, Let's Encrypt for production
- **Nginx Integration**: HTTPS configuration, redirect rules
- **Security Configuration**: Modern TLS versions, strong ciphers
- **Automation**: Certificate renewal, validation testing
- **Monitoring**: Certificate expiration checking

---

## 🚀 Deployment Scripts

### `deployment-scripts/deploy.sh`

**Purpose**: Main deployment automation orchestrating Terraform and Ansible.

**Script Capabilities**:

- **Environment Management**: dev/staging/prod configuration
- **Prerequisite Checking**: Tool availability, credential validation
- **State Management**: Backup creation, state recovery
- **Terraform Integration**: Plan, apply, destroy with validation
- **Ansible Integration**: Playbook execution, inventory generation
- **Verification**: Deployment testing, health checks
- **Logging**: Comprehensive logging with timestamps and colors
- **Error Handling**: Graceful failure recovery, state preservation

**Usage Modes**:

```bash
# Standard deployment
./deploy.sh staging apply

# Debug mode with dry run
DEBUG=true DRY_RUN=true ./deploy.sh dev apply

# Infrastructure only
SKIP_ANSIBLE=true ./deploy.sh prod plan
```

### `deployment-scripts/generate_inventory.py`

**Purpose**: Dynamic Ansible inventory generation from Terraform outputs.

**Features**:

- **Terraform Integration**: JSON output parsing and validation
- **Host Configuration**: Dynamic IP assignment, role assignment
- **Group Management**: Webservers, databases, load balancers
- **Variable Assignment**: Environment-specific settings
- **Format Support**: YAML and JSON output formats
- **Validation**: Inventory structure and host reachability
- **Error Handling**: Comprehensive error reporting and recovery

**Generated Structure**:

```yaml
all:
  vars:           # Global configuration
  children:
    webservers:   # Application servers
      hosts:      # Individual server details
      vars:       # Group-specific settings
```

---

## 📋 Project Management Files

### `Makefile`

**Purpose**: Project automation and command standardization.

**Target Categories**:

- **Infrastructure**: init, plan, apply, destroy
- **Verification**: verify, health, logs
- **Maintenance**: backup, clean, security-scan
- **Development**: ssh, ssh-all, debug modes
- **Environment**: dev-apply, staging-apply, prod-apply

**Key Features**:

- Color-coded output for better readability
- Environment variable support
- Help documentation with usage examples
- Error handling and validation
- Integration with all deployment scripts

### `.gitignore`

**Purpose**: Git version control exclusions for security and cleanliness.

**Excluded Categories**:

- **Terraform**: State files, plans, provider cache, variable files
- **Ansible**: Retry files, vault passwords, dynamic inventories
- **Secrets**: Environment files, certificates, private keys
- **Generated**: Output files, logs, temporary files
- **System**: OS-specific files, IDE configurations
- **Dependencies**: Node modules, Python cache, build artifacts

### `.env.example`

**Purpose**: Environment variable template with documentation.

**Variable Categories**:

- **AWS Configuration**: Credentials, regions, profiles
- **Project Settings**: Names, environments, versions
- **Security**: Database passwords, JWT secrets
- **Terraform**: Variable overrides, state configuration
- **Ansible**: Execution options, vault settings
- **Development**: Debug flags, testing options

### `README.md`

**Purpose**: Complete project documentation and usage guide.

**Documentation Sections**:

- **Architecture Overview**: Infrastructure components and relationships
- **Prerequisites**: Required tools and setup instructions
- **Quick Start**: Step-by-step deployment guide
- **Configuration**: Variable reference and examples
- **Usage**: Command reference and advanced options
- **Security**: Best practices and security considerations
- **Monitoring**: Health checks and observability
- **Troubleshooting**: Common issues and solutions

---

## 📊 File Statistics and Metrics

### Code Metrics

- **Total Files**: 35+ configuration and automation files
- **Lines of Code**: 3,000+ lines of Infrastructure as Code
- **Terraform Resources**: 25+ AWS resources provisioned
- **Ansible Tasks**: 100+ automation tasks executed
- **Template Files**: 15+ configuration templates
- **Playbooks**: 4 specialized playbooks for different operations

### Infrastructure Coverage

- **Security Features**: 15+ hardening measures implemented
- **Monitoring Components**: 10+ health checks and metrics
- **Environment Support**: 3 environments (dev/staging/prod)
- **Service Integration**: 8+ AWS services configured
- **Application Stack**: Complete LEMP stack (Linux, Nginx, Node.js, PostgreSQL)

### Automation Capabilities

- **One-Command Deployment**: Complete infrastructure in minutes
- **Zero-Downtime Updates**: Rolling deployment support
- **Automated Testing**: Verification and health checks
- **Disaster Recovery**: Backup and restore procedures
- **Security Scanning**: Automated vulnerability assessment
- **Cost Optimization**: Resource right-sizing and cleanup

---

## 🔗 File Dependencies and Relationships

### Terraform Dependencies

```
main.tf → variables.tf (input validation)
main.tf → user_data.sh (EC2 initialization)
outputs.tf → main.tf (resource references)
environments/*.tfvars → variables.tf (value assignment)
```

### Ansible Dependencies

```
site.yml → templates/*.j2 (configuration generation)
site.yml → inventory/hosts.yml (target definitions)
playbooks/*.yml → templates/*.j2 (specialized configurations)
group_vars/ → host_vars/ (variable inheritance)
```

### Script Dependencies

```
deploy.sh → generate_inventory.py (dynamic inventory)
deploy.sh → terraform/ (infrastructure management)
deploy.sh → ansible/ (configuration management)
Makefile → deploy.sh (command standardization)
```

### Integration Flow

```
Terraform Outputs → Python Script → Ansible Inventory → Playbook Execution → Infrastructure Configuration
```

This comprehensive documentation provides complete coverage of all files in the Infrastructure as Code project, their purposes, relationships, and implementation details. Use this as a reference for understanding, maintaining, and extending the project.