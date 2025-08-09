variable "project_prefix" {
  description = "Short name used to prefix resource names (must be lowercase/dns-friendly)"
  type        = string
  default     = "prog8870"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "enable_s3_versioning" {
  description = "Enable versioning for all S3 buckets"
  type        = bool
  default     = true
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami_id" {
  description = "AMI ID for EC2 (e.g., Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  sensitive   = true
  default     = "adminuser"
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}
