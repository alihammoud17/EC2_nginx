#!/bin/bash
# deploy.sh - Complete deployment script

set -e

echo "🚀 Starting deployment of EC2 instance with Nginx..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if Ansible is installed
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed. Please install Ansible first."
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "All prerequisites met ✅"
}

# Generate SSH key if it doesn't exist
generate_ssh_key() {
    if [ ! -f ~/.ssh/id_rsa ]; then
        print_status "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        print_status "SSH key pair generated ✅"
    else
        print_status "SSH key pair already exists ✅"
    fi
}

# Create terraform.tfvars if it doesn't exist
create_tfvars() {
    if [ ! -f terraform.tfvars ]; then
        print_status "Creating terraform.tfvars file..."
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please review and update terraform.tfvars with your preferred settings"
    fi
}

# Deploy infrastructure with Terraform
deploy_terraform() {
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Planning Terraform deployment..."
    terraform plan
    
    print_status "Applying Terraform configuration..."
    terraform apply -auto-approve
    
    print_status "Infrastructure deployed successfully ✅"
}

# Display deployment information
show_deployment_info() {
    print_status "Deployment completed successfully! 🎉"
    echo ""
    echo "📋 Deployment Information:"
    echo "=========================="
    
    # Get outputs from Terraform
    INSTANCE_IP=$(terraform output -raw instance_public_ip)
    NGINX_URL=$(terraform output -raw nginx_url)
    
    echo "🖥️  Instance IP: $INSTANCE_IP"
    echo "🌐 Nginx URL: $NGINX_URL"
    echo "🔗 Health Check: $NGINX_URL/health"
    echo ""
    echo "🔧 SSH Access:"
    echo "ssh -i ~/.ssh/id_rsa ec2-user@$INSTANCE_IP"
    echo ""
    echo "📝 To destroy the infrastructure:"
    echo "terraform destroy"
}

# Cleanup function
cleanup() {
    print_warning "Deployment interrupted. You may need to run 'terraform destroy' to clean up resources."
}

# Set trap for cleanup
trap cleanup INT TERM

# Main deployment flow
main() {
    check_prerequisites
    generate_ssh_key
    create_tfvars
    deploy_terraform
    show_deployment_info
}

# Run main function
main

print_status "Deployment script completed! ✨"