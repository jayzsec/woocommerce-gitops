#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -x # Print commands and their arguments as they are executed.

# 1. Set environment variables for the playbook
export DB_NAME="test_db"
export DB_USER="test_user"
export DB_PASSWORD="test_password"
export DB_HOST="localhost" # Will use the MariaDB set up in Dockerfile
export DOMAIN_NAME="localhost"
export CERTBOT_EMAIL="test@example.com"
export REMOTE_SYSLOG_SERVER="localhost" # For testing, logs can go to localhost rsyslog if it's running, or just be ignored.

# Ensure mysqld is running before starting the playbook
echo "Starting MariaDB service..."
/usr/sbin/mysqld --user=mysql --datadir=/var/lib/mysql &
# Give it a few seconds to initialize properly
sleep 10

# Check if mysqld started
if ! pgrep mysqld; then
  echo "MariaDB (mysqld) failed to start!"
  # Attempt to get logs if possible (may not work if mysqld failed very early)
  if [ -f /var/log/mariadb/mariadb.log ]; then
    echo "--- MariaDB Log ---"
    cat /var/log/mariadb/mariadb.log
    echo "-------------------"
  fi
  exit 1
fi
echo "MariaDB service started."

# 2. Run the Ansible playbook
# Target woocommerce-playbook.yml which includes WordPress setup
# We need to specify the inventory, which can be a simple localhost entry.
echo "Running Ansible playbook..."
ansible-playbook /ansible/woocommerce-deploy/woocommerce-playbook.yml -i /ansible/woocommerce-deploy/inventory.ini.template --connection=local

# 3. Check if httpd is running
echo "Checking if httpd service is running..."
if ! systemctl is-active --quiet httpd; then
  echo "httpd service is not running."
  # Attempt to get httpd logs
  journalctl -u httpd --no-pager
  exit 1
fi
echo "httpd service is running."

# 4. Check if WordPress health-check endpoint is accessible
echo "Checking WordPress health-check endpoint..."
# Wait a bit for httpd to be fully up and WordPress initialized
sleep 5
if curl -kfsS http://localhost/wordpress/health-check.php | grep -q "WordPress OK"; then
  echo "Health check successful: WordPress OK"
else
  echo "Health check failed. Output from curl:"
  curl -kvi http://localhost/wordpress/health-check.php || echo "Curl command failed"
  # Show relevant logs
  echo "--- Apache Error Log ---"
  cat /var/log/httpd/wordpress_error.log || echo "Apache error log not found or empty."
  echo "------------------------"
  echo "--- WordPress Debug Log ---"
  cat /var/log/wordpress/debug.log || echo "WordPress debug log not found or empty."
  echo "-------------------------"
  exit 1
fi

echo "Playbook test completed successfully!"
exit 0
