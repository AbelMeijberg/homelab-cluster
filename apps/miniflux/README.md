# Miniflux Setup

Miniflux is deployed but **won't have an admin user** until you complete the Sealed Secrets setup below.

## Creating the Admin Secret with kubeseal

### 1. Install kubeseal CLI

```bash
# Download and install kubeseal
KUBESEAL_VERSION=0.27.3
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
tar xzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/
rm kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
```

### 2. Verify the Sealed Secrets controller is running

```bash
kubectl get pods -n sealed-secrets
# Should show a running sealed-secrets-controller pod
```

### 3. Create and seal the admin secret

```bash
# Create a plaintext secret (don't commit this!)
kubectl create secret generic miniflux-admin \
  --namespace miniflux \
  --from-literal=ADMIN_USERNAME=admin \
  --from-literal=ADMIN_PASSWORD='your-secure-password-here' \
  --dry-run=client -o yaml > /tmp/miniflux-admin.yaml

# Encrypt it using the cluster's public key
kubeseal --format yaml < /tmp/miniflux-admin.yaml > apps/miniflux/admin-secret.yaml

# Clean up the plaintext file
rm /tmp/miniflux-admin.yaml
```

### 4. Update the ArgoCD application

Edit `apps/miniflux.yaml` and change the directory include:

```yaml
# Before:
directory:
  include: "database.yaml"

# After:
directory:
  include: "{database,admin-secret}.yaml"
```

### 5. Enable admin credentials in values.yaml

Edit `apps/miniflux/values.yaml` and uncomment the admin credential section:

```yaml
env:
  # ... existing env vars ...

  CREATE_ADMIN: "1"
  ADMIN_USERNAME:
    valueFrom:
      secretKeyRef:
        name: miniflux-admin
        key: ADMIN_USERNAME
  ADMIN_PASSWORD:
    valueFrom:
      secretKeyRef:
        name: miniflux-admin
        key: ADMIN_PASSWORD
```

### 6. Commit and push

```bash
git add apps/miniflux/
git commit -m "Add Miniflux admin credentials via SealedSecret"
git push
```

ArgoCD will sync and Miniflux will restart with admin credentials.

## How Sealed Secrets Work

```
You (with kubeseal)              Cluster (sealed-secrets controller)
       |                                        |
       | 1. Fetch public key                    |
       |<---------------------------------------|
       |                                        |
       | 2. Encrypt secret with public key      |
       |                                        |
       | 3. Commit SealedSecret to Git          |
       |                                        |
       | 4. ArgoCD syncs SealedSecret           |
       |--------------------------------------->|
       |                                        |
       |           5. Controller decrypts       |
       |              with private key          |
       |                                        |
       |           6. Creates regular Secret    |
       |              in namespace              |
```

The private key never leaves the cluster, so the encrypted SealedSecret is safe to commit to Git.
