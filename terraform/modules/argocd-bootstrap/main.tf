terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

data "kubectl_path_documents" "root_app" {
  pattern = "${path.module}/../../../gitops/apps/root-app.yaml"
}

resource "kubectl_manifest" "root_app" {
  for_each   = toset(data.kubectl_path_documents.root_app.documents)
  yaml_body  = each.value
  depends_on = [var.argocd_ready]
}

resource "null_resource" "strip_app_finalizers_on_destroy" {
  triggers = {
    namespace    = var.argocd_namespace
    argocd_ready = var.argocd_ready
  }

  depends_on = [kubectl_manifest.root_app]

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      NS="${self.triggers.namespace}"

      echo "Deleting ApplicationSets in $NS (stops further Application regeneration)..."
      kubectl delete applicationsets --all -n "$NS" --wait=true --timeout=60s 2>/dev/null || true

      echo "Attempting graceful delete of Applications in $NS..."
      kubectl delete applications --all -n "$NS" --wait=true --timeout=60s 2>/dev/null || true

      echo "Force-clearing finalizers from any remaining Applications in $NS..."
      kubectl get applications -n "$NS" -o name 2>/dev/null | \
        xargs -I{} kubectl patch {} -n "$NS" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    EOT
  }
}
