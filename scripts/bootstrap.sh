#!/usr/bin/env bash
# First-time setup: checks prereqs, then delegates the actual cluster +
# ArgoCD + App of Apps bootstrap entirely to Terraform (terraform/environments/main).
# This is the ONLY supported path - it is not a parallel implementation of
# what Terraform does, it just calls Terraform and prints friendly output.
set -euo pipefail

TF_MAIN_DIR="terraform/environments/main"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_prereq() {
  command -v "$1" &>/dev/null || error "$1 is not installed. See README Prerequisites."
  info "$1 ✓"
}

info "Checking prerequisites..."
for tool in docker kind kubectl terraform helm; do check_prereq "$tool"; done

info "Running terraform init (if needed)..."
terraform -chdir="$TF_MAIN_DIR" init -input=false

info "Running terraform apply (cluster + ArgoCD + App of Apps)..."
terraform -chdir="$TF_MAIN_DIR" apply -auto-approve

ARGOCD_NS=$(terraform -chdir="$TF_MAIN_DIR" output -raw argocd_namespace)
PASS=$(kubectl -n "$ARGOCD_NS" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
info "Platform is up!"
echo "  ArgoCD → make argocd-ui  |  http://localhost:8080  |  admin / ${PASS}"
echo "  App    → make app-ui     |  http://localhost:9898"
