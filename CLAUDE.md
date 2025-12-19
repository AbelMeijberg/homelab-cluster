# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This is a learning and experimentation repository for Kubernetes and homelab infrastructure. The goal is to explore GitOps patterns, try out different applications, and gain hands-on experience with k3s, ArgoCD, and related tooling. Approach each new app or feature from this angle. Don't skip opportunities to explain a nice new pattern.

## Common Commands

```bash
# Check application status
kubectl get applications -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Force sync an application
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Check CloudNativePG database clusters
kubectl get clusters --all-namespaces

# View CNPG-generated database credentials
kubectl get secret <cluster-name>-app -n <namespace> -o jsonpath='{.data.uri}' | base64 -d

# Create a sealed secret (encrypt plaintext secret)
kubectl create secret generic <name> -n <namespace> --from-literal=KEY=value --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets --format yaml > sealed-secret.yaml

# Check Tailscale operator status
kubectl get pods -n tailscale
kubectl logs -n tailscale deployment/tailscale-operator

# View Tailscale ingresses
kubectl get ingress -A -l app.kubernetes.io/managed-by=tailscale-operator

# Regenerate Tailscale OAuth sealed secret (see apps/tailscale/README.md for full instructions)
kubectl create secret generic operator-oauth -n tailscale \
  --from-literal=client_id="<ID>" --from-literal=client_secret="<SECRET>" \
  --dry-run=client -o yaml | kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets --format yaml > apps/tailscale/oauth-secret.yaml

# Check Loki status
kubectl get pods -n loki
kubectl logs -n loki deployment/loki

# Check Alloy log collector status
kubectl get pods -n alloy
kubectl logs -n alloy daemonset/alloy-alloy

# Query logs in Grafana (or use LogCLI)
# Go to Grafana -> Explore -> Select "Loki" -> Query: {namespace="argocd"}
```

## Architecture

### App of Apps Pattern

```
root-app.yaml (entry point - watches apps/ directory)
    │
    └── apps/
        ├── argocd.yaml              → bootstrap/argocd/ (self-manages ArgoCD)
        ├── sealed-secrets.yaml      → Helm chart (encrypts secrets for GitOps)
        ├── cloudnative-pg.yaml      → Helm chart (PostgreSQL operator)
        ├── kube-prometheus-stack.yaml → Helm chart with apps/kube-prometheus-stack/values.yaml
        ├── loki.yaml                → Helm chart (log aggregation backend)
        ├── alloy.yaml               → Helm chart (log collector DaemonSet)
        ├── miniflux.yaml            → Helm chart + CNPG database (RSS reader)
        ├── tailscale.yaml           → Helm chart (Tailscale operator for remote access)
        └── tailscale-ingresses.yaml → Ingress resources for Tailscale
```

- **root-app.yaml**: Entry point that watches `apps/` directory for Application manifests
- **apps/*.yaml**: ArgoCD Application resources defining what to deploy
- **apps/<name>/values.yaml**: Helm value overrides for each application
- **bootstrap/argocd/**: Kustomize overlay for ArgoCD installation

### Adding New Applications

1. Create `apps/<app-name>.yaml` with ArgoCD Application manifest
2. For Helm charts with custom values, use the multi-source pattern:
   ```yaml
   sources:
     - repoURL: <helm-repo-url>
       chart: <chart-name>
       targetRevision: <version>
       helm:
         valueFiles:
           - $values/apps/<app-name>/values.yaml
     - repoURL: https://github.com/AbelMeijberg/homelab-cluster.git
       targetRevision: main
       ref: values
   ```
3. Create `apps/<app-name>/values.yaml` with Helm overrides
4. Commit and push - ArgoCD auto-discovers and deploys

### Key Hostnames

**Local access** (requires `/etc/hosts` entries pointing to cluster IP):
- `argocd.homelab` - ArgoCD UI
- `grafana.homelab` - Grafana dashboards
- `prometheus.homelab` - Prometheus UI
- `miniflux.homelab` - Miniflux RSS reader

**Remote access via Tailscale** (accessible from any tailnet device):
- `argocd.<tailnet>.ts.net` - ArgoCD UI
- `grafana.<tailnet>.ts.net` - Grafana dashboards
- `prometheus.<tailnet>.ts.net` - Prometheus UI
- `miniflux.<tailnet>.ts.net` - Miniflux RSS reader

## Technology Stack

- **k3s**: Lightweight Kubernetes with built-in Traefik ingress
- **ArgoCD**: GitOps continuous delivery
- **Kustomize**: Used for ArgoCD bootstrap
- **Helm**: Used for application deployments via ArgoCD
- **Sealed Secrets**: Encrypt secrets so they can be safely committed to Git
- **CloudNativePG**: Kubernetes operator for managing PostgreSQL databases
- **Tailscale Operator**: Enables remote access to services via Tailscale network
- **Loki**: Log aggregation backend (monolithic mode with local filesystem storage)
- **Alloy**: Log collector agent (DaemonSet, collects pod logs via Kubernetes API)

## Maintaining Documentation

After adding new features or applications, update:

1. **CLAUDE.md** - This file (architecture diagrams, commands, technology stack)
2. **README.md** - The "Deployed Applications" table and /etc/hosts entries
