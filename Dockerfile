# Dockerfile.ansible
# Optional: For containerized Ansible execution

FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    openssh-client \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Set working directory
WORKDIR /workspace

# Default command
CMD ["ansible-playbook", "--version"]