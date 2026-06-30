# Architecture Deep Dive

## Why App of Apps?

The App of Apps pattern means a single root ArgoCD Application watches
`gitops/apps/`, which contains more Application CRDs — one per workload.
One `kubectl apply` bootstraps everything. Adding an app = adding a YAML file.

## Namespace-per-Environment

Each environment lives in its own namespace for hard isolation, easy teardown,
and per-environment resource visibility via Prometheus labels.

## Kustomize Base/Overlay

```
gitops/base/podinfo/     <- canonical manifests
gitops/overlays/main/    <- 2 replicas, main labels
gitops/overlays/preview/ <- 1 replica, namespace injected by CI
```

## Preview Lifecycle

PR open   -> GH Actions creates ArgoCD Application pointing to PR branch
PR update -> ArgoCD auto-syncs new version
PR close  -> GH Actions deletes Application (finalizer prunes pods) + namespace
