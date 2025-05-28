#!/bin/bash
#
# WordPress Fix Script (Refactored)
# This script runs the wordpress-fix.yml playbook using a dynamic inventory
# to troubleshoot common WordPress deployment issues.
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
echo "       WordPress 'Not Found' Error Fix Script             "
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
echo -e "${YELLOW}And that your AWS credentials and region are configured for Ansible (e.g., via environment variables or ~/.aws/credentials).${RESET}"
echo -e "${YELLOW}The EC2 instance also needs an IAM role that allows Ansible to gather facts about it (e.g., ec2:DescribeInstances).${RESET}"

# Run Ansible playbook
echo -e "\n${BOLD}${GREEN}Ready to run the WordPress fix playbook.${RESET}"
read -p "Do you want to start the fix process now? (y/n): " RUN_NOW

if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Starting WordPress fix playbook with Ansible...${RESET}"
    
    # Assuming this script is run from the 'ansible/' directory.
    echo -e "${YELLOW}Executing: ansible-playbook -i inventory/aws_ec2.yml playbooks/wordpress-fix.yml${RESET}"
    ansible-playbook -i inventory/aws_ec2.yml playbooks/wordpress-fix.yml
    
    # Check if deployment was successful
    if [ $? -eq 0 ]; then
        echo -e "\n${BOLD}${GREEN}WordPress fix playbook executed successfully!${RESET}"
        echo -e "${GREEN}Check the Ansible output above for details of actions taken.${RESET}"
        echo -e "${GREEN}Try accessing your WordPress site. You might need to find the EC2 instance's public IP address manually (e.g., from the AWS console).${RESET}"
        echo -e "${GREEN}WordPress URL: http://<EC2_PUBLIC_IP>/wordpress${RESET}"
    else
        echo -e "\n${BOLD}${RED}WordPress fix playbook execution encountered errors. Please check the Ansible output above.${RESET}"
    fi
else
    echo -e "\n${YELLOW}Fix process aborted by user.${RESET}"
    echo -e "When you're ready, re-run this script."
fi

echo -e "\n${BOLD}${BLUE}WordPress Fix Script Complete${RESET}"
