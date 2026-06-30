output "cluster_name" {
  value = module.kind_cluster.cluster_name
}

output "argocd_namespace" {
  value = module.argocd.namespace
}
