#!/bin/bash
# terraform/user_data.sh - Enhanced EC2 initialization script

set -e

# Configuration from Terraform
DB_HOST="${db_host}"
DB_NAME="${db_name}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
APP_NAME="${app_name}"
ENVIRONMENT="${environment}"

# Logging setup
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

log "Starting user data script for $APP_NAME in $ENVIRONMENT environment"

# Update system packages
log "Updating system packages..."
apt-get update -y || error_exit "Failed to update packages"
apt-get upgrade -y || error_exit "Failed to upgrade packages"

# Install essential packages
log "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    htop \
    vim \
    tree \
    git \
    build-essential \
    python3 \
    python3-pip \
    postgresql-client \
    nginx \
    fail2ban \
    ufw \
    logrotate || error_exit "Failed to install essential packages"

# Install AWS CLI v2
log "Installing AWS CLI v2..."
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || error_exit "Failed to download AWS CLI"
unzip -q awscliv2.zip || error_exit "Failed to extract AWS CLI"
./aws/install --update || error_exit "Failed to install AWS CLI"
rm -rf aws awscliv2.zip

# Verify AWS CLI installation
aws --version || error_exit "AWS CLI installation failed"

# Install CloudWatch Agent
log "Installing CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm -O /tmp/amazon-cloudwatch-agent.rpm
rpm -U /tmp/amazon-cloudwatch-agent.rpm || error_exit "Failed to install CloudWatch Agent"

# Install Docker
log "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || error_exit "Failed to add Docker GPG key"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y || error_exit "Failed to update package list"
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error_exit "Failed to install Docker"

# Start and enable Docker
systemctl start docker || error_exit "Failed to start Docker"
systemctl enable docker || error_exit "Failed to enable Docker"
usermod -aG docker ubuntu || error_exit "Failed to add ubuntu user to docker group"

# Install Node.js 18.x
log "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash - || error_exit "Failed to add Node.js repository"
apt-get install -y nodejs || error_exit "Failed to install Node.js"

# Verify Node.js installation
node --version || error_exit "Node.js installation failed"
npm --version || error_exit "NPM installation failed"

# Install PM2 globally
log "Installing PM2..."
npm install -g pm2 || error_exit "Failed to install PM2"

# Create application directory structure
log "Creating application directory structure..."
mkdir -p /opt/$APP_NAME/{logs,tmp,public,config} || error_exit "Failed to create app directories"
mkdir -p /var/log/$APP_NAME || error_exit "Failed to create log directory"
chown -R ubuntu:ubuntu /opt/$APP_NAME /var/log/$APP_NAME || error_exit "Failed to set directory ownership"

# Create environment file
log "Creating environment configuration..."
cat > /opt/$APP_NAME/.env << EOF
# Database Configuration
DB_HOST=$DB_HOST
DB_NAME=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_PORT=5432
DATABASE_URL=postgresql://$DB_USERNAME:$DB_PASSWORD@$DB_HOST:5432/$DB_NAME

# S3 Configuration
S3_BUCKET=$S3_BUCKET
AWS_REGION=$AWS_REGION
AWS_DEFAULT_REGION=$AWS_REGION

# Application Configuration
NODE_ENV=production
PORT=3000
APP_NAME=$APP_NAME
ENVIRONMENT=$ENVIRONMENT

# Logging
LOG_LEVEL=info
LOG_DIR=/var/log/$APP_NAME

# Security
JWT_SECRET=change-me-in-production
BCRYPT_ROUNDS=12

# Features
ENABLE_MONITORING=true
ENABLE_HEALTH_CHECK=true
ENABLE_METRICS=true
EOF

chown ubuntu:ubuntu /opt/$APP_NAME/.env || error_exit "Failed to set .env ownership"
chmod 600 /opt/$APP_NAME/.env || error_exit "Failed to set .env permissions"

# Test database connectivity
log "Testing database connectivity..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USERNAME -d $DB_NAME -c "SELECT version();" >> $LOG_FILE 2>&1 && log "Database connection successful" || log "Warning: Database connection failed"

# Test S3 connectivity
log "Testing S3 connectivity..."
aws s3 ls s3://$S3_BUCKET --region $AWS_REGION >> $LOG_FILE 2>&1 && log "S3 connection successful" || log "Warning: S3 connection failed"

# Create S3 bucket structure
log "Creating S3 bucket structure..."
aws s3api put-object --bucket $S3_BUCKET --key "uploads/" --region $AWS_REGION >> $LOG_FILE 2>&1 || log "Warning: Failed to create uploads folder"
aws s3api put-object --bucket $S3_BUCKET --key "logs/" --region $AWS_REGION >> $LOG_FILE 2>&1 || log "Warning: Failed to create logs folder"
aws s3api put-object --bucket $S3_BUCKET --key "backups/" --region $AWS_REGION >> $LOG_FILE 2>&1 || log "Warning: Failed to create backups folder"

# Configure Nginx
log "Configuring Nginx..."
cat > /etc/nginx/sites-available/$APP_NAME << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;
    client_max_body_size 100M;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Health check endpoint
    location /health {
        access_log off;
        return 200 '{"status": "healthy", "timestamp": "$time_iso8601", "server": "$hostname"}';
        add_header Content-Type application/json;
    }

    # Application proxy
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Proxy timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;
    }

    # Static files
    location /static/ {
        alias /opt/$APP_NAME/public/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        gzip_static on;
    }
}
EOF

# Enable the site and disable default
rm -f /etc/nginx/sites-enabled/default || log "Default site not found"
ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/ || error_exit "Failed to enable Nginx site"

# Test Nginx configuration
nginx -t || error_exit "Nginx configuration test failed"

# Start and enable Nginx
systemctl restart nginx || error_exit "Failed to restart Nginx"
systemctl enable nginx || error_exit "Failed to enable Nginx"

# Create sample application
log "Creating sample application..."
cat > /opt/$APP_NAME/app.js << 'EOF'
const express = require('express');
const { Pool } = require('pg');
const AWS = require('aws-sdk');
const app = express();

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL
});

// S3 client
const s3 = new AWS.S3({
    region: process.env.AWS_REGION
});

// Health check endpoint
app.get('/health', async (req, res) => {
    try {
        // Test database connection
        await pool.query('SELECT 1');
        
        // Test S3 connection
        await s3.headBucket({ Bucket: process.env.S3_BUCKET }).promise();
        
        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            services: {
                database: 'connected',
                s3: 'connected'
            }
        });
    } catch (error) {
        res.status(500).json({
            status: 'unhealthy',
            timestamp: new Date().toISOString(),
            error: error.message
        });
    }
});

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'Application is running!',
        environment: process.env.ENVIRONMENT,
        timestamp: new Date().toISOString()
    });
});

// API endpoints
app.get('/api/status', (req, res) => {
    res.json({
        status: 'running',
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        version: process.version
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
EOF

# Create package.json
cat > /opt/$APP_NAME/package.json << 'EOF'
{
  "name": "sample-app",
  "version": "1.0.0",
  "description": "Sample application with PostgreSQL and S3",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0",
    "aws-sdk": "^2.1400.0"
  }
}
EOF

chown -R ubuntu:ubuntu /opt/$APP_NAME || error_exit "Failed to set application ownership"

# Install application dependencies
log "Installing application dependencies..."
cd /opt/$APP_NAME
sudo -u ubuntu npm install || log "Warning: Failed to install npm dependencies"

# Create systemd service
log "Creating systemd service..."
cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=$APP_NAME Node.js application
After=network.target postgresql.service

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/$APP_NAME
Environment=NODE_ENV=production
EnvironmentFile=/opt/$APP_NAME/.env
ExecStart=/usr/bin/node /opt/$APP_NAME/app.js
ExecReload=/bin/kill -USR2 \$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=30
RestartSec=5
Restart=on-failure

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/opt/$APP_NAME
ReadWritePaths=/var/log/$APP_NAME

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$APP_NAME

[Install]
WantedBy=multi-user.target
EOF

# Configure log rotation
log "Configuring log rotation..."
cat > /etc/logrotate.d/$APP_NAME << EOF
/var/log/$APP_NAME/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
    postrotate
        systemctl reload $APP_NAME > /dev/null 2>&1 || true
    endscript
}
EOF

# Configure firewall
log "Configuring firewall..."
ufw --force enable || log "Warning: Failed to enable UFW"
ufw allow ssh || log "Warning: Failed to allow SSH"
ufw allow 'Nginx Full' || log "Warning: Failed to allow Nginx"

# Configure fail2ban
log "Configuring fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local || log "Warning: Failed to copy fail2ban config"
systemctl enable fail2ban || log "Warning: Failed to enable fail2ban"
systemctl start fail2ban || log "Warning: Failed to start fail2ban"

# Start application service
log "Starting application service..."
systemctl daemon-reload || error_exit "Failed to reload systemd"
systemctl enable $APP_NAME || error_exit "Failed to enable application service"
systemctl start $APP_NAME || error_exit "Failed to start application service"

# Wait for application to start
sleep 10

# Verify application is running
log "Verifying application status..."
systemctl is-active --quiet $APP_NAME && log "Application service is running" || log "Warning: Application service is not running"
systemctl is-active --quiet nginx && log "Nginx service is running" || log "Warning: Nginx service is not running"

# Test health endpoint
curl -f http://localhost/health > /dev/null 2>&1 && log "Health endpoint is responding" || log "Warning: Health endpoint is not responding"

# Create monitoring script
log "Creating monitoring script..."
cat > /opt/$APP_NAME/monitor.sh << 'EOF'
#!/bin/bash
# Simple monitoring script

LOGFILE="/var/log/$APP_NAME/monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Check if application is running
if systemctl is-active --quiet $APP_NAME; then
    echo "$DATE - Application is running" >> $LOGFILE
else
    echo "$DATE - Application is NOT running" >> $LOGFILE
    systemctl restart $APP_NAME
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "$DATE - WARNING: Disk usage is ${DISK_USAGE}%" >> $LOGFILE
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ $MEM_USAGE -gt 90 ]; then
    echo "$DATE - WARNING: Memory usage is ${MEM_USAGE}%" >> $LOGFILE
fi
EOF

chmod +x /opt/$APP_NAME/monitor.sh || error_exit "Failed to make monitor script executable"
chown ubuntu:ubuntu /opt/$APP_NAME/monitor.sh || error_exit "Failed to set monitor script ownership"

# Add monitoring cron job
log "Adding monitoring cron job..."
echo "*/5 * * * * ubuntu /opt/$APP_NAME/monitor.sh" >> /etc/crontab || log "Warning: Failed to add monitoring cron job"

# Clean up
log "Cleaning up..."
apt-get autoremove -y || log "Warning: Failed to autoremove packages"
apt-get autoclean || log "Warning: Failed to autoclean packages"

log "User data script completed successfully!"
log "Application should be accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
log "Health check endpoint: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/health"

# Send completion notification to CloudWatch
aws logs create-log-stream --log-group-name "/aws/ec2/$APP_NAME" --log-stream-name "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)/user-data" --region $AWS_REGION 2>/dev/null || log "Warning: Failed to create CloudWatch log stream"

echo "User data execution completed at $(date)" | aws logs put-log-events --log-group-name "/aws/ec2/$APP_NAME" --log-stream-name "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)/user-data" --log-events timestamp=$(date +%s000),message="User data execution completed successfully" --region $AWS_REGION 2>/dev/null || log "Warning: Failed to send CloudWatch log event"