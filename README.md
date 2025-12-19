# homelab-cluster

GitOps repository for my k3s homelab cluster using ArgoCD with the App of Apps pattern.

## Deployed Applications

| Application | Description | Local Access | Tailscale Access |
|-------------|-------------|--------------|------------------|
| **ArgoCD** | GitOps continuous delivery | [argocd.homelab](http://argocd.homelab) | argocd.\<tailnet\>.ts.net |
| **Grafana** | Dashboards & visualization | [grafana.homelab](http://grafana.homelab) | grafana.\<tailnet\>.ts.net |
| **Prometheus** | Metrics collection | [prometheus.homelab](http://prometheus.homelab) | prometheus.\<tailnet\>.ts.net |
| **Loki** | Log aggregation | - (query via Grafana) | - |
| **Alloy** | Log collector (DaemonSet) | - | - |
| **Miniflux** | RSS reader | [miniflux.homelab](http://miniflux.homelab) | miniflux.\<tailnet\>.ts.net |
| **Sealed Secrets** | Encrypt secrets for Git | - | - |
| **CloudNativePG** | PostgreSQL operator | - | - |
| **[Tailscale Operator](apps/tailscale/README.md)** | Remote access via tailnet | - | - |

## Accessing Services

### Option 1: Local Access (via /etc/hosts)

Add these entries to your `/etc/hosts` file, replacing `<CLUSTER_IP>` with your k3s node IP:

```
<CLUSTER_IP>  argocd.homelab
<CLUSTER_IP>  grafana.homelab
<CLUSTER_IP>  prometheus.homelab
<CLUSTER_IP>  miniflux.homelab
```

### Option 2: Remote Access (via Tailscale)

Services are accessible from any device on your tailnet at `<service>.<tailnet>.ts.net` with automatic HTTPS.

Requires:
- Tailscale operator deployed with valid OAuth credentials (see [setup instructions](apps/tailscale/README.md))
- HTTPS and MagicDNS enabled in Tailscale admin console

## Prerequisites

- k3s cluster running with Traefik ingress
- [Nix](https://nixos.org/download/) with flakes enabled - run `nix develop` to get all required tools (kubectl, kubeseal, helm, etc.)
- (Optional) Tailscale account for remote access

## Repository Structure

```
.
├── bootstrap/
│   └── argocd/           # ArgoCD installation manifests
├── apps/                 # Application manifests (App of Apps)
│   └── argocd.yaml       # ArgoCD self-management
└── root-app.yaml         # Root Application (App of Apps entry point)
```

## Bootstrap from Scratch

### 1. Create the ArgoCD namespace and install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -k bootstrap/argocd/
```

### 2. Wait for ArgoCD to be ready

```bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

### 3. Get the initial admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 4. Deploy the App of Apps

```bash
kubectl apply -f root-app.yaml
```

ArgoCD will now:
- Sync the `apps/` directory
- Pick up `apps/argocd.yaml` and start managing its own installation
- Automatically deploy any new applications you add to `apps/`

### 5. Access the ArgoCD UI

Add to your `/etc/hosts` (on your local machine):
```
<CLUSTER_IP>  argocd.homelab
```

Then visit: http://argocd.homelab

Login with:
- Username: `admin`
- Password: (from step 3)

## How App of Apps Works

```
root-app.yaml
    │
    └── watches: apps/
            │
            ├── argocd.yaml ──────► bootstrap/argocd/ (self-manages ArgoCD)
            ├── my-app.yaml ──────► apps/my-app/      (your future apps)
            └── ...
```

The `root` Application watches the `apps/` directory. Any Application manifest you add there will be automatically picked up and deployed.

## Adding New Applications

1. Create your application manifests in a new directory (e.g., `apps/my-app/` or `workloads/my-app/`)

2. Create an Application manifest in `apps/`:

```yaml
# apps/my-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/AbelMeijberg/homelab-cluster.git
    targetRevision: main
    path: workloads/my-app  # or wherever your manifests are
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app  # target namespace for deployment
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

3. Commit and push - ArgoCD will automatically sync and deploy your app.

## Useful Commands

```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Force sync an application
kubectl patch application root -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Delete the initial admin secret after changing password
kubectl delete secret argocd-initial-admin-secret -n argocd
```
