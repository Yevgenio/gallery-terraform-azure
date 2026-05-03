# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# First-time init — requires a backend.conf file (see below, do NOT commit it)
terraform init -backend-config=backend.conf

# Migrate existing local state to the remote backend
terraform init -backend-config=backend.conf -migrate-state

# Generate a self-signed PFX cert for the Application Gateway (initial deploy only)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj "/CN=gitlab.boukingolts.art"
openssl pkcs12 -export -in cert.pem -inkey key.pem -out gallery.pfx -passout pass:changeme

# Preview / apply — three required vars (no defaults)
terraform plan \
  -var="admin_ssh_cidr=<YOUR_IP>/32" \
  -var="appgw_ssl_cert_path=./gallery.pfx" \
  -var="appgw_ssl_cert_password=changeme"

terraform apply \
  -var="admin_ssh_cidr=<YOUR_IP>/32" \
  -var="appgw_ssl_cert_path=./gallery.pfx" \
  -var="appgw_ssl_cert_password=changeme"

# Format / validate
terraform fmt
terraform validate

# SSH to a VM — toggle public IP on, SSH in, toggle off when done
# 1. Open (creates public IP + NSG rule for your IP only, VM does NOT restart)
terraform apply -var="enable_gitlab_public_ip=true" -var="admin_ssh_cidr=<YOUR_IP>/32" \
  -var="appgw_ssl_cert_path=./gallery.pfx" -var="appgw_ssl_cert_password=changeme"
# 2. Connect
ssh azureuser@$(terraform output -raw gitlab_public_ip)
# 3. Close (destroys public IP + removes NSG rule)
terraform apply -var="enable_gitlab_public_ip=false" -var="admin_ssh_cidr=<YOUR_IP>/32" \
  -var="appgw_ssl_cert_path=./gallery.pfx" -var="appgw_ssl_cert_password=changeme"

# Configure kubectl after AKS apply (run from an allowed CIDR)
az aks get-credentials --resource-group gallery-rg --name gallery-aks
```

### backend.conf (create manually, never commit)

```
resource_group_name  = "tfstate-rg"
storage_account_name = "gallerytfstate"
container_name       = "tfstate"
key                  = "gallery/terraform.tfstate"
```

Pre-requisite storage account (run once out-of-band):
```bash
az group create --name tfstate-rg --location westeurope
az storage account create --name gallerytfstate --resource-group tfstate-rg \
  --sku Standard_LRS --https-only true --min-tls-version TLS1_2
az storage container create --name tfstate --account-name gallerytfstate
```

## Architecture

Single-file-per-concern layout (no modules). All resources in `gallery-rg`, `westeurope`.

**Network** (`network.tf`) — VNet `10.2.0.0/16` with three subnets:
- `appgw-subnet` (`10.2.0.0/24`) — Application Gateway (dedicated, Azure requirement); public-facing
- `infra-subnet` (`10.2.1.0/24`) — GitLab + Vault VMs; no public IPs by default; NAT Gateway for outbound
- `aks-subnet` (`10.2.2.0/24`) — AKS node pool; NAT Gateway for outbound

**Load balancer** (`appgw.tf`) — Application Gateway Standard_v2 terminates HTTP/HTTPS/5050, routes to GitLab VM. Port 80 permanently redirects to 443. AKS backend pool is defined but empty — populate with the AKS internal LB IP post-deploy or enable AGIC.

**SSH access** — No Bastion. Use `enable_gitlab_public_ip=true` to temporarily attach a public IP + NSG rule (locked to `admin_ssh_cidr`) to the GitLab VM. Set back to `false` when done — destroys the IP instantly, VM does not restart.

**VMs** (`vms.tf`) — Ubuntu 22.04 LTS, static private IPs, system-assigned managed identity, no public IPs:
- GitLab CE (`10.2.1.10`, Standard_B4ms, 100 GB SSD)
- HashiCorp Vault (`10.2.1.20`, Standard_B2s, 30 GB SSD) — API accessible only from AKS subnet on port 8200

**AKS** (`aks.tf`) — `gallery-aks`, Kubernetes 1.30, Azure CNI, 2–5× Standard_D2s_v3 (autoscaling). API server restricted to `admin_ssh_cidr` + infra subnet + appgw subnet. Kubelet identity has Storage Account Contributor on the AKS node resource group (not Contributor on the whole RG).

**Private DNS** (`dns.tf`) — zone `internal.gallery.local` linked to the VNet. Records: `gitlab → 10.2.1.10`, `vault → 10.2.1.20`.

**State** (`main.tf`) — remote backend in Azure Blob Storage via partial config (`-backend-config=backend.conf`).

**Key variables**: `admin_ssh_cidr`, `appgw_ssl_cert_path`, and `appgw_ssl_cert_password` have no defaults and must be passed on every plan/apply. See ARCHITECTURE.md for the full apply order and migration runbook.

## IDE false positives

The Terraform language server may flag `api_server_authorized_ip_ranges` and `enable_auto_scaling` in `aks.tf` as unexpected. These are valid attributes in azurerm `~> 3.110` (v3.x); they were renamed in v4.x which the LSP may use for schema lookup.
