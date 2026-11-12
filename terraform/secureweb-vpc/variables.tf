variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "admin_cidr" {
  description = "Your public IP as a /32, e.g. 203.0.113.10/32"
  type        = string
}
