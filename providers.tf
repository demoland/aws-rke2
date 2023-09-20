terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.17.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Owner       = "Daniel Fedick"
      Purpose     = "AWS RKE2 DEMOLAND"
      Terraform   = true
      Environment = "development"
      DoNotDelete = true
      Name        = "DEMOLAND RKE2"
    }
  }
}
