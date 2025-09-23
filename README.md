# EC2 + Nginx Deployment with Terraform and Ansible

Automated deployment of an EC2 instance on AWS with Nginx web server using Infrastructure as Code (IaC) principles.

## 🎯 Overview

This project combines **Terraform** for infrastructure provisioning and **Ansible** for configuration management to create a production-ready web server deployment on AWS.

### What Gets Deployed

- **AWS Infrastructure**: VPC, Security Groups, EC2 instance with public IP
- **Web Server**: Nginx with custom welcome page and health check endpoint
- **Security**: Firewall rules, SSH key management, and secure access

## 📁 Project Structure

```
terraform-ansible-nginx/
├── 🔧 Scripts
│   ├── setup.sh                     # Environment setup
│   ├── deploy.sh                    # Main deployment
│   └── cleanup.sh                   # Resource cleanup
│
├── 🏗️ Infrastructure (Terraform)
│   ├── main.tf                      # AWS resources
│   ├── variables.tf                 # Input variables
│   ├── outputs.tf                   # Output values
│   ├── versions.tf                  # Provider versions
│   └── terraform.tfvars.example     # Configuration template
│
├── ⚙️ Configuration (Ansible)
│   ├── ansible.cfg                  # Ansible settings
│   ├── nginx-playbook.yml           # Server configuration
│   └── inventory.tpl                # Inventory template
│
└── 📋 Documentation
    ├── README.md                    # This file
    ├── Makefile                     # Command shortcuts
    └── .gitignore                   # Git exclusions
```

## 🚀 Quick Start

### Prerequisites

Ensure you have these tools installed:

- **Terraform** (≥ 1.0)
- **Ansible** (≥ 2.9) 
- **AWS CLI** with configured credentials
- **SSH key pair** (will be generated if missing)

### One-Command Deployment

```bash
# Make scripts executable and deploy everything
chmod +x ./scripts/*.sh && ./scripts/deploy.sh
```

The deployment script automatically:
- ✅ Verifies prerequisites
- 🔑 Generates SSH keys if needed
- 📝 Creates configuration files
- 🏗️ Provisions AWS infrastructure
- ⚙️ Configures Nginx web server
- 📊 Displays access information

## 🛠️ Manual Deployment

If you prefer step-by-step control:

### 1. Environment Setup
```bash
# Install dependencies (one-time setup)
./setup.sh

# Generate SSH keys (if needed)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

### 2. Configuration
```bash
# Create your configuration file
cp terraform.tfvars.example terraform.tfvars

# Edit with your preferred settings
nano terraform.tfvars
```

### 3. Infrastructure Deployment
```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply
```

*Note: Ansible configuration runs automatically via Terraform's local provisioner*

## ⚙️ Configuration Options

### Key Variables (terraform.tfvars)

```hcl
# AWS Configuration
aws_region     = "us-west-2"        # AWS region
instance_type  = "t3.micro"         # EC2 instance size
key_name       = "my-keypair"       # SSH key name

# Networking
allowed_cidr   = ["0.0.0.0/0"]     # SSH access (restrict in production)
```

### Customization Examples

**Change Instance Size:**
```hcl
instance_type = "t3.small"  # Upgrade from t3.micro
```

**Restrict SSH Access:**
```hcl
allowed_cidr = ["203.0.113.0/24"]  # Your office IP range
```

**Different AWS Region:**
```hcl
aws_region = "eu-west-1"
```

## 🌐 Accessing Your Deployment

After successful deployment, you'll see:

```
📋 Deployment Complete!
========================
🖥️  Instance IP: 54.123.45.67
🌐 Website: http://54.123.45.67
🏥 Health Check: http://54.123.45.67/health

🔐 SSH Command:
ssh -i ~/.ssh/id_rsa ec2-user@54.123.45.67
```

### Available Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Custom welcome page |
| `/health` | Health check (returns "healthy") |

## 🎮 Makefile Commands

For convenience, use these shortcuts:

```bash
make deploy     # Full deployment
make plan       # Show planned changes
make destroy    # Remove all resources
make ssh        # Connect to server
make test       # Test web server
make logs       # View deployment logs
```

## 🔧 Troubleshooting

### Common Issues

**SSH Connection Refused**
- Wait 2-3 minutes for instance boot completion
- Verify security group allows SSH (port 22)

**Ansible Fails to Connect**
- Check private key permissions: `chmod 600 ~/.ssh/id_rsa`
- Confirm instance is running: `aws ec2 describe-instances`

**Terraform Apply Errors**
- Verify AWS credentials: `aws sts get-caller-identity`
- Ensure adequate AWS permissions (EC2, VPC creation)

### Debug Commands

```bash
# Check infrastructure state
terraform show

# Test Ansible connectivity  
ansible -i inventory webservers -m ping

# View server logs
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -raw instance_public_ip)
sudo journalctl -u nginx -f
```

## 🔒 Security Considerations

### Current Security Settings
- SSH access allowed from anywhere (0.0.0.0/0)
- HTTP/HTTPS ports open to internet
- Standard AWS security group rules

### Production Hardening
- **Restrict SSH**: Limit to your IP range in `terraform.tfvars`
- **Use Session Manager**: Consider AWS Systems Manager for access
- **Enable CloudTrail**: For audit logging
- **SSL/TLS**: Add certificate management for HTTPS
- **Backup Strategy**: Implement automated backups

### Security Best Practices
```hcl
# Example: Restrict SSH to your IP
allowed_cidr = ["203.0.113.100/32"]  # Your specific IP
```

## 🧹 Cleanup

Remove all AWS resources:

```bash
# Using script (recommended)
./cleanup.sh

# Or directly with Terraform
terraform destroy

# Or with Makefile
make destroy
```

**What Gets Removed:**
- EC2 instance and associated storage
- VPC, subnets, and networking components  
- Security groups and rules
- SSH key pairs

## 🛡️ What's Protected

The `.gitignore` prevents committing:
- 🔑 SSH private keys
- 📊 Terraform state files (contain sensitive data)
- ⚙️ Your `terraform.tfvars` configuration
- 📋 Generated inventory files
- 🔐 Any AWS credentials

## 📚 Additional Resources

- 📖 [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- 📖 [Ansible Documentation](https://docs.ansible.com/)
- 📖 [Nginx Configuration Guide](https://nginx.org/en/docs/)
- 📖 [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).