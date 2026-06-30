#!/usr/bin/env bash
set -euo pipefail
echo "This will delete the kind cluster 'platform-fleet' and all data."
read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
kind delete cluster --name platform-fleet
echo "Cluster deleted."
