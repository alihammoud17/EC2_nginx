#!/bin/bash
# deployment-scripts/deploy.sh - Main deployment automation script

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Default values
ENVIRONMENT=${1:-dev}
ACTION=${2:-apply}
SKIP_TERRAFORM=${SKIP_TERRAFORM:-false}
SKIP_ANSIBLE=${SKIP_ANSIBLE:-false}
DRY_RUN=${DRY_RUN:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG: $1${NC}"
    fi
}

# Banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    INFRASTRUCTURE DEPLOYMENT                  ║"
    echo "║                                                               ║"
    echo "║  Environment: ${ENVIRONMENT^^}                                ║"
    echo "║  Action:      ${ACTION^^}                                     ║"
    echo "║  Date:        $(date +'%Y-%m-%d %H:%M:%S')                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Prerequisites check
check_prerequisites() {
    log "Checking prerequisites..."
    
    local required_tools=("terraform" "ansible" "aws" "jq")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        else
            debug "$tool is installed: $(command -v $tool)"
        fi
    done
    
    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error "AWS credentials not configured properly"
    fi
    
    # Check if required files exist
    local required_files=(
        "$TERRAFORM_DIR/main.tf"
        "$TERRAFORM_DIR/variables.tf"
        "$TERRAFORM_DIR/outputs.tf"
        "$ANSIBLE_DIR/site.yml"
        "$ANSIBLE_DIR/inventory/hosts.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Required file not found: $file"
        fi
    done
    
    log "Prerequisites check completed ✓"
}

# Backup existing state
backup_state() {
    log "Creating backup of current state..."
    
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup Terraform state
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        cp "$TERRAFORM_DIR/terraform.tfstate" "$backup_dir/"
        debug "Terraform state backed up"
    fi
    
    # Backup Ansible inventory
    if [[ -f "$ANSIBLE_DIR/inventory/dynamic_hosts.yml" ]]; then
        cp "$ANSIBLE_DIR/inventory/dynamic_hosts.yml" "$backup_dir/"
        debug "Ansible inventory backed up"
    fi
    
    # Backup outputs
    if [[ -f "$PROJECT_ROOT/outputs.json" ]]; then
        cp "$PROJECT_ROOT/outputs.json" "$backup_dir/"
        debug "Outputs backed up"
    fi
    
    log "Backup created at: $backup_dir"
}

# Terraform operations
deploy_infrastructure() {
    if [[ "$SKIP_TERRAFORM" == "true" ]]; then
        log "Skipping Terraform deployment (SKIP_TERRAFORM=true)"
        return 0
    fi
    
    log "Starting Terraform deployment..."
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    if [[ "$DRY_RUN" == "false" ]]; then
        terraform init -upgrade || error "Terraform init failed"
    else
        log "DRY RUN: Would run terraform init -upgrade"
    fi
    
    # Validate configuration
    log "Validating Terraform configuration..."
    if [[ "$DRY_RUN" == "false" ]]; then
        terraform validate || error "Terraform validation failed"
    else
        log "DRY RUN: Would run terraform validate"
    fi
    
    # Choose variables file
    local tfvars_file
    if [[ -f "environments/${ENVIRONMENT}.tfvars" ]]; then
        tfvars_file="environments/${ENVIRONMENT}.tfvars"
    elif [[ -f "terraform.tfvars" ]]; then
        tfvars_file="terraform.tfvars"
    else
        error "No variables file found for environment: $ENVIRONMENT"
    fi
    
    # Plan deployment
    log "Creating Terraform execution plan..."
    local plan_file="tfplan-${ENVIRONMENT}-$(date +%Y%m%d_%H%M%S)"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if ! terraform plan -var-file="$tfvars_file" -out="$plan_file" -detailed-exitcode; then
            local exit_code=$?
            if [[ $exit_code -eq 1 ]]; then
                error "Terraform plan failed"
            elif [[ $exit_code -eq 2 ]]; then
                log "Terraform plan shows changes to be made"
            fi
        else
            log "No changes detected in Terraform plan"
        fi
    else
        log "DRY RUN: Would run terraform plan -var-file=$tfvars_file -out=$plan_file"
    fi
    
    # Execute based on action
    case $ACTION in
        "plan")
            log "Plan completed. Review the changes above."
            ;;
        "apply")
            if [[ "$DRY_RUN" == "false" ]]; then
                log "Applying Terraform changes..."
                terraform apply "$plan_file" || error "Terraform apply failed"
                
                # Generate outputs
                log "Generating Terraform outputs..."
                terraform output -json > "$PROJECT_ROOT/outputs.json" || error "Failed to generate outputs"
                
                # Display key outputs
                log "Key infrastructure outputs:"
                echo "  Load Balancer DNS: $(terraform output -raw load_balancer_dns 2>/dev/null || echo 'N/A')"
                echo "  Instance IPs: $(terraform output -json instance_public_ips 2>/dev/null | jq -r '.[]?' | tr '\n' ' ' || echo 'N/A')"
                echo "  Database Endpoint: $(terraform output -raw rds_endpoint 2>/dev/null || echo 'N/A')"
                echo "  S3 Bucket: $(terraform output -raw s3_bucket_name 2>/dev/null || echo 'N/A')"
            else
                log "DRY RUN: Would apply Terraform changes"
            fi
            ;;
        "destroy")
            warn "DESTRUCTIVE ACTION: This will destroy all infrastructure!"
            if [[ "$DRY_RUN" == "false" ]]; then
                read -p "Are you sure you want to destroy the infrastructure for $ENVIRONMENT? (yes/no): " -r
                if [[ $REPLY == "yes" ]]; then
                    terraform destroy -var-file="$tfvars_file" -auto-approve || error "Terraform destroy failed"
                else
                    log "Destroy cancelled by user"
                fi
            else
                log "DRY RUN: Would destroy infrastructure"
            fi
            ;;
        *)
            error "Unknown action: $ACTION"
            ;;
    esac
    
    # Clean up plan files (keep last 5)
    find . -name "tfplan-*" -type f | sort | head -n -5 | xargs -r rm
    
    cd "$PROJECT_ROOT"
    log "Terraform deployment completed ✓"
}

# Generate dynamic Ansible inventory
generate_inventory() {
    log "Generating dynamic Ansible inventory..."
    
    if [[ ! -f "$PROJECT_ROOT/outputs.json" ]]; then
        error "Terraform outputs not found. Run Terraform first."
    fi
    
    if [[ "$DRY_RUN" == "false" ]]; then
        python3 "$SCRIPT_DIR/generate_inventory.py" "$PROJECT_ROOT/outputs.json" || error "Failed to generate inventory"
    else
        log "DRY RUN: Would generate dynamic inventory"
    fi
    
    log "Dynamic inventory generated ✓"
}

# Configure servers with Ansible
configure_servers() {
    if [[ "$SKIP_ANSIBLE" == "true" ]]; then
        log "Skipping Ansible configuration (SKIP_ANSIBLE=true)"
        return 0
    fi
    
    if [[ "$ACTION" == "destroy" ]]; then
        log "Skipping Ansible configuration for destroy action"
        return 0
    fi
    
    log "Starting Ansible configuration..."
    cd "$ANSIBLE_DIR"
    
    # Check if inventory exists
    local inventory_file="inventory/dynamic_hosts.yml"
    if [[ ! -f "$inventory_file" ]]; then
        warn "Dynamic inventory not found, using static inventory"
        inventory_file="inventory/hosts.yml"
    fi
    
    # Check Ansible configuration
    log "Validating Ansible configuration..."
    if [[ "$DRY_RUN" == "false" ]]; then
        ansible-playbook --syntax-check -i "$inventory_file" site.yml || error "Ansible syntax check failed"
    else
        log "DRY RUN: Would validate Ansible syntax"
    fi
    
    # Test connectivity
    log "Testing Ansible connectivity..."
    if [[ "$DRY_RUN" == "false" ]]; then
        if ! ansible all -i "$inventory_file" -m ping --timeout=30; then
            error "Cannot connect to target hosts"
        fi
    else
        log "DRY RUN: Would test connectivity to hosts"
    fi
    
    # Run playbook
    local ansible_args=(
        "-i" "$inventory_file"
        "--extra-vars" "environment=$ENVIRONMENT"
        "--timeout=300"
    )
    
    # Add vault password if exists
    if [[ -f ".vault_pass" ]]; then
        ansible_args+=("--vault-password-file" ".vault_pass")
    fi
    
    # Add verbosity if debug mode
    if [[ "${DEBUG:-false}" == "true" ]]; then
        ansible_args+=("-vvv")
    fi
    
    log "Running Ansible playbook..."
    if [[ "$DRY_RUN" == "false" ]]; then
        ansible-playbook "${ansible_args[@]}" site.yml || error "Ansible playbook execution failed"
    else
        log "DRY RUN: Would run ansible-playbook ${ansible_args[*]} site.yml"
    fi
    
    cd "$PROJECT_ROOT"
    log "Ansible configuration completed ✓"
}

# Verify deployment
verify_deployment() {
    if [[ "$ACTION" != "apply" ]]; then
        log "Skipping verification for action: $ACTION"
        return 0
    fi
    
    log "Starting deployment verification..."
    cd "$ANSIBLE_DIR"
    
    local inventory_file="inventory/dynamic_hosts.yml"
    if [[ ! -f "$inventory_file" ]]; then
        inventory_file="inventory/hosts.yml"
    fi
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Run verification playbook
        if [[ -f "playbooks/verify.yml" ]]; then
            ansible-playbook -i "$inventory_file" playbooks/verify.yml || warn "Some verification checks failed"
        else
            warn "Verification playbook not found, running basic checks..."
            
            # Basic service checks
            ansible webservers -i "$inventory_file" -m service -a "name=nginx state=started" || warn "Nginx service check failed"
            ansible webservers -i "$inventory_file" -m uri -a "url=http://localhost/health timeout=10" || warn "Health check failed"
        fi
    else
        log "DRY RUN: Would run deployment verification"
    fi
    
    cd "$PROJECT_ROOT"
    log "Deployment verification completed ✓"
}

# Display deployment summary
show_summary() {
    log "Deployment Summary"
    echo "===================="
    echo "Environment: $ENVIRONMENT"
    echo "Action: $ACTION"
    echo "Timestamp: $(date)"
    echo "Duration: $((SECONDS / 60)) minutes $((SECONDS % 60)) seconds"
    
    if [[ -f "$PROJECT_ROOT/outputs.json" && "$ACTION" == "apply" ]]; then
        echo ""
        echo "Infrastructure Endpoints:"
        echo "------------------------"
        
        # Extract key information from outputs
        local lb_dns
        local instance_ips
        local db_endpoint
        local s3_bucket
        
        lb_dns=$(jq -r '.load_balancer_dns.value // "N/A"' "$PROJECT_ROOT/outputs.json" 2>/dev/null)
        instance_ips=$(jq -r '.instance_public_ips.value[]? // "N/A"' "$PROJECT_ROOT/outputs.json" 2>/dev/null | tr '\n' ' ')
        db_endpoint=$(jq -r '.rds_endpoint.value // "N/A"' "$PROJECT_ROOT/outputs.json" 2>/dev/null)
        s3_bucket=$(jq -r '.s3_bucket_name.value // "N/A"' "$PROJECT_ROOT/outputs.json" 2>/dev/null)
        
        echo "🌐 Load Balancer: http://$lb_dns"
        echo "🖥️  Instance IPs: $instance_ips"
        echo "🗄️  Database: $db_endpoint"
        echo "☁️  S3 Bucket: $s3_bucket"
        echo ""
        echo "🔍 Health Check: http://$lb_dns/health"
        
        if [[ "$lb_dns" != "N/A" ]]; then
            echo ""
            echo "Quick test command:"
            echo "curl -I http://$lb_dns/health"
        fi
    fi
    
    echo ""
    log "Deployment completed successfully! 🎉"
}

# Error handling
cleanup_on_error() {
    error "Deployment failed! Check the logs for details."
    
    # Attempt to save state
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        cp "$TERRAFORM_DIR/terraform.tfstate" "$PROJECT_ROOT/terraform.tfstate.error.$(date +%s)"
        warn "Terraform state saved for debugging"
    fi
    
    exit 1
}

# Signal handlers
trap cleanup_on_error ERR
trap 'warn "Deployment interrupted by user"; exit 130' INT TERM

# Usage information
show_usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [ACTION]

Arguments:
  ENVIRONMENT    Target environment (dev, staging, prod) [default: dev]
  ACTION         Action to perform (plan, apply, destroy) [default: apply]

Environment Variables:
  SKIP_TERRAFORM    Skip Terraform execution (true/false) [default: false]
  SKIP_ANSIBLE      Skip Ansible execution (true/false) [default: false]
  DRY_RUN          Show what would be done without executing (true/false) [default: false]
  DEBUG            Enable debug output (true/false) [default: false]

Examples:
  $0 dev plan                    # Plan changes for dev environment
  $0 staging apply               # Deploy to staging
  $0 prod apply                  # Deploy to production
  DRY_RUN=true $0 dev apply      # Show what would be deployed
  SKIP_ANSIBLE=true $0 dev apply # Only run Terraform
  DEBUG=true $0 dev apply        # Enable debug output

Files required:
  - terraform/main.tf
  - terraform/variables.tf
  - terraform/outputs.tf
  - terraform/environments/\${ENVIRONMENT}.tfvars (or terraform/terraform.tfvars)
  - ansible/site.yml
  - ansible/inventory/hosts.yml

EOF
}

# Main execution function
main() {
    # Parse arguments
    if [[ "$#" -eq 0 ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
    fi
    
    # Validate action
    if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
        error "Invalid action: $ACTION. Must be plan, apply, or destroy."
    fi
    
    # Start deployment
    show_banner
    check_prerequisites
    
    if [[ "$ACTION" != "plan" ]]; then
        backup_state
    fi
    
    deploy_infrastructure
    
    if [[ "$ACTION" == "apply" ]]; then
        generate_inventory
        configure_servers
        verify_deployment
    fi
    
    show_summary
}

# Execute main function with all arguments
main "$@"