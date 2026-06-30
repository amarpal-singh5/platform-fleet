#!/usr/bin/env bash
# First-time setup: checks prereqs, creates cluster, installs ArgoCD, bootstraps apps.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_prereq() {
  command -v "$1" &>/dev/null || error "$1 is not installed. See README Prerequisites."
  info "$1 ✓"
}

info "Checking prerequisites..."
for tool in docker kind kubectl terraform helm; do check_prereq "$tool"; done

info "Creating kind cluster..."
kind create cluster --name platform-fleet --config terraform/modules/kind-cluster/kind-config.yaml

info "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

info "Waiting for ArgoCD server (up to 2 min)..."
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd

info "Bootstrapping App of Apps..."
kubectl apply -f gitops/apps/root-app.yaml

PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ""
info "Platform is up!"
echo "  ArgoCD → make argocd-ui  |  http://localhost:8080  |  admin / ${PASS}"
echo "  App    → make app-ui     |  http://localhost:9898"
