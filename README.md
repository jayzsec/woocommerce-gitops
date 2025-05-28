# WooCommerce GitOps Pipeline

This project automates the deployment of a WooCommerce store on AWS using Terraform, Ansible, and GitHub Actions. Designed for small to medium businesses, it provisions a cost-effective EC2 instance and RDS database, and deploys WordPress with WooCommerce. The pipeline showcases DevOps best practices, including Infrastructure as Code (IaC), GitOps, and Continuous Integration/Continuous Deployment (CI/CD).

## Architecture

![Architecture Diagram](architecture.png)

The architecture includes:

- **VPC with public subnets** in multiple availability zones
- **EC2 instance (t2.micro)** running Amazon Linux 2023 for WordPress + WooCommerce
- **RDS MySQL database (db.t3.micro)** for WordPress data storage
- **Security groups** for controlled access to resources
- **S3 and DynamoDB** for Terraform state management
- **GitHub Actions** for CI/CD pipeline automation

## Project Structure

<!-- ![Project Structure](project_structure.png) -->

The project is organized as follows:

- **`.github/workflows/`**: Contains GitHub Actions workflow definitions
  - `deploy.yml`: Main CI/CD pipeline for deploying the infrastructure and application

- **`terraform/`**: Contains Terraform configurations for AWS infrastructure
  - `main.tf`: Main infrastructure definition
  - `variables.tf`: Input variables for customization
  - `outputs.tf`: Output values after infrastructure creation
  - `provider.tf`: AWS provider configuration
  - `backend.tf`: Remote state configuration

- **`backend-setup/`**: Bootstrap Terraform backend infrastructure
  - `main.tf`: Creates S3 bucket and DynamoDB table for remote state

- **`ansible/`**: Contains Ansible configurations for application deployment
  - **`playbooks/`**: Organized Ansible playbooks
    - `deploy.yml`: Main playbook for WordPress and WooCommerce deployment. Pins WordPress and WooCommerce versions for predictable deployments and includes improved SELinux handling.
    - `verify-wp-config.yml`: Verifies `wp-config.php` settings.
    - `wordpress-fix.yml`: Applies various fixes for common WordPress issues.
    - `backup.yml`: Backup procedures for WordPress files and database.
    - `update.yml`: Update procedures for WordPress core and plugins.
    - `validate.yml`: Pre-deployment validation checks.
  - **`templates/`**: Jinja2 templates for configuration files
    - `wordpress.conf.j2`: Apache virtual host configuration
    - `wp-config.php.j2`: WordPress configuration template
  - **`inventory/`**: Ansible inventory configurations
    - `aws_ec2.yml`: Dynamic inventory script for AWS EC2.
  - **`deploy-woocommerce.sh`**: User-friendly helper script that runs `playbooks/deploy.yml` using the dynamic inventory. Prompts for necessary database credentials.
  - **`fix-wordpress.sh`**: Troubleshooting helper script that runs `playbooks/wordpress-fix.yml` using the dynamic inventory.

## Setup

### Prerequisites

1. AWS Account with appropriate permissions
2. GitHub repository with Actions enabled
3. Terraform (v1.1.7+)
4. Ansible (v2.9+)
5. AWS CLI configured locally

### Initial Configuration

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/woocommerce-gitops.git
   cd woocommerce-gitops
   ```

2. **Set up Terraform backend infrastructure**
   ```bash
   cd backend-setup
   terraform init
   terraform apply
   cd ..
   ```

3. **Create an EC2 key pair in AWS and download the `.pem` file**
   - Store the private key securely (e.g., `~/.ssh/your-key-name.pem`).
   - Ensure this key name matches the `ec2_key_name` variable in `terraform/variables.tf`.

4. **Review and Update Terraform Variables (`terraform/variables.tf`)**
   Before deploying, review and customize the following variables in `terraform/variables.tf`:
   - `aws_region`: The AWS region for deployment.
   - `instance_type`: EC2 instance type (default: `t2.micro`).
   - `ec2_key_name`: **Important:** Set this to the name of the EC2 key pair you created (e.g., "woocommerce-key").
   - `ssh_access_cidr`: **Security Critical:** List of CIDR blocks allowed for SSH access to the EC2 instance. Defaults to `["0.0.0.0/0"]` (open to all). **It is strongly recommended to restrict this to your IP address or specific bastion host IPs.**
   - `db_name`, `db_username`, `db_password`: Credentials for the RDS database.
   - `rds_multi_az`: Set to `true` for production for higher availability (default: `false`).
   - `rds_skip_final_snapshot`: Set to `false` for production to ensure a final snapshot is taken on deletion (default: `false`).

5. **Configure GitHub repository secrets for the CI/CD Workflow**
   Add the following secrets to your GitHub repository settings (used by `.github/workflows/deploy.yml`):
   - `AWS_ACCESS_KEY_ID`: Your AWS access key.
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key.
   - `SSH_PRIVATE_KEY`: Contents of your EC2 private key file (`.pem`) that matches `var.ec2_key_name`.
   - `TF_VAR_db_name`: Database name for WordPress (e.g., `wordpress_db`). This will be passed to Terraform.
   - `TF_VAR_db_username`: Database username (e.g., `wp_user`). This will be passed to Terraform.
   - `TF_VAR_db_password`: Secure password for the database. This will be passed to Terraform.
   - `DB_NAME_ENV`: Database name for WordPress (e.g., `wordpress_db`). Used by Ansible.
   - `DB_USER_ENV`: Database username (e.g., `wp_user`). Used by Ansible.
   - `DB_PASSWORD_ENV`: Secure password for the database. Used by Ansible.
   - `DB_HOST_ENV`: Database host. This will be populated by the Terraform output in the GitHub Actions workflow and passed to Ansible.

   *Note on Database Credentials:* The GitHub Actions workflow in `.github/workflows/deploy.yml` handles the flow of database credentials. Terraform creates the RDS instance and outputs its endpoint (`DB_HOST`). These, along with the DB name, user, and password (defined as secrets), are then passed as environment variables to the Ansible playbook. For manual deployments using `ansible/deploy-woocommerce.sh`, you will be prompted for these values.

### Deployment

#### Automated Deployment with GitHub Actions

1. **Update the variables in `terraform/variables.tf` if needed**

2. **Push changes to the `main` branch**
   ```bash
   git add .
   git commit -m "Update configuration for deployment"
   git push origin main
   ```

3. **Monitor the GitHub Actions workflow**
   - Navigate to your repository's Actions tab
   - You should see the workflow running

4. **Access your WooCommerce site**
   - Once deployment completes, find the EC2 public IP in the workflow output
   - Access your site at `http://<EC2-PUBLIC-IP>/wordpress`
   - Complete the WordPress installation wizard

#### Manual Deployment

1. **Initialize and apply Terraform configuration**
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
   Note the outputs from `terraform apply`, such as the RDS endpoint. While the `deploy-woocommerce.sh` script will prompt for the database host, understanding the Terraform outputs is useful.

2. **Run the Ansible deployment script**
   ```bash
   cd ../ansible
   ./deploy-woocommerce.sh
   ```
   This script uses `ansible/playbooks/deploy.yml` and the dynamic inventory at `ansible/inventory/aws_ec2.yml`.
   - The script will prompt you for database credentials: `DB_NAME`, `DB_USER`, `DB_PASSWORD`, and `DB_HOST` (the RDS endpoint from Terraform output).
   - **Important**: Ensure your target EC2 instance is tagged with `Name: woocommerce-server` for the dynamic inventory to detect it.

3. **Follow the script prompts to complete deployment.**

## Troubleshooting

If you encounter issues with WordPress access:

1. **Run the fix script**
   ```bash
   cd ansible
   ./fix-wordpress.sh
   ```
   This script uses `ansible/playbooks/wordpress-fix.yml` and the dynamic inventory at `ansible/inventory/aws_ec2.yml`.
   - **Important**: Ensure your target EC2 instance is tagged with `Name: woocommerce-server` for the dynamic inventory to detect it.

## Maintenance

### Backing Up Your WooCommerce Store

```bash
cd ansible
ansible-playbook -i inventory/aws_ec2.yml playbooks/backup.yml
```

### Updating WordPress and Plugins

```bash
cd ansible
ansible-playbook -i inventory/aws_ec2.yml playbooks/update.yml
```

## Cost Analysis

- **EC2 (t2.micro)**: ~$10/month (free tier eligible)
- **RDS (db.t3.micro)**: ~$15/month (free tier eligible)
- **Data transfer**: Variable, typically $1-5/month for small stores
- **S3 & DynamoDB**: <$1/month for Terraform state storage
- **Total**: ~$20-30/month (potentially free for 12 months under AWS Free Tier)

## Security Considerations

This setup includes several security measures:
- Encrypted database connections
- Secure WordPress configuration
- AWS security groups for network isolation
- Database password stored as sensitive values
- SSH access with key-based authentication, configurable via the `ssh_access_cidr` Terraform variable to restrict source IPs.

**Production Recommendations:**
- **Restrict SSH access:** Utilize the `ssh_access_cidr` variable in `terraform/variables.tf` to limit SSH access to known IPs.
- Implement HTTPS with SSL/TLS certificates
- Set up AWS Web Application Firewall (WAF)
- Enable database encryption at rest

## Future Improvements

- Multi-availability zone deployment for high availability
- CloudFront integration for content delivery
- Automated database backups to S3
- Monitoring and alerting with CloudWatch
- Auto Scaling for handling traffic spikes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- WordPress and WooCommerce communities
- Terraform and Ansible documentation
- AWS Architecture Center

## Lessons Learned

- Optimized Ansible playbook for idempotency, ensuring reliable deployments
- Implemented GitOps workflow for version-controlled infrastructure
- Balanced cost optimization with performance for small business use cases