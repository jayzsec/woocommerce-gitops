#!/bin/bash
#
# WooCommerce Deployment Script
# This script automates the deployment of WooCommerce using Ansible
#

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Deployment directory
DEPLOY_DIR="$(pwd)/woocommerce-deploy"
TEMPLATES_DIR="$DEPLOY_DIR/templates"
SSH_KEY_PATH="$HOME/.ssh/woocommerce-key.pem"
ENV_FILE="$DEPLOY_DIR/.env"

# Print banner
echo -e "${BOLD}${BLUE}"
echo "=========================================================="
echo "              WooCommerce Deployment Script               "
echo "=========================================================="
echo -e "${RESET}"

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo -e "${RED}Ansible is not installed. Please install Ansible first.${RESET}"
    echo "On Amazon Linux: sudo dnf install ansible -y"
    echo "On Ubuntu: sudo apt install ansible -y"
    echo "On macOS: brew install ansible"
    exit 1
fi

# Create deployment directory structure
echo -e "${YELLOW}Setting up deployment directory...${RESET}"
mkdir -p "$DEPLOY_DIR"
mkdir -p "$TEMPLATES_DIR"

# Load environment variables if they exist
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}Loading saved configuration...${RESET}"
    source "$ENV_FILE"
    
    # Show current configuration
    echo -e "\n${BOLD}Current configuration:${RESET}"
    echo "EC2 Public IP: ${EC2_PUBLIC_IP:-Not set}"
    echo "Database Name: ${DB_NAME:-Not set}"
    echo "Database User: ${DB_USER:-Not set}" 
    echo "Database Host: ${DB_HOST:-Not set}"
    echo "SSH Key Path: ${SSH_KEY_PATH:-Not set}"
    
    read -p "Do you want to use this configuration? (y/n): " USE_SAVED
    if [[ ! "$USE_SAVED" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Will collect new configuration values...${RESET}"
        # Clear variables to force collection of new values
        EC2_PUBLIC_IP=""
        DB_NAME=""
        DB_USER=""
        DB_PASSWORD=""
        DB_HOST=""
    else
        # Ask only for password if not wanting to reuse (for security)
        if [ -z "$DB_PASSWORD" ]; then
            read -sp "Database Password: " DB_PASSWORD
            echo ""
        else
            read -sp "Database Password (press Enter to keep current password): " NEW_PASSWORD
            echo ""
            if [ ! -z "$NEW_PASSWORD" ]; then
                DB_PASSWORD="$NEW_PASSWORD"
            fi
        fi
    fi
fi

# Check if SSH key exists with proper permissions
if [ -z "$SSH_KEY_PATH" ] || [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}SSH key not found at $SSH_KEY_PATH${RESET}"
    read -p "Enter the path to your EC2 SSH key file: " CUSTOM_KEY_PATH
    
    if [ -f "$CUSTOM_KEY_PATH" ]; then
        SSH_KEY_PATH="$CUSTOM_KEY_PATH"
    else
        echo -e "${RED}Invalid SSH key path. Exiting.${RESET}"
        exit 1
    fi
fi

# Ensure SSH key has correct permissions
chmod 600 "$SSH_KEY_PATH"
echo -e "${GREEN}SSH key configured at: $SSH_KEY_PATH${RESET}"

# Collect EC2 instance details if not already set
if [ -z "$EC2_PUBLIC_IP" ]; then
    echo -e "\n${BOLD}Please provide the following information:${RESET}"
    read -p "EC2 Public IP address: " EC2_PUBLIC_IP
    if [ -z "$EC2_PUBLIC_IP" ]; then
        echo -e "${RED}EC2 IP address is required. Exiting.${RESET}"
        exit 1
    fi
fi

# Collect database details if not already set
if [ -z "$DB_NAME" ]; then
    read -p "Database Name: " DB_NAME
fi

if [ -z "$DB_USER" ]; then
    read -p "Database User: " DB_USER
fi

if [ -z "$DB_PASSWORD" ]; then
    read -sp "Database Password: " DB_PASSWORD
    echo ""
fi

if [ -z "$DB_HOST" ]; then
    read -p "Database Host: " DB_HOST
fi

# Validate all required fields
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ]; then
    echo -e "${RED}All database fields are required. Exiting.${RESET}"
    exit 1
fi

# Save environment variables to file (except password)
echo -e "${YELLOW}Saving configuration...${RESET}"
cat > "$ENV_FILE" << EOF
EC2_PUBLIC_IP="$EC2_PUBLIC_IP"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_HOST="$DB_HOST"
SSH_KEY_PATH="$SSH_KEY_PATH"
EOF

# Secure the environment file
chmod 600 "$ENV_FILE"

# Create inventory file
echo -e "${YELLOW}Creating inventory file...${RESET}"
cat > "$DEPLOY_DIR/inventory.ini" << EOF
[ec2]
$EC2_PUBLIC_IP ansible_user=ec2-user ansible_ssh_private_key_file=$SSH_KEY_PATH ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

# Create wp-config.php template
echo -e "${YELLOW}Creating WordPress configuration template...${RESET}"
cat > "$TEMPLATES_DIR/wp-config.php.j2" << 'EOF'
<?php
// Basic DB settings
define('DB_NAME', '{{ db_name }}');
define('DB_USER', '{{ db_user }}');
define('DB_PASSWORD', '{{ db_password }}');
define('DB_HOST', '{{ db_host }}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

// Security keys
define('AUTH_KEY',         '{{ lookup('password', '/dev/null chars=ascii_letters length=64') }}');
define('SECURE_AUTH_KEY',  '{{ lookup('password', '/dev/null chars=ascii_letters length=64') }}');
define('LOGGED_IN_KEY',    '{{ lookup('password', '/dev/null chars=ascii_letters length=64') }}');
define('NONCE_KEY',        '{{ lookup('password', '/dev/null chars=ascii_letters length=64') }}');
define('AUTH_SALT',        '{{ lookup('password', '/dev/null chars=ascii_letters length=64') }}');
define('SECURE_AUTH_SALT', '{{ lookup('password', '/dev/null chars=ascii_letters length=64') }}');
define('LOGGED_IN_SALT',   '{{ lookup('password', '/dev/null chars=ascii_letters length=64') }}');
define('NONCE_SALT',       '{{ lookup('password', '/dev/null chars=ascii_letters length=64') }}');

// WordPress database table prefix
$table_prefix = 'wp_';

// For developers: WordPress debugging mode
define('WP_DEBUG', false);

// Limit revisions
define('WP_POST_REVISIONS', 3);

// Disable file editing from admin
define('DISALLOW_FILE_EDIT', true);

// Auto-save interval
define('AUTOSAVE_INTERVAL', 160); // seconds

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
EOF

# Create Apache virtual host template
echo -e "${YELLOW}Creating Apache configuration template...${RESET}"
cat > "$TEMPLATES_DIR/wordpress.conf.j2" << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@example.com
    DocumentRoot /var/www/html/wordpress
    
    <Directory /var/www/html/wordpress>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog /var/log/httpd/wordpress_error.log
    CustomLog /var/log/httpd/wordpress_access.log combined
</VirtualHost>
EOF

# Create Ansible playbook
echo -e "${YELLOW}Creating Ansible playbook...${RESET}"
cat > "$DEPLOY_DIR/woocommerce-playbook.yml" << 'EOF'
---
- name: Install and configure WooCommerce
  hosts: ec2
  become: yes
  vars:
    db_name: "{{ lookup('env', 'DB_NAME') }}"
    db_user: "{{ lookup('env', 'DB_USER') }}"
    db_password: "{{ lookup('env', 'DB_PASSWORD') }}"
    db_host: "{{ lookup('env', 'DB_HOST') }}"
  tasks:
    - name: Update package cache
      dnf:
        name: "*"
        state: latest
        
    - name: Install Apache, PHP 8.1+, MySQL client, and other required packages
      dnf:
        name: "{{ packages }}"
        state: present
      vars:
        packages:
          - httpd
          - php
          - php-mysqlnd
          - php-json
          - php-gd
          - php-mbstring
          - php-xml
          - php-intl
          - php-curl
          - php-zip
          - mariadb105
          - unzip
          - wget
          
    - name: Start and enable Apache
      service:
        name: httpd
        state: started
        enabled: yes
        
    - name: Create Apache virtual host configuration
      template:
        src: templates/wordpress.conf.j2
        dest: /etc/httpd/conf.d/wordpress.conf
      notify: Restart Apache
        
    - name: Download WordPress
      get_url:
        url: https://wordpress.org/latest.tar.gz
        dest: /tmp/wordpress.tar.gz
        
    - name: Create WordPress directory
      file:
        path: /var/www/html/wordpress
        state: directory
        owner: apache
        group: apache
        
    - name: Extract WordPress
      unarchive:
        src: /tmp/wordpress.tar.gz
        dest: /var/www/html/
        remote_src: yes
        
    - name: Configure WordPress wp-config.php
      template:
        src: templates/wp-config.php.j2
        dest: /var/www/html/wordpress/wp-config.php
        owner: apache
        group: apache
        mode: '0640'
        
    - name: Install WooCommerce plugin
      shell: |
        wget https://downloads.wordpress.org/plugin/woocommerce.latest-stable.zip -P /tmp
        unzip /tmp/woocommerce.latest-stable.zip -d /var/www/html/wordpress/wp-content/plugins
      args:
        creates: /var/www/html/wordpress/wp-content/plugins/woocommerce
        
    - name: Set permissions
      file:
        path: /var/www/html/wordpress
        owner: apache
        group: apache
        recurse: yes
        mode: 'u=rwX,g=rX,o=rX'
        
    - name: Configure SELinux for WordPress (if enabled)
      shell: |
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/wordpress(/.*)?"
        restorecon -Rv /var/www/html/wordpress
      ignore_errors: yes
      
  handlers:
    - name: Restart Apache
      service:
        name: httpd
        state: restarted
EOF

# Run Ansible playbook with the provided variables
echo -e "\n${BOLD}${GREEN}Deployment files created. Ready to deploy.${RESET}"
read -p "Do you want to run the deployment now? (y/n): " RUN_NOW

if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Starting deployment...${RESET}"
    
    # Export database variables
    export DB_NAME="$DB_NAME"
    export DB_USER="$DB_USER"
    export DB_PASSWORD="$DB_PASSWORD"
    export DB_HOST="$DB_HOST"
    
    # Run the Ansible playbook
    cd "$DEPLOY_DIR"
    ansible-playbook -i inventory.ini woocommerce-playbook.yml
    
    # Check if deployment was successful
    if [ $? -eq 0 ]; then
        echo -e "\n${BOLD}${GREEN}WooCommerce deployment completed successfully!${RESET}"
        echo -e "${BOLD}WordPress URL: http://$EC2_PUBLIC_IP/wordpress${RESET}"
        echo -e "Complete the WordPress setup by visiting the URL above."
    else
        echo -e "\n${BOLD}${RED}Deployment encountered errors. Please check the output above.${RESET}"
    fi
else
    echo -e "\n${YELLOW}Deployment files are ready in: $DEPLOY_DIR${RESET}"
    echo -e "When you're ready to deploy, navigate to that directory and run:"
    echo -e "${BOLD}DB_NAME=\"$DB_NAME\" DB_USER=\"$DB_USER\" DB_PASSWORD=\"your_password\" DB_HOST=\"$DB_HOST\" ansible-playbook -i inventory.ini woocommerce-playbook.yml${RESET}"
fi

echo -e "\n${BOLD}${BLUE}Thank you for using the WooCommerce Deployment Script!${RESET}"