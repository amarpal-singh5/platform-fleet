variable "argocd_ready" {
  description = <<-EOT
    Not used for its value - only referenced by kubectl_manifest.root_app's
    depends_on so that resource (not the whole module, not the data source)
    waits for ArgoCD's Helm release to exist first. Pass something like
    module.argocd.release_name from the caller.
  EOT
  type        = any
}

variable "argocd_namespace" {
  description = <<-EOT
    ArgoCD's namespace name. Pass module.argocd.namespace from the caller.
    Used to scope the destroy-time Application finalizer cleanup, and the
    reference itself is what creates the correct destroy-order dependency
    on module.argocd's namespace resource (see null_resource in main.tf).
  EOT
  type        = string
}
