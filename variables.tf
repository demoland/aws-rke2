variable "region" {
  description = "AWS region"
  default     = "us-east-2"
}

variable "public_key" {
  description = "SSH public key"
  sensitive   = true
}

variable "subnet_prefix" {
  description = "value of the subnet prefix, Example: 10.88"
  default     = "10.88"
}

variable "instance_type" {
  description = "AWS instance type"
  default     = "t3.large"
}