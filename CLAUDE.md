# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Init — backend config is hardcoded in backend.tf (use_azuread_auth = true, no key-based auth)
terraform init

# Preview / apply — required vars (no defaults)
terraform plan \
  -var="admin_ssh_cidr=<YOUR_IP>/32" \
  -var="appgw_ssl_cert_path=./gallery.pfx" \
  -var="appgw_ssl_cert_password=<CERT_PASSWORD>" \
  -var="storage_account_name=<NFS_STORAGE_ACCOUNT>"

terraform apply \
  -var="admin_ssh_cidr=<YOUR_IP>/32" \
  -var="appgw_ssl_cert_path=./gallery.pfx" \
  -var="appgw_ssl_cert_password=<CERT_PASSWORD>" \
  -var="storage_account_name=<NFS_STORAGE_ACCOUNT>"

# Format / validate
terraform fmt
terraform validate

# SSH to a VM via Bastion tunnel
az network bastion ssh \
  --name gallery-bastion --resource-group gallery-rg \
  --target-resource-id $(az vm show -g gallery-rg -n gitlab-vm --query id -o tsv) \
  --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa

# File transfer via Bastion tunnel (Terminal 1: open tunnel, Terminal 2: scp/rsync)
az network bastion tunnel \
  --name gallery-bastion --resource-group gallery-rg \
  --target-resource-id $(az vm show -g gallery-rg -n gitlab-vm --query id -o tsv) \
  --resource-port 22 --port 2222
scp -P 2222 localfile azureuser@127.0.0.1:/remote/path/

# Configure kubectl after AKS apply
az aks get-credentials --resource-group gallery-rg --name gallery-aks
```

## Architecture

Modular layout under `modules/`. All resources in `gallery-rg`, `westeurope`.

**Network** (`modules/network`) — VNet `gallery-vnet` (`10.2.0.0/16`) with four subnets:
- `appgw-subnet` (`10.2.0.0/24`) — Application Gateway; public-facing
- `infra-subnet` (`10.2.1.0/24`) — GitLab + Vault VMs; no public IPs; NAT Gateway for outbound
- `aks-subnet` (`10.2.2.0/24`) — AKS node pool; NAT Gateway for outbound
- `AzureBastionSubnet` (`10.2.3.0/26`) — Azure Bastion; name mandatory, /26 minimum

NAT Gateway public IP: `20.23.242.48` — included in AKS API server authorized IP ranges.

**Load balancer** (`modules/ingress`) — Application Gateway Standard_v2, hostname-based routing:
- `gitlab.boukingolts.art` → GitLab VM (`10.2.1.10`)
- `argocd.boukingolts.art` → AKS internal LB (Traefik)
- `boukingolts.art` → AKS internal LB (Traefik)
- `grafana.boukingolts.art` → AKS internal LB (Traefik)

Port 80 permanently redirects to 443. AKS backend pool IP set via `aks_internal_lb_ip` variable after Traefik internal LB is deployed.

**SSH access** (`modules/ingress`) — Azure Bastion **Standard SKU** (required for tunneling and file transfer). VMs have no public IPs.

**VMs** (`modules/vms`) — static private IPs, system-assigned managed identity, no public IPs, 32 GB OS disk:
- GitLab (`10.2.1.10`, Standard_D2s_v3) — boots from Azure Compute Gallery image `galleryImages/gitlab/1.0.0`. Docker + GitLab container managed by Ansible. GitLab data lives at `/mnt/gitlab_data` on the host.
- Vault (`10.2.1.20`, Standard_D2as_v4) — API accessible only from AKS subnet on port 8200

**AKS** (`modules/aks`) — `gallery-aks`, Kubernetes 1.35, Azure CNI, 2–4× Standard_D2s_v3 (autoscaling). `outbound_type = "userAssignedNATGateway"` — uses the existing NAT Gateway for egress (prevents AKS from creating a competing outbound LB which breaks node-to-API-server connectivity). API server authorized IPs: `admin_ssh_cidr` + infra subnet + appgw subnet + NAT Gateway IP.

**Private DNS** (`modules/network`) — zone `internal.gallery.local` linked to the VNet:
- `gitlab → 10.2.1.10`
- `registry → 10.2.1.10`
- `vault → 10.2.1.20`
- `aks → CNAME to AKS cluster FQDN` (auto-updated by Terraform on each cluster recreation)

**Storage** (`modules/storage`) — Azure Files Premium NFS share for AKS workloads.

**State** — remote backend in Azure Blob Storage (`tfstatest3fe`, `tfstate-container`). Uses `use_azuread_auth = true` — key-based auth is disabled on the storage account. Requires `Storage Blob Data Contributor` role on the storage account.

## Current Terraform state (2026-05-04)

Only `azurerm_resource_group.gallery` remains in state — all other resources were torn down at end of day. The resource group is intentionally kept in state so the next `terraform apply` rebuilds everything inside it.

`gallery-rg` contains an Azure Compute Gallery (`galleryImages`) with a GitLab VM image (`gitlab/1.0.0`) that must be preserved — it cannot be moved to another resource group (Azure limitation). Do NOT run `terraform destroy` on the resource group.

## VM configuration

VMs are provisioned bare by Terraform. Docker and application setup (GitLab container, Vault) is handled by **Ansible** from `../ansible/`.

## AKS ingress

Traefik runs inside AKS (migrated from on-prem). After deploying Traefik with `service.beta.kubernetes.io/azure-load-balancer-internal: "true"`, get its internal LB IP and set `aks_internal_lb_ip` in `terraform.tfvars`, then re-apply to wire it into the Application Gateway.

## Known quota constraints

Subscription vCPU limit in westeurope: **10 cores**. Current baseline usage:
- GitLab VM (Standard_D2s_v3): 2 vCPU
- Vault VM (Standard_D2as_v4): 2 vCPU
- AKS min 2 nodes (Standard_D2s_v3): 4 vCPU
- Total at minimum: 8/10 vCPU

AKS can scale to max 4 nodes but will hit quota at 3 nodes (12 vCPU needed, 10 limit). Request a quota increase or reduce VM sizes if autoscaling beyond 1 additional node is needed.

## IDE false positives

The Terraform language server may flag `api_server_authorized_ip_ranges` and `auto_scaling_enabled` as unexpected. These are valid attributes in azurerm `~> 4.x`; the LSP schema may lag behind.
