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
```

## Architecture

### App of Apps Pattern

```
root-app.yaml (entry point - watches apps/ directory)
    │
    └── apps/
        ├── argocd.yaml          → bootstrap/argocd/ (self-manages ArgoCD)
        ├── homepage.yaml        → Helm chart with apps/homepage/values.yaml
        └── kube-prometheus-stack.yaml → Helm chart with apps/kube-prometheus-stack/values.yaml
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

All require `/etc/hosts` entries pointing to cluster IP:
- `argocd.homelab` - ArgoCD UI
- `grafana.homelab` - Grafana dashboards
- `homepage.homelab` - Homelab dashboard
- `prometheus.homelab` - Prometheus UI

## Technology Stack

- **k3s**: Lightweight Kubernetes with built-in Traefik ingress
- **ArgoCD**: GitOps continuous delivery
- **Kustomize**: Used for ArgoCD bootstrap
- **Helm**: Used for application deployments via ArgoCD

## Maintaining This File

Update this CLAUDE.md file after adding new features or applications to keep it current with the repository state.
