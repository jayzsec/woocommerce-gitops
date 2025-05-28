#!/bin/bash
#
# WooCommerce Deployment Script (Refactored)
# This script automates the deployment of WooCommerce using Ansible
# and a dynamic inventory.
#

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Print banner
echo -e "${BOLD}${BLUE}"
echo "=========================================================="
echo "        WooCommerce Ansible Deployment Script             "
echo "=========================================================="
echo -e "${RESET}"

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo -e "${RED}Ansible is not installed. Please install Ansible first.${RESET}"
    echo "On Amazon Linux: sudo dnf install ansible -y"
    echo "On Ubuntu: sudo apt install ansible -y"
    echo "On macOS: brew install ansible"
    exit 1
else
    echo -e "${GREEN}Ansible is installed.${RESET}"
fi

# Inform about EC2 instance tagging requirement
echo -e "\n${BOLD}${YELLOW}Important Note for EC2 Dynamic Inventory:${RESET}"
echo -e "${YELLOW}This script uses the 'inventory/aws_ec2.yml' dynamic inventory (aws_ec2 plugin).${RESET}"
echo -e "${YELLOW}Please ensure your target EC2 instance is tagged with:${RESET}"
echo -e "${YELLOW}  ${BOLD}Name: woocommerce-server${RESET}"
echo -e "${YELLOW}And that your AWS credentials and region are configured for Ansible (e.g., via environment variables like AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, or ~/.aws/credentials).${RESET}"
echo -e "${YELLOW}The EC2 instance also needs an IAM role that allows Ansible to gather facts about it (e.g., ec2:DescribeInstances).${RESET}"


# Collect database details
echo -e "\n${BOLD}Please provide the following database credentials (will be passed as environment variables to Ansible):${RESET}"
read -p "Database Name (e.g., woocommerce_db): " DB_NAME
read -p "Database User (e.g., wp_user): " DB_USER
read -sp "Database Password: " DB_PASSWORD
echo ""
read -p "Database Host (RDS endpoint or IP): " DB_HOST

# Validate all required fields
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ]; then
    echo -e "${RED}All database fields (Name, User, Password, Host) are required. Exiting.${RESET}"
    exit 1
fi

echo -e "\n${GREEN}Database credentials collected.${RESET}"

# Run Ansible playbook
echo -e "\n${BOLD}${GREEN}Ready to run Ansible playbook.${RESET}"
read -p "Do you want to start the deployment now? (y/n): " RUN_NOW

if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Starting deployment with Ansible...${RESET}"
    
    # Export database variables for the playbook
    # The playbook `ansible/playbooks/deploy.yml` uses lookup('env', 'VAR_NAME')
    export DB_NAME
    export DB_USER
    export DB_PASSWORD
    export DB_HOST
    
    # Assuming this script is run from the 'ansible/' directory.
    # If run from project root, paths would be ansible/inventory/aws_ec2.yml and ansible/playbooks/deploy.yml
    echo -e "${YELLOW}Executing: ansible-playbook -i inventory/aws_ec2.yml playbooks/deploy.yml${RESET}"
    ansible-playbook -i inventory/aws_ec2.yml playbooks/deploy.yml
    
    # Check if deployment was successful
    if [ $? -eq 0 ]; then
        echo -e "\n${BOLD}${GREEN}WooCommerce deployment playbook executed successfully!${RESET}"
        echo -e "${GREEN}Check the Ansible output above for details. You may need to find the EC2 instance's public IP address manually if not previously known (e.g., from the AWS console).${RESET}"
        echo -e "${GREEN}Once you have the IP, your WordPress site should be accessible at: http://<EC2_PUBLIC_IP>/wordpress${RESET}"
    else
        echo -e "\n${BOLD}${RED}Deployment playbook execution encountered errors. Please check the Ansible output above.${RESET}"
    fi
else
    echo -e "\n${YELLOW}Deployment aborted by user.${RESET}"
    echo -e "When you're ready to deploy, re-run this script and provide the database credentials."
fi

echo -e "\n${BOLD}${BLUE}Thank you for using the WooCommerce Deployment Script!${RESET}"
