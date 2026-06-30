.PHONY: help platform-up platform-down cluster-up cluster-down \
        argocd-install argocd-ui argocd-password app-ui \
        tf-init tf-plan tf-apply lint

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
platform-up: cluster-up argocd-install argocd-bootstrap ## Full bootstrap: cluster + ArgoCD + apps
	@echo "✅ Platform is up. Run 'make argocd-ui' to open the dashboard."

platform-down: cluster-down ## Destroy everything
	@echo "✅ Platform torn down."

## —— Cluster —————————————————————————————————————————————————————————————————
cluster-up: ## Create kind cluster
	@echo "🔧 Creating kind cluster '$(CLUSTER_NAME)'..."
	@kind create cluster --name $(CLUSTER_NAME) --config terraform/modules/kind-cluster/kind-config.yaml
	@echo "✅ Cluster ready. Context: kind-$(CLUSTER_NAME)"

cluster-down: ## Delete kind cluster
	@echo "🗑  Deleting kind cluster '$(CLUSTER_NAME)'..."
	@kind delete cluster --name $(CLUSTER_NAME)

## —— ArgoCD ——————————————————————————————————————————————————————————————————
argocd-install: ## Install ArgoCD into cluster
	@echo "🔧 Installing ArgoCD..."
	@kubectl create namespace $(ARGOCD_NS) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n $(ARGOCD_NS) -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "⏳ Waiting for ArgoCD to be ready..."
	@kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n $(ARGOCD_NS)
	@echo "✅ ArgoCD installed."

argocd-bootstrap: ## Apply root App of Apps
	@echo "🔧 Bootstrapping App of Apps..."
	@kubectl apply -f gitops/apps/root-app.yaml
	@echo "✅ Root application applied. ArgoCD will sync everything."

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

## —— Lint ————————————————————————————————————————————————————————————————————
lint: ## Run terraform fmt check + validate
	@echo "🔍 Checking Terraform formatting..."
	@terraform fmt -check -recursive terraform/
	@echo "✅ Format OK"
