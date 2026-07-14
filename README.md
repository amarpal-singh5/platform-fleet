# platform-fleet

A platform engineering project in active development, building toward always-on, self-service Kubernetes environments using GitOps, Infrastructure as Code, and preview environments per pull request.

Built to mirror the architecture patterns used in real-world platform engineering roles — specifically around fleet management, environment reproducibility, and developer experience. Cluster provisioning, ArgoCD install, and the App of Apps bootstrap are fully Terraform-driven end to end, including clean teardown. Preview environments per PR deploy and tear down automatically via an ArgoCD ApplicationSet — no CI job touches the cluster directly. See Roadmap below for what's built vs. planned.

---

## Architecture

```
GitHub PR opened
      ↓
ArgoCD ApplicationSet (PR generator, polls GitHub directly)
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
  (always-on)              (per open PR, auto-destroy on close)
     │                          │
  podinfo app              podinfo app (PR's exact commit)
  prometheus/grafana
  (planned, Sprint 6)
```

**Core Principles:**
- ArgoCD App of Apps pattern — all environments declared as code
- One bootstrap path: `make platform-up` → `terraform apply` → cluster + ArgoCD (Helm) + root Application, in that order, with matching teardown via `terraform destroy`
- Per-PR preview namespaces via an ArgoCD ApplicationSet (Pull Request generator) — ArgoCD polls GitHub directly and creates/destroys the preview Application itself; no CI job ever touches the cluster
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
│   │   └── preview/       # (planned) — preview env template per PR
│   └── modules/
│       ├── kind-cluster/     # Reusable kind cluster module
│       ├── argocd/           # ArgoCD install via Helm provider
│       ├── argocd-bootstrap/ # Applies root App of Apps + handles destroy-time
│       │                     # cleanup of Application finalizers
│       └── monitoring/       # (planned) — Prometheus + Grafana stack
├── gitops/
│   ├── apps/              # ArgoCD App of Apps definitions + preview ApplicationSet
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
- Lifecycle: an ArgoCD `ApplicationSet` (`gitops/apps/podinfo-preview-appset.yaml`) with a GitHub Pull Request generator polls open PRs directly (every ~3 min) and creates/destroys the preview `Application` itself — this is not GitHub Actions reaching into the cluster, it's ArgoCD (already running on the cluster) reaching out to GitHub. Deploys the exact commit SHA of the PR, so new pushes get picked up automatically.
- `.github/workflows/preview.yaml` only posts a heads-up PR comment — it does no cluster work at all
- **Known gap:** closing a PR correctly removes the `Application` and its workload (confirmed working), but the `preview-{pr}` namespace itself is left behind, empty. ArgoCD's `CreateNamespace=true` sync option creates the namespace but doesn't treat it as a resource it prunes on Application deletion. Not yet automated — for now, stale preview namespaces need a manual `kubectl delete ns preview-{n}` cleanup pass.

---

## Makefile Targets

```bash
make platform-up       # Full bootstrap via Terraform: cluster + ArgoCD + App of Apps
make platform-down     # terraform destroy - tears down everything, incl. Application cleanup

make tf-init           # terraform init for main environment
make tf-plan           # terraform plan for main environment
make tf-apply          # terraform apply for main environment (same as platform-up)
make tf-destroy        # terraform destroy for main environment (same as platform-down)

make argocd-ui         # Port-forward ArgoCD UI → localhost:8080
make argocd-password   # Print initial admin password
make app-ui            # Port-forward podinfo → localhost:9898

make lint              # Run terraform fmt + validate
make docs              # Generate docs from terraform modules

# Debug only - NOT used by platform-up/down, bypasses Terraform entirely
# with raw kind/kubectl. Will drift from the Terraform-managed install
# (different ArgoCD install method/version). Use only for troubleshooting.
make manual-cluster-up       # Create kind cluster directly
make manual-cluster-down     # Delete kind cluster directly
make manual-argocd-install   # Install ArgoCD via raw manifest
```

---

## GitOps Pattern: App of Apps

ArgoCD is configured with a single root `Application` that points to `gitops/apps/`. That directory contains `Application` CRDs for every other app — podinfo, monitoring, and namespace definitions. This means:

1. Terraform provisions the cluster and installs ArgoCD via Helm
2. Terraform applies the root Application from `gitops/apps/root-app.yaml` directly (via `kubectl_manifest`, reading the same YAML file that's checked into the repo — no separate copy re-declared in HCL)
3. ArgoCD takes it from there — all future changes go through Git, no manual `kubectl apply` in this flow
4. On teardown, a destroy-time step strips ArgoCD's finalizers from any Applications in the namespace first (including ones ArgoCD's own controller created, like `podinfo-main`), so `terraform destroy` completes cleanly instead of hanging on a namespace stuck in `Terminating`
5. That same destroy-time step deletes any `ApplicationSet`s before touching Applications — a live ApplicationSet (e.g. the preview-env PR generator) can regenerate an Application with a fresh finalizer faster than a one-time cleanup sweep can catch it, which caused a second, different destroy hang before this was fixed

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
| Linux | Shell scripts, container runtime |

---

## Roadmap

- [x] Sprint 1: Repo scaffold + architecture
- [x] Sprint 2: Terraform kind cluster + ArgoCD install
- [x] Sprint 3: App of Apps — podinfo on main
- [x] Sprint 4: Consolidate onto one Terraform-driven bootstrap path (cluster + ArgoCD + root Application, plus clean destroy-time Application-finalizer handling)
- [x] Sprint 5: Preview environments via ArgoCD ApplicationSet (PR generator) — deploy and auto-teardown on PR close confirmed working end to end; orphaned namespace cleanup still open
- [ ] Sprint 6: Prometheus + Grafana observability
- [ ] Sprint 7: Polish, one-liner demo, LinkedIn writeup
