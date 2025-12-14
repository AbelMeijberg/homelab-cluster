# Tailscale Operator

This directory contains the Tailscale Kubernetes operator configuration for remote access to homelab services via your Tailscale network (tailnet).

## Prerequisites

Before deploying, complete these steps in the Tailscale Admin Console:

1. **Create OAuth Client** (Settings > OAuth clients)
   - Scopes: Devices (read/write), Auth Keys (read/write)
   - Assign tag: `tag:k8s-operator`
   - Save the Client ID and Client Secret

2. **Update ACL Policy** (Access Controls)
   ```json
   {
     "tagOwners": {
       "tag:k8s-operator": [],
       "tag:k8s": ["tag:k8s-operator"]
     }
   }
   ```

3. **Enable HTTPS & MagicDNS** (DNS settings)

## Creating the OAuth Sealed Secret

The operator requires OAuth credentials stored as a Kubernetes secret. We use Sealed Secrets to encrypt them for safe storage in Git.

### Generate the Sealed Secret

Replace `<YOUR_CLIENT_ID>` and `<YOUR_CLIENT_SECRET>` with your OAuth credentials:

```bash
kubectl create secret generic operator-oauth \
  -n tailscale \
  --from-literal=client_id="<YOUR_CLIENT_ID>" \
  --from-literal=client_secret="<YOUR_CLIENT_SECRET>" \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets \
           --controller-namespace=sealed-secrets \
           --format yaml > apps/tailscale/oauth-secret.yaml
```

### Verify Deployment

After committing and syncing with ArgoCD, verify the secret was created:

```bash
# Check the sealed secret was processed
kubectl get sealedsecret operator-oauth -n tailscale

# Check the actual secret exists
kubectl get secret operator-oauth -n tailscale

# Check operator is running
kubectl get pods -n tailscale
kubectl logs -n tailscale deployment/tailscale-operator
```

## How It Works

The Tailscale operator watches for Ingress resources with `ingressClassName: tailscale` and creates proxy pods that:

1. Join your tailnet as devices
2. Route traffic from your tailnet to the Kubernetes services
3. Automatically provision TLS certificates via Tailscale's HTTPS feature

This runs alongside Traefik, giving you:
- **Local access**: `*.homelab` via Traefik (requires /etc/hosts)
- **Remote access**: `*.<tailnet>.ts.net` via Tailscale (works from any tailnet device)
