output "cluster_name" {
  value = module.rke2.cluster_name
}

output "cluster_sg" {
  value = module.rke2.cluster_sg
}

output "server_url" {
  value = module.rke2.server_url
}

output "kubeconfig_path" {
  value = module.rke2.kubeconfig_path
}

output "kubeconfig_path" {
  value = "aws s3 cp ${module.rke2.kubeconfig_path} ~/.kube/config"
}