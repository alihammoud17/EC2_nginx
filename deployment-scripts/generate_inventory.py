#!/usr/bin/env python3
"""
Dynamic Ansible inventory generator from Terraform outputs
"""

import json
import sys
import yaml
from pathlib import Path
from typing import Dict, Any, List
import argparse
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def load_terraform_outputs(outputs_file: str) -> Dict[str, Any]:
    """Load Terraform outputs from JSON file."""
    try:
        with open(outputs_file, 'r') as f:
            outputs = json.load(f)
        logger.info(f"Loaded Terraform outputs from {outputs_file}")
        return outputs
    except FileNotFoundError:
        logger.error(f"Terraform outputs file not found: {outputs_file}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in outputs file: {e}")
        sys.exit(1)

def generate_inventory(terraform_outputs: Dict[str, Any]) -> Dict[str, Any]:
    """Generate Ansible inventory from Terraform outputs."""
    
    logger.info("Generating dynamic inventory...")
    
    # Extract values with safe defaults
    def get_output_value(key: str, default=None):
        return terraform_outputs.get(key, {}).get('value', default)
    
    # Get infrastructure details
    public_ips = get_output_value('instance_public_ips', [])
    private_ips = get_output_value('instance_private_ips', [])
    instance_ids = get_output_value('instance_ids', [])
    rds_endpoint = get_output_value('rds_endpoint', '')
    s3_bucket = get_output_value('s3_bucket_name', '')
    lb_dns = get_output_value('load_balancer_dns', '')
    vpc_id = get_output_value('vpc_id', '')
    db_name = get_output_value('rds_database_name', 'appdb')
    db_username = get_output_value('rds_username', 'dbadmin')
    
    # Environment info
    env_info = get_output_value('environment_info', {})
    project_name = env_info.get('project_name', 'myapp')
    environment = env_info.get('environment', 'dev')
    region = env_info.get('region', 'us-west-2')
    
    if not public_ips:
        logger.warning("No public IPs found in Terraform outputs")
    
    # Build inventory structure
    inventory = {
        'all': {
            'vars': {
                'ansible_user': 'ubuntu',
                'ansible_ssh_private_key_file': '~/.ssh/id_rsa',
                'ansible_python_interpreter': '/usr/bin/python3',
                'host_key_checking': False,
                'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
                
                # Project configuration
                'project_name': project_name,
                'environment': environment,
                'aws_region': region,
                
                # Infrastructure details
                'vpc_id': vpc_id,
                'load_balancer_dns': lb_dns,
                
                # Database configuration
                'database_host': rds_endpoint,
                'database_port': 5432,
                'database_name': db_name,
                'database_username': db_username,
                'database_password': '{{ vault_db_password }}',  # From vault
                
                # S3 configuration
                's3_bucket_name': s3_bucket,
                
                # Application configuration
                'app_port': 3000,
                'app_user': 'ubuntu',
                'app_directory': f'/opt/{project_name}',
                'log_directory': f'/var/log/{project_name}',
                
                # Feature flags
                'enable_ssl': False,
                'enable_monitoring': True,
                'enable_cloudwatch': True,
                'enable_firewall': True,
                'enable_fail2ban': True,
                
                # Performance settings
                'max_upload_size': '100m',
                'nginx_worker_processes': 'auto',
                'nginx_worker_connections': 1024,
            },
            'children': {
                'webservers': {
                    'hosts': {},
                    'vars': {
                        'server_type': 'web',
                        'nginx_client_max_body_size': '100m',
                        'node_env': 'production',
                        'log_level': 'info',
                    }
                },
                'databases': {
                    'hosts': {
                        'postgres-main': {
                            'ansible_host': rds_endpoint.split(':')[0] if rds_endpoint else 'localhost',
                            'db_engine': 'postgres',
                            'db_port': 5432,
                            'is_managed': True,
                        }
                    },
                    'vars': {
                        'database_type': 'postgresql',
                        'backup_enabled': True,
                    }
                },
                'loadbalancers': {
                    'hosts': {
                        'alb-main': {
                            'lb_dns_name': lb_dns,
                            'lb_type': 'application',
                            'is_managed': True,
                        }
                    },
                    'vars': {
                        'lb_health_check_path': '/health',
                        'lb_health_check_interval': 30,
                    }
                }
            }
        }
    }
    
    # Add web servers to inventory
    for i, (public_ip, private_ip, instance_id) in enumerate(zip(
        public_ips, 
        private_ips + [''] * len(public_ips),  # Pad with empty strings
        instance_ids + [''] * len(public_ips)  # Pad with empty strings
    )):
        host_name = f'web-{i+1}'
        host_config = {
            'ansible_host': public_ip,
            'private_ip': private_ip,
            'instance_id': instance_id,
            'server_role': 'primary' if i == 0 else 'secondary',
            'server_index': i + 1,
        }
        
        # Primary server gets additional responsibilities
        if i == 0:
            host_config.update({
                'enable_cron_jobs': True,
                'enable_database_backups': True,
                'is_primary': True,
            })
        else:
            host_config.update({
                'enable_cron_jobs': False,
                'enable_database_backups': False,
                'is_primary': False,
            })
        
        inventory['all']['children']['webservers']['hosts'][host_name] = host_config
    
    logger.info(f"Generated inventory with {len(public_ips)} web servers")
    return inventory

def save_inventory(inventory: Dict[str, Any], output_file: str) -> None:
    """Save inventory to YAML file."""
    try:
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w') as f:
            yaml.dump(inventory, f, default_flow_style=False, indent=2)
        
        logger.info(f"Inventory saved to {output_file}")
    except Exception as e:
        logger.error(f"Failed to save inventory: {e}")
        sys.exit(1)

def validate_inventory(inventory: Dict[str, Any]) -> bool:
    """Validate the generated inventory structure."""
    required_keys = ['all']
    
    for key in required_keys:
        if key not in inventory:
            logger.error(f"Missing required key in inventory: {key}")
            return False
    
    # Check if we have any hosts
    webservers = inventory.get('all', {}).get('children', {}).get('webservers', {}).get('hosts', {})
    if not webservers:
        logger.warning("No webserver hosts found in inventory")
        return False
    
    # Validate host configuration
    for host_name, host_config in webservers.items():
        if 'ansible_host' not in host_config:
            logger.error(f"Host {host_name} missing ansible_host")
            return False
    
    logger.info("Inventory validation passed")
    return True

def main():
    """Main function."""
    parser = argparse.ArgumentParser(description='Generate Ansible inventory from Terraform outputs')
    parser.add_argument('terraform_outputs', help='Path to Terraform outputs JSON file')
    parser.add_argument('--output', '-o', default='ansible/inventory/dynamic_hosts.yml', 
                       help='Output inventory file path')
    parser.add_argument('--validate', '-v', action='store_true', 
                       help='Validate inventory after generation')
    parser.add_argument('--format', choices=['yaml', 'json'], default='yaml',
                       help='Output format')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')
    
    args = parser.parse_args()
    
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Load Terraform outputs
    terraform_outputs = load_terraform_outputs(args.terraform_outputs)
    
    # Generate inventory
    inventory = generate_inventory(terraform_outputs)
    
    # Validate if requested
    if args.validate and not validate_inventory(inventory):
        logger.error("Inventory validation failed")
        sys.exit(1)
    
    # Save inventory
    if args.format == 'json':
        output_file = args.output.replace('.yml', '.json').replace('.yaml', '.json')
        with open(output_file, 'w') as f:
            json.dump(inventory, f, indent=2)
        logger.info(f"Inventory saved as JSON to {output_file}")
    else:
        save_inventory(inventory, args.output)
    
    # Print summary
    webservers_count = len(inventory.get('all', {}).get('children', {}).get('webservers', {}).get('hosts', {}))
    db_host = inventory.get('all', {}).get('vars', {}).get('database_host', 'N/A')
    s3_bucket = inventory.get('all', {}).get('vars', {}).get('s3_bucket_name', 'N/A')
    
    print(f"\n✅ Dynamic inventory generated successfully!")
    print(f"📊 Summary:")
    print(f"  - Web servers: {webservers_count}")
    print(f"  - Database host: {db_host}")
    print(f"  - S3 bucket: {s3_bucket}")
    print(f"  - Output file: {args.output}")

if __name__ == '__main__':
    main()