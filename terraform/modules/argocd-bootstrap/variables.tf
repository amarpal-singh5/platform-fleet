variable "argocd_ready" {
  description = <<-EOT
    Not used for its value - only referenced by kubectl_manifest.root_app's
    depends_on so that resource (not the whole module, not the data source)
    waits for ArgoCD's Helm release to exist first. Pass something like
    module.argocd.release_name from the caller.
  EOT
  type = any
}
