# outputs.tf
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.nginx.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.nginx.public_dns
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.nginx.id
}

output "nginx_url" {
  description = "URL to access Nginx"
  value       = "http://${aws_instance.nginx.public_ip}"
}