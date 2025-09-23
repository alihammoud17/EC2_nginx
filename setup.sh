#!/bin/bash
# setup.sh - Initial environment setup script

set -e

echo "🔧 Setting up development environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" ]]; then
    OS="windows"
fi

print_header "Detected OS: $OS"

# Install Terraform
install_terraform() {
    if command -v terraform &> /dev/null; then
        print_status "Terraform already installed ✅"
        terraform version
        return
    fi

    print_status "Installing Terraform..."
    
    case $OS in
        "linux")
            wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install terraform
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install terraform
            else
                print_error "Homebrew not found. Please install Homebrew first: https://brew.sh/"
                exit 1
            fi
            ;;
        *)
            print_warning "Please install Terraform manually: https://www.terraform.io/downloads"
            ;;
    esac
}

# Install Ansible
install_ansible() {
    if command -v ansible &> /dev/null; then
        print_status "Ansible already installed ✅"
        ansible --version | head -1
        return
    fi

    print_status "Installing Ansible..."
    
    case $OS in
        "linux")
            sudo apt update && sudo apt install -y ansible
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install ansible
            else
                pip3 install ansible
            fi
            ;;
        *)
            print_warning "Please install Ansible manually: https://docs.ansible.com/ansible/latest/installation_guide/"
            ;;
    esac
}

# Install AWS CLI
install_aws_cli() {
    if command -v aws &> /dev/null; then
        print_status "AWS CLI already installed ✅"
        aws --version
        return
    fi

    print_status "Installing AWS CLI..."
    
    case $OS in
        "linux")
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf aws awscliv2.zip
            ;;
        "macos")
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            sudo installer -pkg AWSCLIV2.pkg -target /
            rm AWSCLIV2.pkg
            ;;
        *)
            print_warning "Please install AWS CLI manually: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
            ;;
    esac
}

# Setup Python dependencies
setup_python() {
    print_status "Installing Python dependencies..."
    
    if command -v pip3 &> /dev/null; then
        pip3 install -r requirements.txt
    elif command -v pip &> /dev/null; then
        pip install -r requirements.txt
    else
        print_warning "pip not found. Please install Python dependencies manually."
    fi
}

# Make scripts executable
setup_scripts() {
    print_status "Making scripts executable..."
    chmod +x deploy.sh
    chmod +x cleanup.sh
    chmod +x setup.sh
}

# Create terraform.tfvars if it doesn't exist
setup_config() {
    if [ ! -f terraform.tfvars ]; then
        print_status "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please edit terraform.tfvars with your preferred settings"
    fi
}

# Main setup function
main() {
    print_header "Starting environment setup..."
    
    install_terraform
    install_ansible
    install_aws_cli
    setup_python
    setup_scripts
    setup_config
    
    print_status "🎉 Setup completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "==============="
    echo "1. Configure AWS credentials: aws configure"
    echo "2. Edit terraform.tfvars with your settings"
    echo "3. Run deployment: ./deploy.sh"
    echo ""
    echo "📚 Available commands:"
    echo "- ./deploy.sh    : Deploy infrastructure"
    echo "- ./cleanup.sh   : Clean up resources"
    echo "- make help      : Show available make targets"
}

# Run main function
main