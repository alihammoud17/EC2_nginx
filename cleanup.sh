#!/bin/bash
# cleanup.sh - Script to clean up all resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "🧹 Starting cleanup process..."

# Confirm destruction
read -p "⚠️  This will destroy all AWS resources. Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

# Destroy Terraform resources
if [ -f "terraform.tfstate" ] || [ -f "terraform.tfstate.backup" ]; then
    print_status "Destroying Terraform resources..."
    terraform destroy -auto-approve
    print_status "AWS resources destroyed ✅"
else
    print_warning "No Terraform state found. Skipping resource destruction."
fi

# Clean up local files
print_status "Cleaning up local files..."

# Remove generated files
rm -f inventory
rm -f terraform.tfstate*
rm -f *.tfplan
rm -f crash.log
rm -rf .terraform/

# Clean up logs
rm -f *.log
rm -rf logs/

print_status "Local files cleaned up ✅"

# Optionally remove SSH keys (ask user)
if [ -f ~/.ssh/id_rsa ]; then
    read -p "🔑 Remove SSH keys (~/.ssh/id_rsa)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
        print_status "SSH keys removed ✅"
    else
        print_status "SSH keys preserved"
    fi
fi

print_status "🎉 Cleanup completed successfully!"
echo ""
echo "📋 What was cleaned up:"
echo "======================"
echo "✅ AWS EC2 instance"
echo "✅ AWS VPC and networking"
echo "✅ AWS Security groups"
echo "✅ AWS Key pairs"
echo "✅ Local Terraform state"
echo "✅ Generated inventory files"
echo ""
echo "You can now run ./deploy.sh again to create a fresh deployment."