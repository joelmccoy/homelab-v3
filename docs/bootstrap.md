# Cluster bring-up from scratch

```bash
mise install
mise run hk-install
cp tofu/example.tfvars tofu/terraform.tfvars     # fill in tokens
mise run tf-apply                                 # cluster + cf tunnel + tokens
tofu -chdir=tofu output -raw kubeconfig > kubeconfig && chmod 600 kubeconfig

# CNI (required before any pod schedules)
helm repo add cilium https://helm.cilium.io/ && helm repo update cilium
helm upgrade --install cilium cilium/cilium --version <pin> -n kube-system -f k8s/apps/cilium/values.yaml --wait

# GitOps controller
helm repo add argo https://argoproj.github.io/argo-helm && helm repo update argo
helm upgrade --install argo-cd argo/argo-cd --version <pin> -n argocd --create-namespace -f k8s/apps/argo-cd/values.yaml --wait

# ArgoCD takes over from here
kubectl apply -f k8s/apps/_apps.yaml
```

Chart versions match what each `k8s/apps/<app>/application.yaml` pins. After `_apps.yaml` is applied, ArgoCD adopts the existing Cilium and ArgoCD helm releases (matching `releaseName` + namespace) and reconciles every other app under `k8s/apps/`.
