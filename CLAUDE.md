# CLAUDE.md

## Rules

* YOU ARE FORBIDDEN TO COMMIT AND PUSH TO GITHUB (pushing to GitLab is allowed)
* You are forbidden to add 'Claude' reference as author to anywhere (commits, docs, etc)
* You don't put commentaries on code
* You don't use emoticons
* You're not allowed to commit and push to GitHub directly neither mention yourself (GitLab push is allowed)
* You're not allowed to create/edit resources directly via kubectl/vault, you can only make these type of changes via OpenTofu or manually like this to test something
* At the end of your task you always review what was done and repo README to properly update it
* **IMPORTANT**: All secrets from `secrets/common/cluster-secret-store/secrets` are automatically available as environment variables on self-hosted runners (including VAULT_TOKEN, VAULT_ADDR, etc.). DO NOT explicitly set these in workflows unless absolutely necessary

## Repository Overview

Public portfolio repository showcasing production-grade infrastructure-as-code for managing Kubernetes clusters on Proxmox VE using OpenTofu with GitOps workflows.

**Key Architecture:**
- Two-tier OpenTofu structure: base modules + application modules
- Cluster provisioning via Cluster API (clustermgmt K3s cluster as management cluster)
- Multi-environment isolation using OpenTofu workspaces (prod, clustermgmt, toolz, home, observability)
- Secrets: SOPS (age encryption) for git storage, HashiCorp Vault for runtime
- Distributions: K3s (legacy single-node), kubeadm, RKE2 (via Cluster API)
- Dev environments: ephemeral clusters (created/destroyed per PR in app repos)

**Security Posture:**
- ✅ All secrets SOPS-encrypted (age key: `age15vvdhaj90s3nru2zw4p2a9yvdrv6alfg0d6ea6zxpx3eagyqfqlsgdytsp`)
- ✅ No credentials in git history (verified clean)
- ✅ Externally-usable credentials (SSH keys, GitHub PAT, Cloudflare token) protected
- ⚠️ Public repository - workflow logs visible (internal details only, homelab is private)

## Common Commands

### OpenTofu Operations
```bash
# Plan/apply specific environment
make plan ENV=prod
make apply ENV=prod

# All environments
make plan
make apply

# Utilities
make init
make fmt
make validate
```

### Secrets Management
```bash
# Create/edit/view secrets (SOPS-encrypted)
./secret_new.sh path/to/secret.yaml
./secret_edit.sh path/to/secret.yaml
./secret_view.sh path/to/secret.yaml
```

**Note:** Make commands automatically decode SOPS secrets to `clusters/tmp/` before OpenTofu runs.

### Pre-Commit Hooks
```bash
# Install pre-commit framework and hooks
make pre-commit-install

# Run all hooks on all files
make pre-commit-run

# Update hook versions
make pre-commit-update
```

### Cluster Management (Cluster API)
```bash
# Update Talos kubeconfigs in Vault
make build-kubeconfig-tool
make update-kubeconfigs ENV=toolz
```

## Key Patterns

### Workspace-Based Environments

Each workspace represents an environment. Configuration in `clusters/variables.tf`:

```hcl
variable "workload" {
  default = {
    prod = ["externaldns", "cert_manager", "istio", "argocd", ...]
    toolz = ["redis", "vault", "github_runner", "argocd", ...]
  }
}

variable "config" {
  default = {
    prod = {
      kubernetes_context = "prod"
      argocd_domain = "argocd.homelabz.eu"
    }
  }
}
```

**Pattern:** Modules check `contains(local.workload, "module_name")` for conditional deployment.

### Cluster API Provisioning (Current Standard)

1. Define cluster in `clusters/variables.tf` under `clustermgmt` workspace (kubernetes-cluster list)
2. OpenTofu creates Cluster API resources on clustermgmt K3s cluster (context: `clustermgmt`)
3. Cluster API provisions VMs and bootstraps Kubernetes
4. `cicd-update-kubeconfig` tool extracts kubeconfigs to Vault
5. Cluster available immediately to OpenTofu and CI/CD

**Key Files:**
- `.github/workflows/opentofu.yml` - Main deployment pipeline
- `modules/apps/kubernetes-cluster/` - Polymorphic cluster module (talos, kubeadm, rke2, k3s)

### Secrets Lifecycle

```
Developer → secret*.sh → SOPS YAML → Git → CI/CD (decrypt) → Vault → External Secrets → K8s → Pods
```

**In OpenTofu:**
```hcl
locals {
  secrets_json = jsondecode(file("${path.module}/tmp/secrets.json"))
}
vault_token = local.secrets_json["kv/cluster-secret-store/secrets/VAULT_TOKEN"]["VAULT_TOKEN"]
```

## Critical Workflows

### Adding a New Module

1. Create in `modules/apps/module-name/`
2. Add to `clusters/modules.tf`:
   ```hcl
   module "module_name" {
     count  = contains(local.workload, "module_name") ? 1 : 0
     source = "../modules/apps/module-name"
   }
   ```
3. Add to workspace in `clusters/variables.tf`:
   ```hcl
   workload = { prod = ["existing", "module_name"] }
   config = { prod = { module_name = {} } }
   ```

### Adding a New Cluster (Cluster API)

Add to `clusters/variables.tf` under the `clustermgmt` workspace `kubernetes-cluster` list:
```hcl
config = {
  clustermgmt = {
    kubernetes-cluster = [{
      cluster_type              = "rke2"  # talos | kubeadm | rke2 | k3s
      name                      = "new-cluster"
      kubernetes_version        = "v1.33.0"
      control_plane_endpoint_ip = "192.168.1.X"
      ip_range_start            = "192.168.1.X"
      ip_range_end              = "192.168.1.X"
      gateway                   = "192.168.1.1"
      prefix                    = 24
      dns_servers               = ["192.168.1.3", "8.8.4.4"]
      source_node               = "node03"
      template_id               = 9004
      cp_replicas               = 1
      wk_replicas               = 2
      # ... resource allocations
    }]
  }
}
```

Cluster API runs on the `clustermgmt` K3s cluster (context: `clustermgmt`). Commit changes - CI/CD handles provisioning.

### Handling Secrets

**Never commit unencrypted secrets.**

```bash
# Create new secret
./secret_new.sh secrets/path/to/secret.yaml

# Reference in OpenTofu
cd clusters && python3 load_secrets.py
# Access via local.secrets_json
```

## Important File Locations

**OpenTofu:**
- `clusters/modules.tf` - Module orchestration
- `clusters/variables.tf` - Workspace configs + Cluster API definitions
- `clusters/providers.tf` - Provider configurations
- `clusters/load_secrets.py` - SOPS decryption

**Modules:**
- `modules/base/` - Building blocks (helm, namespace, ingress, credentials, etc.)
- `modules/apps/` - Applications (argocd, vault, postgres, istio, cert_manager, etc.)

**CI/CD:**
- `.github/workflows/opentofu.yml` - Main deployment
- `.github/workflows/ansible.yml` - Legacy K3s maintenance

**Secrets:**
- `secrets/` - SOPS-encrypted secrets (all environments)
- `.sops.yaml` - Encryption rules

## State Management

- Backend: S3-compatible (MinIO VM) at `s3.homelabz.eu`
- Workspace-specific state files
- Daily backups to Oracle Cloud Object Storage

```bash
cd clusters && tofu workspace select prod
make workspace  # List workspaces
```

## Physical Infrastructure

- 3 Proxmox nodes: NODE01 (16GB), NODE02 (32GB), NODE03 (128GB)
- Management cluster: `clustermgmt` K3s on NODE02 — runs Cluster API only (context: `clustermgmt`, OpenTofu workspace: `clustermgmt`)
- Workloads cluster: `toolz` RKE2 on NODE03 — vault, harbor, argocd, gitlab-runner, nats, etc. (context: `toolz`, OpenTofu workspace: `toolz`)
- VM services: GitLab CE (192.168.1.102), MinIO (192.168.1.103), PostgreSQL+Redis (192.168.1.100)
- Legacy K3s: home, observability (Ansible-managed)
- Cluster API managed: prod (kubeadm), toolz (RKE2)
- Network: 192.168.1.0/24 (private, not internet-exposed)

## Security Notes

**Public Repository Context:**
- Repository is PUBLIC for portfolio showcase
- Homelab is PRIVATE (192.168.x.x not internet-routable)
- Externally-usable credentials (SSH keys, Cloudflare token) are protected
- GitHub workflow logs are public but contain only internal details

**Best Practices Demonstrated:**
- SOPS encryption for all secrets
- GitLab CI/CD with self-hosted runners on K8s (controlled environment)
- No debug logging of sensitive values
- Clean git history (no committed secrets)

**Security Audit Results (Latest):**
- ✅ No externally-usable credential exposure found
- ✅ Proper secrets management (SOPS + Vault)
- ✅ Docker login using `--password-stdin`
- ⚠️ Internal details visible in logs (acceptable for portfolio)

## Troubleshooting

**OpenTofu plan shows unwanted changes:**
- Run: `cd clusters && python3 load_secrets.py`
- Verify workspace: `tofu workspace show`

**Module not deploying:**
- Check `workload` list in `clusters/variables.tf`
- Verify workspace: `tofu workspace select <env>`

**Kubeconfig not in Vault (Cluster API):**
- Verify cluster ready: `kubectl --context clustermgmt get cluster -n <namespace> <cluster>`
- Check secret: `kubectl --context clustermgmt get secret -n <namespace> <cluster>-kubeconfig` # pragma: allowlist secret
- Run manually: `./cicd-update-kubeconfig --cluster-name <cluster> --namespace <namespace> --vault-path kv/cluster-secret-store/secrets --vault-addr $VAULT_ADDR --management-context clustermgmt`

**CRD chicken-and-egg:**
- Set `create_default_gateway = false` or `install_crd = false` initially
- Run `tofu apply` to install CRDs
- Set to `true` and apply again

## Testing Workflow

Always test in order:
1. `make fmt` - Format
2. `make validate` - Validate
3. `make plan ENV=<test>` - Review changes
4. `make apply ENV=<test>` - Apply to test
5. `kubectl --context <test> get all -A` - Verify
6. Apply to production

## References

- [README.md](README.md) - Comprehensive architecture
- [Security Audit](.claude/plans/lovely-foraging-otter.md) - Latest security assessment
- [docs/SECRETS_ROTATION.md](docs/SECRETS_ROTATION.md) - Secret rotation procedures
- [cicd-update-kubeconfig/README.md](cicd-update-kubeconfig/README.md) - Kubeconfig tool docs
