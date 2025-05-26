variable "aws_region" {
  description = "The AWS region to deploy the resources in"
  type        = string
  default     = "ap-southeast-2"
}

variable "instance_type" {
  description = "The type of EC2 instance to use"
  type        = string
  default     = "t2.micro"
}

variable "db_name" {
  description = "The name of the database"
  type        = string
  default     = "mydb"
}

variable "db_username" {
  description = "The username for the database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "The password for the database"
  type        = string
  default     = "password"
  sensitive   = true
}

variable "ssh_access_cidr" {
  description = "CIDR block allowed for SSH access to the EC2 instance. It is recommended to restrict this to your IP address."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Defaulting to open for now, but user should be warned.
}

variable "ec2_key_name" {
  description = "The name of the EC2 key pair to use for SSH access to the instance."
  type        = string
  # No default, as this is environment-specific and critical for access.
  # Alternatively, could default to "woocommerce-key" if a process for ensuring its existence is established.
}

variable "rds_skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted."
  type        = bool
  default     = false # Production recommendation: false
}

variable "rds_multi_az" {
  description = "Specifies if the RDS instance is multi-AZ."
  type        = bool
  default     = false # Default to false (single-AZ) to keep costs lower for non-production. Can be overridden for production.
}