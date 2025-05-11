output "ec2_public_ip" {
  value = aws_instance.woocommerce.public_ip
  description = "The public IP address of the WooCommerce EC2 instance"
}

output "rds_endpoint" {
  value = aws_db_instance.woocommerce_db.endpoint
  description = "The connection endpoint for the WooCommerce database"
}