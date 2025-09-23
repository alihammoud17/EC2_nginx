# Makefile
.PHONY: help init plan apply destroy ssh status clean

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init

plan: ## Plan Terraform deployment
	terraform plan

apply: ## Apply Terraform configuration
	terraform apply

deploy: ## Full deployment (init + apply)
	terraform init
	terraform apply -auto-approve

destroy: ## Destroy all resources
	terraform destroy

ssh: ## SSH into the EC2 instance
	ssh -i ~/.ssh/id_rsa ec2-user@$$(terraform output -raw instance_public_ip)

status: ## Show deployment status
	@echo "=== Terraform Outputs ==="
	terraform output
	@echo ""
	@echo "=== Instance Status ==="
	aws ec2 describe-instances --instance-ids $$(terraform output -raw instance_id) --query 'Reservations[0].Instances[0].State.Name' --output text

test: ## Test Nginx service
	@echo "Testing Nginx service..."
	@curl -s -o /dev/null -w "%{http_code}" http://$$(terraform output -raw instance_public_ip) && echo " - Main page: OK" || echo " - Main page: FAILED"
	@curl -s -o /dev/null -w "%{http_code}" http://$$(terraform output -raw instance_public_ip)/health && echo " - Health check: OK" || echo " - Health check: FAILED"

logs: ## View Terraform logs
	terraform show

clean: ## Clean up local files
	rm -f inventory
	rm -rf .terraform/
	rm -f terraform.tfstate*
	rm -f *.tfplan

validate: ## Validate Terraform configuration
	terraform validate
	terraform fmt -check

format: ## Format Terraform files
	terraform fmt