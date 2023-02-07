locals {
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  cluster_name   = data.terraform_remote_state.vpc.outputs.cluster_name
  tags           = data.terraform_remote_state.vpc.outputs.vpc_tags
  ami_id         = data.aws_ami.rhel9.image_id

  private_key = var.private_key
  public_key  = var.public_key

  instance_type = "t3a.large"
  ebs_mappings = {
    "encrypted" = true,
    "size"      = 30
  }
}

data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["219670896067"] # owner is specific to aws gov cloud

  filter {
    name   = "name"
    values = ["RHEL-9*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

}

resource "local_file" "ssh_pem" {
  filename        = "${local.cluster_name}.pem"
  content         = local.private_key
  file_permission = "0600"
}

module "rke2" {
  source = "git::https://github.com/shebashio/terraform-aws-rke.git?ref=v2.0.1"

  cluster_name  = local.cluster_name
  unique_suffix = false
  vpc_id        = local.vpc_id
  subnets       = local.public_subnets

  ami                   = local.ami_id
  ssh_authorized_keys   = [local.public_key]
  instance_type         = "t3a.large"
  controlplane_internal = false # note this defaults to best practice of true, but is explicitly set to public for demo purposes
  servers               = 1
  # rke2_version          = "v1.26.0+rke2r1"
  enable_ccm            = true
  block_device_mappings = local.ebs_mappings

  rke2_config = <<-eot
node-label:
  - "name=server"
  - "os=rhel9"
eot

  tags = local.tags

}

#
# Generic agent pool
#
module "agents" {
  source = "git::https://github.com/shebashio/terraform-aws-rke.git//modules/agent-nodepool?ref=v2.0.1"

  name    = "generic"
  vpc_id  = local.vpc_id
  subnets = local.public_subnets # Note: Public subnets used for demo purposes, this is not recommended in production

  ami                 = local.ami_id # Note: Multi OS is primarily for example purposes
  ssh_authorized_keys = [local.public_key]
  spot                = false
  # rke2_version        = "v1.26.0+rke2r1"

  asg = {
    min     = 1,
    max     = 10,
    desired = 3
  }

  instance_type         = local.instance_type
  block_device_mappings = local.ebs_mappings

  # Enable AWS Cloud Controller Manager and Cluster Autoscaler
  enable_ccm        = true
  enable_autoscaler = true

  rke2_config = <<-EOT
node-label:
  - "name=generic"
  - "os=rhel9"
EOT

  cluster_data = module.rke2.cluster_data
  tags         = local.tags

}

# For demonstration only, lock down ssh access in production
resource "aws_security_group_rule" "quickstart_ssh" {
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = module.rke2.cluster_data.cluster_sg
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}