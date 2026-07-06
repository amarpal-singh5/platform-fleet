#!/usr/bin/env bash
set -euo pipefail
TF_MAIN_DIR="terraform/environments/main"

echo "This will terraform destroy everything in ${TF_MAIN_DIR} (cluster, ArgoCD, apps)."
read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

terraform -chdir="$TF_MAIN_DIR" destroy -auto-approve
echo "Torn down."
