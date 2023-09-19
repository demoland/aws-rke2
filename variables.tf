variable "region" {
  description = "AWS region"
  default     = "us-east-2"
}

variable "public_key" {
  description = "SSH public key"
  sensitive   = true
}
