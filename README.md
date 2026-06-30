# platform-fleet

A production-pattern platform engineering project demonstrating always-on, self-service Kubernetes environments using GitOps, Infrastructure as Code, and preview environments per pull request.

Built to mirror the architecture patterns used in real-world platform engineering roles — specifically around fleet management, environment reproducibility, and developer experience.

---

## Architecture

```
GitHub PR → GitHub Actions CI
                ↓
          Terraform (kind provider)
          provisions local cluster
                ↓
          ArgoCD (GitOps engine)
          deploys App of Apps
                ↓
     ┌──────────────────────────┐
     │                          │
  main ns                  preview-{pr} ns
  (always-on)              (per PR, auto-destroy on merge)
     │                          │
  podinfo app              podinfo app (branch version)
  prometheus/grafana
```

**Core Principles:**
- `terraform apply` = full cluster with GitOps engine, zero manual steps
- ArgoCD App of Apps pattern — all environments declared as code
- Per-PR preview namespaces with automatic teardown
- `make` targets as the self-service interface for engineers

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker | 20.10+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| kind | 0.20+ | `brew install kind` |
| kubectl | 1.28+ | `brew install kubectl` |
| Terraform | 1.6+ | `brew install terraform` |
| Helm | 3.12+ | `brew install helm` |
| argocd CLI | 2.9+ | `brew install argocd` |

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/amarpal-singh5/platform-fleet.git
cd platform-fleet

# 2. Stand up the full platform (cluster + ArgoCD + apps)
make platform-up

# 3. Open ArgoCD UI
make argocd-ui

# 4. Open the demo app
make app-ui

# 5. Tear everything down
make platform-down
```

---

## Project Structure

```
platform-fleet/
├── terraform/
│   ├── environments/
│   │   ├── main/          # Always-on environment (Terraform root)
│   │   └── preview/       # Preview env template (instantiated per PR)
│   └── modules/
│       ├── kind-cluster/  # Reusable kind cluster module
│       ├── argocd/        # ArgoCD install via Helm provider
│       └── monitoring/    # Prometheus + Grafana stack
├── gitops/
│   ├── apps/              # ArgoCD App of Apps definitions
│   ├── base/              # Kustomize base manifests
│   │   ├── podinfo/       # Sample demo app
│   │   └── namespaces/    # Namespace definitions
│   └── overlays/
│       ├── main/          # Main environment overlay
│       └── preview/       # Preview environment overlay template
├── .github/
│   └── workflows/
│       ├── ci.yaml        # PR validation pipeline
│       └── preview.yaml   # Preview environment lifecycle
├── scripts/
│   ├── bootstrap.sh       # First-time cluster bootstrap helper
│   └── teardown.sh        # Clean teardown helper
├── docs/
│   └── architecture.md    # Deep dive on design decisions
└── Makefile               # Self-service interface
```

---

## Environments

### Main (Always-On)
- Namespace: `main`
- Purpose: Stakeholder demos, internal dogfooding, UX validation
- Deployed via: ArgoCD watching `gitops/overlays/main`
- Auto-syncs on every merge to `main` branch

### Preview (Per Pull Request)
- Namespace: `preview-{pr-number}`
- Purpose: Feature branch validation, rapid UX feedback
- Lifecycle: Created on PR open → destroyed on PR merge/close
- URL posted as PR comment by GitHub Actions

---

## Makefile Targets

```bash
make platform-up       # Full bootstrap: cluster + ArgoCD + apps
make platform-down     # Destroy everything

make cluster-up        # kind cluster only
make cluster-down      # Delete kind cluster

make argocd-install    # Install ArgoCD into existing cluster
make argocd-ui         # Port-forward ArgoCD UI → localhost:8080
make argocd-password   # Print initial admin password

make app-ui            # Port-forward podinfo → localhost:9898
make tf-init           # terraform init for main environment
make tf-plan           # terraform plan for main environment
make tf-apply          # terraform apply for main environment

make lint              # Run terraform fmt + validate
make docs              # Generate docs from terraform modules
```

---

## GitOps Pattern: App of Apps

ArgoCD is configured with a single root `Application` that points to `gitops/apps/`. That directory contains `Application` CRDs for every other app — podinfo, monitoring, and namespace definitions. This means:

1. ArgoCD is installed once by Terraform
2. A single `kubectl apply` of the root app bootstraps everything else
3. All future changes go through Git — no `kubectl apply` in production

---

## Skills Demonstrated

| Skill | Where |
|-------|-------|
| Kubernetes | kind cluster, all workloads |
| Infrastructure as Code | `terraform/` — cluster, ArgoCD, monitoring |
| GitOps | ArgoCD App of Apps, auto-sync |
| CI/CD | `.github/workflows/` — lint, validate, preview lifecycle |
| Helm | ArgoCD install, kube-prometheus-stack |
| Kustomize | `gitops/base/` + `gitops/overlays/` |
| Multi-tenant environments | Namespace-isolated main + preview envs |
| Developer Experience | Makefile self-service, one-command bootstrap |
| Observability | Prometheus + Grafana (Sprint 5) |
| Linux | Shell scripts, container runtime |

---

## Roadmap

- [x] Sprint 1: Repo scaffold + architecture
- [ ] Sprint 2: Terraform kind cluster + ArgoCD install
- [ ] Sprint 3: App of Apps — podinfo on main
- [ ] Sprint 4: Preview environments via GitHub Actions
- [ ] Sprint 5: Prometheus + Grafana observability
- [ ] Sprint 6: Polish, one-liner demo, LinkedIn writeup
