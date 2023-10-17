locals {
  cluster_name = "hashi-k8s"
  aws_region   = "us-east-2"

  tags = {
    "terraform" = "true",
    "env"       = "cloud-enabled",
  }
}

data "aws_ami" "rhel8" {
  most_recent = true
  owners      = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-8*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# Key Pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_pem" {
  filename        = "${local.cluster_name}.pem"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "0600"
}

#
# Network
#
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "rke2-${local.cluster_name}"
  cidr = "${var.subnet_prefix}.0.0/16"

  azs             = ["${local.aws_region}a", "${local.aws_region}b", "${local.aws_region}c"]
  public_subnets  = ["${var.subnet_prefix}.1.0/24", "${var.subnet_prefix}.2.0/24", "${var.subnet_prefix}.3.0/24"]
  private_subnets = ["${var.subnet_prefix}.101.0/24", "${var.subnet_prefix}.102.0/24", "${var.subnet_prefix}.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_vpn_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Add in required tags for proper AWS CCM integration
  public_subnet_tags = merge({
    "kubernetes.io/cluster/${module.rke2.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                            = "1"
  }, local.tags)

  private_subnet_tags = merge({
    "kubernetes.io/cluster/${module.rke2.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"                   = "1"
  }, local.tags)

  tags = merge({
    "kubernetes.io/cluster/${module.rke2.cluster_name}" = "shared"
  }, local.tags)
}

#
# Server
#
module "rke2" {
  source = "git::https://github.com/demoland/rke2-aws-tf"

  cluster_name                = local.cluster_name
  vpc_id                      = module.vpc.vpc_id
  subnets                     = module.vpc.public_subnets # Note: Public subnets used for demo purposes, this is not recommended in production
  associate_public_ip_address = true

  ami                   = data.aws_ami.rhel8.image_id # Note: Multi OS is primarily for example purposes
  ssh_authorized_keys   = [tls_private_key.ssh.public_key_openssh]
  instance_type         = var.instance_type
  controlplane_internal = false # Note this defaults to best practice of true, but is explicitly set to public for demo purposes
  servers               = 2
  rke2_start            = true

  # Enable AWS Cloud Controller Manager
  enable_ccm = true

  rke2_config = <<-EOT
node-label:
  - "name=server"
  - "os=rhel8"
EOT

  tags = local.tags
}

#
# Generic agent pool
#
module "agents" {
  source = "git::https://github.com/demoland/rke2-aws-tf//modules/agent-nodepool"

  name    = "generic"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets # Note: Public subnets used for demo purposes, this is not recommended in production

  ami                       = data.aws_ami.rhel8.image_id # Note: Multi OS is primarily for example purposes
  ssh_authorized_keys       = [tls_private_key.ssh.public_key_openssh]
  spot                      = false
  asg                       = { min : 2, max : 10, desired : 2 }
  instance_type             = var.instance_type
  wait_for_capacity_timeout = "20m"

  # Enable AWS Cloud Controller Manager and Cluster Autoscaler
  enable_ccm        = true
  enable_autoscaler = true

  rke2_config = <<-EOT
node-label:
  - "name=generic"
  - "os=rhel8"
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

# Generic outputs as examples
output "rke2" {
  value = module.rke2
}

# Example method of fetching kubeconfig from state store, requires aws cli and bash locally
resource "null_resource" "kubeconfig" {
  depends_on = [module.rke2]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "aws s3 cp ${module.rke2.kubeconfig_path} rke2.yaml"
  }
}
