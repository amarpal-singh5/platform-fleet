terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Applies the repo's own gitops/apps/root-app.yaml so there is exactly one
# place that defines the App of Apps, not a second copy re-declared in HCL.
# root-app.yaml itself then points ArgoCD at gitops/apps/, which is what
# actually drives podinfo, namespaces, etc. via GitOps sync.
data "kubectl_path_documents" "root_app" {
  pattern = "${path.module}/../../../gitops/apps/root-app.yaml"
}

resource "kubectl_manifest" "root_app" {
  for_each  = toset(data.kubectl_path_documents.root_app.documents)
  yaml_body = each.value

  # This is the ONLY thing in this module that actually needs to wait for
  # ArgoCD (the CRD comes from module.argocd's Helm release). Putting the
  # dependency here instead of on the whole module means the data source
  # above stays evaluable at plan time - it just reads a local file and
  # has no real dependency on the cluster.
  depends_on = [var.argocd_ready]
}
