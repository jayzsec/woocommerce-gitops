#!/bin/bash
#
# WordPress Fix Script
# This script fixes common WordPress deployment issues
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
ENV_FILE="$DEPLOY_DIR/.env"

# Print banner
echo -e "${BOLD}${BLUE}"
echo "=========================================================="
echo "           WordPress 'Not Found' Error Fix Script         "
echo "=========================================================="
echo -e "${RESET}"

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Environment file not found. Please run the deployment script first.${RESET}"
    exit 1
fi

# Load environment variables
source "$ENV_FILE"

# Verify EC2 IP is available
if [ -z "$EC2_PUBLIC_IP" ]; then
    echo -e "${RED}EC2 Public IP not found in environment file.${RESET}"
    read -p "Enter your EC2 Public IP address: " EC2_PUBLIC_IP
    if [ -z "$EC2_PUBLIC_IP" ]; then
        echo -e "${RED}EC2 IP address is required. Exiting.${RESET}"
        exit 1
    fi
fi

# Create fix playbook
echo -e "${YELLOW}Creating fix playbook...${RESET}"
cat > "$DEPLOY_DIR/wordpress-fix.yml" << 'EOF'
---
- name: Troubleshoot and Fix WordPress Access
  hosts: ec2
  become: yes
  tasks:
    - name: Check if WordPress directory exists
      stat:
        path: /var/www/html/wordpress
      register: wordpress_dir
      
    - name: Check WordPress directory content
      command: ls -la /var/www/html/wordpress
      register: wordpress_content
      ignore_errors: yes
      changed_when: false
      
    - name: Debug WordPress directory structure
      debug:
        msg: "{{ wordpress_content.stdout_lines }}"
      when: wordpress_dir.stat.exists
        
    - name: Check Apache configuration
      command: apachectl -t
      register: apache_config_check
      ignore_errors: yes
      changed_when: false
      
    - name: Display Apache virtual hosts
      command: apachectl -S
      register: apache_vhosts
      ignore_errors: yes
      changed_when: false
        
    - name: Debug Apache configuration
      debug:
        msg: 
          - "Config test result: {{ apache_config_check.stdout }}"
          - "Virtual hosts: {{ apache_vhosts.stdout_lines }}"
          
    - name: Ensure DocumentRoot exists
      file:
        path: /var/www/html/wordpress
        state: directory
        owner: apache
        group: apache
        mode: '0755'
        
    # Fix 1: Check if WordPress is extracted at the wrong location
    - name: Check if WordPress was extracted to wrong directory
      stat:
        path: /var/www/html/wordpress/wordpress
      register: nested_wordpress
      
    - name: Fix nested WordPress directory if it exists
      shell: mv /var/www/html/wordpress/wordpress/* /var/www/html/wordpress/ && rmdir /var/www/html/wordpress/wordpress
      when: nested_wordpress.stat.exists
      
    # Fix 2: Check if WordPress is in parent directory
    - name: Check if WordPress was extracted to parent directory
      stat:
        path: /var/www/html/index.php
      register: parent_wordpress
      
    - name: Fix WordPress in parent directory
      shell: rm -rf /var/www/html/wordpress && mkdir -p /var/www/html/wordpress && mv /var/www/html/*.php /var/www/html/wp-* /var/www/html/wordpress/
      when: parent_wordpress.stat.exists
      
    # Fix 3: Create a symbolic link
    - name: Create symbolic link from /wordpress to actual location
      file:
        src: /var/www/html/wordpress
        dest: /var/www/wordpress
        state: link
        
    # Fix 4: Update SELinux context
    - name: Set proper SELinux context
      shell: |
        semanage fcontext -a -t httpd_sys_content_t "/var/www/html/wordpress(/.*)?"
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/wordpress/wp-content(/.*)?"
        restorecon -Rv /var/www/html/wordpress
      ignore_errors: yes

    # Fix 5: Check and update Apache configuration
    - name: Ensure Apache default document root is updated
      lineinfile:
        path: /etc/httpd/conf/httpd.conf
        regexp: '^DocumentRoot.*'
        line: 'DocumentRoot "/var/www/html/wordpress"'
        
    - name: Ensure Directory directive is updated
      blockinfile:
        path: /etc/httpd/conf/httpd.conf
        marker: "# {mark} ANSIBLE MANAGED BLOCK FOR WORDPRESS"
        block: |
          <Directory "/var/www/html/wordpress">
              AllowOverride All
              Require all granted
          </Directory>
        
    - name: Create .htaccess file for WordPress
      copy:
        dest: /var/www/html/wordpress/.htaccess
        content: |
          # BEGIN WordPress
          <IfModule mod_rewrite.c>
          RewriteEngine On
          RewriteBase /
          RewriteRule ^index\.php$ - [L]
          RewriteCond %{REQUEST_FILENAME} !-f
          RewriteCond %{REQUEST_FILENAME} !-d
          RewriteRule . /index.php [L]
          </IfModule>
          # END WordPress
        owner: apache
        group: apache
        mode: '0644'
        
    - name: Enable mod_rewrite
      lineinfile:
        path: /etc/httpd/conf/httpd.conf
        regexp: '^#LoadModule rewrite_module modules/mod_rewrite.so'
        line: 'LoadModule rewrite_module modules/mod_rewrite.so'
      
    - name: Restart Apache
      service:
        name: httpd
        state: restarted
EOF

# Run the fix playbook
echo -e "${YELLOW}Running WordPress fix playbook...${RESET}"
cd "$DEPLOY_DIR"
ansible-playbook -i inventory.ini wordpress-fix.yml

# Check if the fix was successful
if [ $? -eq 0 ]; then
    echo -e "\n${BOLD}${GREEN}Fix completed. Try accessing your WordPress site now:${RESET}"
    echo -e "${BOLD}WordPress URL: http://$EC2_PUBLIC_IP/wordpress${RESET}"
    echo -e "If it still doesn't work, try accessing these alternative URLs:"
    echo -e "1. http://$EC2_PUBLIC_IP/ (root URL)"
    echo -e "2. http://$EC2_PUBLIC_IP/wordpress/wp-admin/ (direct admin access)"
else
    echo -e "\n${BOLD}${RED}Fix encountered errors. Please check the output above.${RESET}"
fi

echo -e "\n${BOLD}${BLUE}WordPress Fix Script Complete${RESET}"