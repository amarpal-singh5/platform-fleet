output "applied_manifests" {
  description = "Keys of the manifest documents applied from root-app.yaml"
  value       = keys(kubectl_manifest.root_app)
}
