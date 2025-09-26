# FILE: Makefile - Project automation
.PHONY: help init plan apply destroy verify clean ssh logs backup restore

# Default environment
ENV ?= dev

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Help target
help: ## Show this help message
	@echo 'Infrastructure Management Commands'
	@echo '=================================='
	@echo ''
	@echo 'Usage: make [target] [ENV=environment]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  ${GREEN}%-15s${NC} %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Environment Variables:'
	@echo '  ENV              Target environment (dev, staging, prod) [default: dev]'
	@echo '  SKIP_TERRAFORM   Skip Terraform execution (true/false) [default: false]'
	@echo '  SKIP_ANSIBLE     Skip Ansible execution (true/false) [default: false]'
	@echo '  DRY_RUN          Show what would be done (true/false) [default: false]'
	@echo '  DEBUG            Enable debug output (true/false) [default: false]'

init: ## Initialize Terraform and Ansible
	@echo "${GREEN}Initializing project for $(ENV) environment...${NC}"
	@cd terraform && terraform init -upgrade
	@cd ansible && ansible-galaxy install -r requirements.yml || true
	@echo "${GREEN}✅ Initialization complete${NC}"

validate: ## Validate Terraform and Ansible configurations
	@echo "${GREEN}Validating configurations...${NC}"
	@cd terraform && terraform fmt -check=true && terraform validate
	@cd ansible && ansible-playbook --syntax-check site.yml
	@echo "${GREEN}✅ Validation complete${NC}"

plan: ## Plan infrastructure changes
	@echo "${GREEN}Planning infrastructure changes for $(ENV)...${NC}"
	@./deployment-scripts/deploy.sh $(ENV) plan

apply: ## Deploy infrastructure and configure servers
	@echo "${GREEN}Deploying infrastructure for $(ENV)...${NC}"
	@./deployment-scripts/deploy.sh $(ENV) apply

destroy: ## Destroy infrastructure
	@echo "${RED}⚠️  WARNING: This will destroy all infrastructure for $(ENV)!${NC}"
	@./deployment-scripts/deploy.sh $(ENV) destroy

verify: ## Verify deployment
	@echo "${GREEN}Verifying deployment for $(ENV)...${NC}"
	@cd ansible && ansible-playbook -i inventory/dynamic_hosts.yml playbooks/verify.yml

clean: ## Clean temporary files and old backups
	@echo "${GREEN}Cleaning temporary files...${NC}"
	@find terraform -name "tfplan-*" -type f -mtime +7 -delete || true
	@find terraform -name "*.tfstate.backup" -type f -mtime +30 -delete || true
	@find ansible -name "*.retry" -type f -delete || true
	@find backups -name "*" -type f -mtime +90 -delete 2>/dev/null || true
	@rm -f outputs.json.old terraform/*.log ansible/*.log
	@echo "${GREEN}✅ Cleanup complete${NC}"

ssh: ## SSH into the first web server
	@echo "${GREEN}Connecting to first web server...${NC}"
	@cd terraform && terraform output -raw instance_public_ips | jq -r '.[0]' | xargs -I {} ssh -i ~/.ssh/id_rsa ubuntu@{}

ssh-all: ## Show SSH commands for all servers
	@echo "${GREEN}SSH commands for all servers:${NC}"
	@cd terraform && terraform output ssh_commands | jq -r '.[]?'

logs: ## Show application logs from all servers
	@echo "${GREEN}Showing application logs...${NC}"
	@cd ansible && ansible webservers -i inventory/dynamic_hosts.yml -m shell -a "tail -50 /var/log/myapp/*.log"

health: ## Check health of all services
	@echo "${GREEN}Checking service health...${NC}"
	@cd ansible && ansible webservers -i inventory/dynamic_hosts.yml -m uri -a "url=http://localhost/health"

backup: ## Create backup of current state
	@echo "${GREEN}Creating backup...${NC}"
	@cd ansible && ansible-playbook -i inventory/dynamic_hosts.yml playbooks/backup.yml

security-scan: ## Run security scanning
	@echo "${GREEN}Running security scan...${NC}"
	@cd ansible && ansible-playbook -i inventory/dynamic_hosts.yml playbooks/security.yml

ssl-setup: ## Setup SSL certificates
	@echo "${GREEN}Setting up SSL certificates...${NC}"
	@cd ansible && ansible-playbook -i inventory/dynamic_hosts.yml playbooks/ssl.yml

# Environment-specific targets
dev-apply: ENV=dev
dev-apply: apply ## Deploy to development environment

staging-apply: ENV=staging  
staging-apply: apply ## Deploy to staging environment

prod-apply: ENV=prod
prod-apply: apply ## Deploy to production environment