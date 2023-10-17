terraform {
  required_version = "~> 1.5.7"
  # Point to terraform enterprise server

  backend "remote" {
    organization = "demo-land"
    workspaces {
      name = "aws-rke2"
    }
  }
}
