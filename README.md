# Infrastructure as Code Project

This project provides a complete Infrastructure as Code (IaC) solution using Terraform for infrastructure provisioning and Ansible for configuration management. It deploys a scalable web application with PostgreSQL database and S3 storage on AWS.

## 🏗️ Architecture

- **Load Balancer**: Application Load Balancer for high availability
- **Web Servers**: Auto-scaled EC2 instances running Node.js applications
- **Database**: RDS PostgreSQL with automated backups
- **Storage**: S3 bucket for file storage and static assets
- **Monitoring**: CloudWatch integration with custom metrics
- **Security**: VPC with public/private subnets, security groups, and SSL/TLS

## 📋 Prerequisites

### Required Tools

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide) >= 6.0
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [Python 3](https://www.python.org/downloads/) >= 3.8
- [jq](https://stedolan.github.io/jq/) for JSON processing

### AWS Configuration

```bash
# Configure AWS credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-2"
```

### SSH Key Setup

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Add your public key to terraform.tfvars
echo "public_key = \"$(cat ~/.ssh/id_rsa.pub)\"" >> terraform/terraform.tfvars
```

## 🚀 Quick Start

### 1. Clone and Initialize

```bash
git clone <repository-url>
cd infrastructure-project
make init
```

### 2. Configure Variables

```bash
# Copy and edit Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars

# Set up Ansible vault for secrets
ansible-vault create ansible/inventory/group_vars/all/vault.yml
```

### 3. Deploy Infrastructure

```bash
# Development environment
make dev-apply

# Staging environment
make staging-apply

# Production environment
make prod-apply
```

### 4. Verify Deployment

```bash
make verify ENV=dev
make health ENV=dev
```

## 📁 Project Structure

```
infrastructure-project/
├── terraform/                 # Infrastructure definitions
│   ├── main.tf                # Main infrastructure
│   ├── variables.tf           # Variable definitions
│   ├── outputs.tf             # Output definitions
│   ├── user_data.sh           # EC2 initialization
│   └── environments/          # Environment-specific configs
├── ansible/                   # Configuration management
│   ├── site.yml               # Main playbook
│   ├── inventory/             # Host inventories
│   ├── templates/             # Configuration templates
│   └── playbooks/             # Additional playbooks
├── deployment-scripts/        # Automation scripts
│   ├── deploy.sh              # Main deployment script
│   └── generate_inventory.py  # Dynamic inventory
├── Makefile                   # Project automation
└── README.md                  # This file
```

## 🛠️ Usage

### Environment Management

```bash
# Plan changes
make plan ENV=dev

# Deploy infrastructure
make apply ENV=staging

# Destroy infrastructure
make destroy ENV=dev
```

### Maintenance Operations

```bash
# SSH into servers
make ssh ENV=prod
make ssh-all ENV=prod

# View application logs
make logs ENV=prod

# Health check
make health ENV=prod

# Create backup
make backup ENV=prod

# Security scan
make security-scan ENV=prod

# Setup SSL
make ssl-setup ENV=prod

# Clean temporary files
make clean
```

### Advanced Options

```bash
# Dry run (show what would be done)
DRY_RUN=true make apply ENV=dev

# Skip Terraform or Ansible
SKIP_TERRAFORM=true make apply ENV=dev
SKIP_ANSIBLE=true make apply ENV=dev

# Debug mode
DEBUG=true make apply ENV=dev
```

## ⚙️ Configuration

### Terraform Variables

Key variables in `terraform/terraform.tfvars`:

```hcl
# Basic configuration
project_name = "myapp"
environment = "dev"
aws_region = "us-west-2"

# Instance configuration
instance_type = "t3.micro"
instance_count = 2

# Database configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20
db_password = "SecurePassword123!"

# SSH access
public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
```

### Ansible Variables

Key variables in `ansible/inventory/group_vars/all.yml`:

```yaml
# Application settings
project_name: myapp
app_port: 3000
enable_ssl: false

# Security settings
enable_firewall: true
enable_fail2ban: true

# Monitoring
enable_monitoring: true
enable_cloudwatch: true
```

## 🔐 Security

### Secrets Management

- Use Ansible Vault for sensitive data
- Store AWS credentials securely
- Rotate database passwords regularly
- Enable SSL/TLS in production

### Network Security

- Private subnets for databases
- Security groups with minimal access
- VPC isolation
- Optional NAT gateway

### Access Control

- SSH key-based authentication
- IAM roles for EC2 instances
- Database user isolation
- S3 bucket policies

## 📊 Monitoring

### Health Checks

```bash
# Application health
curl http://your-load-balancer/health

# Database connectivity
make verify ENV=prod
```

### Metrics

- CloudWatch custom metrics
- Application performance monitoring
- System resource monitoring
- Log aggregation

## 🚨 Troubleshooting

### Common Issues

1. **Terraform Init Failed**

   ```bash
   cd terraform && terraform init -upgrade
   ```

2. **Ansible Connection Issues**

   ```bash
   # Test connectivity
   ansible all -i inventory/hosts.yml -m ping
   ```

3. **Database Connection Failed**

   ```bash
   # Check security groups and connectivity
   make verify ENV=dev
   ```

4. **SSL Certificate Issues**

   ```bash
   # Setup SSL certificates
   make ssl-setup ENV=dev
   ```

### Debugging

```bash
# Enable debug output
DEBUG=true make apply ENV=dev

# Terraform debug
cd terraform && TF_LOG=DEBUG terraform plan

# Ansible debug
cd ansible && ansible-playbook -vvv site.yml
```

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to staging
        run: make staging-apply
      - name: Verify deployment
        run: make verify ENV=staging
```

## 📚 Documentation

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment.md)
- [Security Guidelines](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)
- [API Documentation](docs/api.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com)
- [AWS Best Practices](https://aws.amazon.com/architecture/well-architected/)
- [Infrastructure as Code Guide](https://www.terraform.io/guides/core-workflow)

## 📊 Project Statistics

- **Total Files**: 35+ configuration files
- **Lines of Code**: 3000+ lines of Infrastructure as Code
- **Terraform Resources**: 25+ AWS resources provisioned
- **Ansible Tasks**: 100+ automation tasks
- **Security Features**: 15+ hardening measures
- **Monitoring Components**: 10+ health checks and metrics
- **Environment Support**: dev, staging, prod configurations
- **One-Command Deployment**: Complete infrastructure in minutes

---

## 🎯 What This Project Provides

✅ **Complete AWS Infrastructure**: VPC, EC2, RDS, S3, ALB, CloudWatch
✅ **Automated Configuration**: Nginx, Node.js, PostgreSQL, Docker, monitoring
✅ **Security Hardening**: Firewall, Fail2Ban, SSL/TLS, encrypted storage
✅ **Multi-Environment**: Separate dev, staging, production configurations
✅ **Comprehensive Monitoring**: Health checks, metrics, log aggregation
✅ **Backup & Recovery**: Automated backups with S3 integration
✅ **One-Command Deploy**: Complete infrastructure deployment with `make apply`
✅ **Verification**: Automated testing and validation of deployments
✅ **Documentation**: Comprehensive guides and troubleshooting

For questions or support, please create an issue in the repository.
