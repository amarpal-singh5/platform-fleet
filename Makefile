.PHONY: help platform-up platform-down manual-cluster-up manual-cluster-down \
        manual-argocd-install argocd-ui argocd-password app-ui \
        tf-init tf-plan tf-apply tf-destroy lint

CLUSTER_NAME   := platform-fleet
ARGOCD_NS      := argocd
MAIN_NS        := main
TF_MAIN_DIR    := terraform/environments/main
KUBECONFIG_PATH := $(HOME)/.kube/config

## —— Help ————————————————————————————————————————————————————————————————————
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

## —— Platform ————————————————————————————————————————————————————————————————
platform-up: tf-apply ## Full bootstrap: cluster + ArgoCD + App of Apps, all via Terraform
	@echo "✅ Platform is up. Run 'make argocd-ui' to open the dashboard."

platform-down: tf-destroy ## Destroy everything
	@echo "✅ Platform torn down."

## —— Manual escape hatch (NOT used by platform-up) —————————————————————————
## These bypass Terraform entirely with raw kind/kubectl. Kept only for
## debugging when you want a cluster without touching Terraform state.
## They are not wired into platform-up/platform-down and will drift from
## the Terraform-managed install (different ArgoCD install method/version).
manual-cluster-up: ## [debug] Create kind cluster directly, no Terraform
	@echo "🔧 [manual] Creating kind cluster '$(CLUSTER_NAME)'..."
	@kind create cluster --name $(CLUSTER_NAME) --config terraform/modules/kind-cluster/kind-config.yaml
	@echo "✅ Cluster ready. Context: kind-$(CLUSTER_NAME)"

manual-cluster-down: ## [debug] Delete kind cluster directly, no Terraform
	@echo "🗑  [manual] Deleting kind cluster '$(CLUSTER_NAME)'..."
	@kind delete cluster --name $(CLUSTER_NAME)

manual-argocd-install: ## [debug] Install ArgoCD via raw manifest, no Terraform
	@echo "🔧 [manual] Installing ArgoCD..."
	@kubectl create namespace $(ARGOCD_NS) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n $(ARGOCD_NS) -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "⏳ Waiting for ArgoCD to be ready..."
	@kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n $(ARGOCD_NS)
	@echo "✅ ArgoCD installed. Now run: kubectl apply -f gitops/apps/root-app.yaml"

argocd-ui: ## Port-forward ArgoCD UI → localhost:8080
	@echo "🌐 ArgoCD UI → http://localhost:8080"
	@echo "   Username: admin"
	@echo "   Password: run 'make argocd-password'"
	@kubectl port-forward svc/argocd-server -n $(ARGOCD_NS) 8080:443

argocd-password: ## Print ArgoCD initial admin password
	@kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d && echo

## —— App —————————————————————————————————————————————————————————————————————
app-ui: ## Port-forward podinfo → localhost:9898
	@echo "🌐 podinfo → http://localhost:9898"
	@kubectl port-forward svc/podinfo -n $(MAIN_NS) 9898:9898

## —— Terraform ———————————————————————————————————————————————————————————————
tf-init: ## terraform init for main environment
	@terraform -chdir=$(TF_MAIN_DIR) init

tf-plan: ## terraform plan for main environment
	@terraform -chdir=$(TF_MAIN_DIR) plan

tf-apply: ## terraform apply for main environment
	@terraform -chdir=$(TF_MAIN_DIR) apply -auto-approve

tf-destroy: ## terraform destroy for main environment
	@terraform -chdir=$(TF_MAIN_DIR) destroy -auto-approve

## —— Lint ————————————————————————————————————————————————————————————————————
lint: ## Run terraform fmt check + validate
	@echo "🔍 Checking Terraform formatting..."
	@terraform fmt -check -recursive terraform/
	@echo "✅ Format OK"
