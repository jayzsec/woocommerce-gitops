# WooCommerce GitOps Pipeline

This project automates the deployment of a WooCommerce store on AWS using Terraform, Ansible, and GitHub Actions. Designed for a small business, it provisions a cost-effective EC2 instance and RDS database, and deploys WordPress with WooCommerce. The pipeline showcases DevOps best practices, including IaC, GitOps, and CI/CD.

## Architecture
![Architecture Diagram](architecture.png)

## Setup
1. Clone the repository.
2. Configure AWS credentials and GitHub Secrets.
3. Push to `main` to trigger provisioning and deployment.

## Cost Analysis
- EC2 (t2.micro): ~$10/month (free tier eligible)
- RDS (db.t3.micro): ~$10/month (free tier eligible)
- Total: ~$20/month

## Lessons Learned
- Optimized Ansible playbook for idempotency, ensuring reliable deployments.