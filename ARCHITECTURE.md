# Azure Infrastructure — Architecture & Hardening Whitepaper

## Overview

This document describes the target architecture for a self-hosted DevOps platform running on Azure, migrated from AWS. The platform consists of:

- **GitLab CE** — source control, CI/CD, and container registry (`gitlab.boukingolts.art`, `registry.boukingolts.art`)
- **HashiCorp Vault** — secrets management for AKS workloads
- **Azure Kubernetes Service (AKS)** — application workload cluster

All infrastructure is defined in Terraform (`azurerm` provider `~> 3.110`, Terraform `>= 1.6`) in the `gallery-rg` resource group, `westeurope` region.

---

## AWS-to-Azure Concept Mapping

| AWS Concept | Azure Equivalent | Terraform Resource |
|-------------|------------------|--------------------|
| Internet Gateway + public subnet | Application Gateway subnet (public IP on AppGW, not on VMs) | `azurerm_application_gateway` |
| Private subnet + NAT Gateway | Private subnet + NAT Gateway | `azurerm_nat_gateway` + `azurerm_subnet_nat_gateway_association` |
| Application Load Balancer (Layer 7) | Application Gateway Standard_v2 | `azurerm_application_gateway` |
| Bastion Host | Azure Bastion (managed PaaS) | `azurerm_bastion_host` |
| Route53 Private Hosted Zone | Private DNS Zone | `azurerm_private_dns_zone` |
| EKS private endpoint | `api_server_authorized_ip_ranges` | attribute on `azurerm_kubernetes_cluster` |
| S3 Terraform backend | Azure Blob Storage backend | `backend "azurerm"` |
| EC2 IAM Instance Role | System-Assigned Managed Identity | `identity { type = "SystemAssigned" }` on VM |
| Security Group | Network Security Group (NSG) | `azurerm_network_security_group` |

---

## Network Topology

### Subnet Layout

All subnets live inside `gallery-vnet` (`10.2.0.0/16`).

| Subnet | CIDR | Purpose | AWS Analogy |
|--------|------|---------|-------------|
| `appgw-subnet` | `10.2.0.0/24` | Application Gateway (Azure requires a dedicated subnet) | Public subnet |
| `infra-subnet` | `10.2.1.0/24` | GitLab VM + Vault VM — **no public IPs** | Private subnet |
| `aks-subnet` | `10.2.2.0/24` | AKS node pool | Private subnet |
| `AzureBastionSubnet` | `10.2.3.0/26` | Azure Bastion (name is mandatory; /26 minimum) | Jump host subnet |

### Traffic Flow

```
Internet
  │
  ▼
azurerm_public_ip.appgw  (Static, Standard SKU)
  │
  ▼
azurerm_application_gateway.main  (Standard_v2, ports 80 / 443 / 5050)
  │            │                │
  │            │                └─── port 5050 ──► GitLab VM 10.2.1.10 [container registry]
  │            └──────────────────── port 443  ──► GitLab VM 10.2.1.10 [web]
  │             HTTP → HTTPS redirect on port 80
  │
  └── AKS backend pool ──────────────► AKS internal LB (provisioned post-cluster)

SSH / RDP access:
  Operator (browser or az CLI)
    │
    ▼
  azurerm_bastion_host.main  (TLS 443, Standard SKU)
    │
    ├──► GitLab VM  10.2.1.10  (private NIC only)
    └──► Vault VM   10.2.1.20  (private NIC only)

AKS → Vault:
  Pod ──► vault.internal.gallery.local ──► 10.2.1.20:8200
          (resolved by private DNS zone, allowed by Vault NSG)
```

### Outbound Internet (NAT Gateway)

Both `infra-subnet` and `aks-subnet` are attached to a single NAT Gateway with a static public IP. VMs and AKS nodes reach the internet through NAT — no individual public IPs required.

---

## Security Posture

### NSG Rules

**AppGW NSG** (`appgw-subnet`):
- Required by Azure: allow `GatewayManager` on ports 65200–65535 (infrastructure probes)
- Allow inbound 80, 443, 5050 from Internet

**GitLab NSG** (NIC-level on `gitlab-vm`):
- Allow 80, 443, 5050 from `10.2.0.0/24` (AppGW subnet) only — no direct internet
- Allow 22 from `10.2.3.0/26` (Bastion subnet) only

**Vault NSG** (NIC-level on `vault-vm`):
- Allow 22 from `10.2.3.0/26` (Bastion subnet) only
- Allow 8200 from `10.2.2.0/24` (AKS subnet) only — Vault API never public

**Bastion NSG** (`AzureBastionSubnet`):
- Inbound: 443 from Internet; 443/4443 from GatewayManager; 443 from AzureLoadBalancer
- Outbound: 22 to VirtualNetwork; 443 to AzureCloud

### Key Security Decisions

| Decision | Rationale |
|----------|-----------|
| No public IPs on VMs | Eliminates direct internet attack surface; all access via AppGW or Bastion |
| Vault has no public exposure | Vault API is reachable only from the AKS subnet — follows Vault hardening guidance |
| AKS API `api_server_authorized_ip_ranges` | Restricts Kubernetes API access to admin CIDR + infra subnet |
| NSGs at NIC level (not subnet level) | Prevents GitLab NSG from accidentally applying to Vault (was a bug in the original config) |
| System-assigned managed identity on VMs | Enables Azure service auth (Key Vault, storage) without embedded credentials |

---

## Component Details

### Application Gateway

- **SKU**: `Standard_v2`, capacity 2 (autoscaling can be enabled later)
- **Frontend**: single public IP, listeners on 80, 443, 5050
- **Routing rules**:
  - Port 80 → permanent redirect to HTTPS
  - Port 443 → GitLab VM backend (10.2.1.10:80)
  - Port 5050 → GitLab registry backend (10.2.1.10:5050)
  - AKS backend pool: initially empty; populate with the AKS internal load balancer IP after it is provisioned, or use AGIC (Application Gateway Ingress Controller) for dynamic routing
- **TLS**: PFX certificate supplied via `var.appgw_ssl_cert_path`. Use a self-signed cert for the initial deployment; replace with a CA-signed cert once DNS is pointed at the AppGW IP.

### Azure Bastion

- **SKU**: `Standard` (required for native client tunneling)
- `tunneling_enabled = true` enables `az network bastion ssh` from the CLI without opening a browser
- SSH command:
  ```bash
  az network bastion ssh \
    --name gallery-bastion \
    --resource-group gallery-rg \
    --target-resource-id $(az vm show -g gallery-rg -n gitlab-vm --query id -o tsv) \
    --auth-type ssh-key \
    --username azureuser \
    --ssh-key ~/.ssh/id_rsa
  ```

### Virtual Machines

| VM | Size | Disk | Private IP | Purpose |
|----|------|------|------------|---------|
| `gitlab-vm` | Standard_B4ms (4 vCPU / 16 GB) | 100 GB StandardSSD | 10.2.1.10 | GitLab CE + container registry |
| `vault-vm` | Standard_B2s (2 vCPU / 4 GB) | 30 GB StandardSSD | 10.2.1.20 | HashiCorp Vault |

Both VMs:
- Ubuntu 22.04 LTS
- SSH key auth (`azureuser`)
- System-assigned managed identity
- No public IPs

### AKS Cluster

- **Kubernetes version**: 1.30
- **Node pool**: 2–5 × Standard_D2s_v3, autoscaling enabled
- **Networking**: Azure CNI, Azure network policy, attached to `aks-subnet`
- **API access**: restricted to `var.admin_ssh_cidr` + `10.2.1.0/24` (infra subnet)
- **Kubelet identity role**: Storage Account Contributor scoped to the AKS node resource group (`MC_gallery-rg_gallery-aks_westeurope`) — replaces the overly broad Contributor on `gallery-rg`

### Private DNS Zone

Zone: `internal.gallery.local`, linked to `gallery-vnet`.

| Record | IP | Used by |
|--------|----|---------|
| `gitlab.internal.gallery.local` | 10.2.1.10 | Internal tooling |
| `vault.internal.gallery.local` | 10.2.1.20 | AKS pods (Vault Agent, CSI driver) |

### Terraform State Backend

State is stored in Azure Blob Storage (not local). The backend uses partial configuration — credentials and account details are passed at `terraform init` time via a `backend.conf` file that is **never committed**.

Pre-requisite setup (run once, out-of-band):
```bash
az group create --name tfstate-rg --location westeurope
az storage account create \
  --name gallerytfstate \
  --resource-group tfstate-rg \
  --sku Standard_LRS \
  --https-only true \
  --min-tls-version TLS1_2
az storage container create --name tfstate --account-name gallerytfstate
```

`backend.conf` (add to `.gitignore`):
```
resource_group_name  = "tfstate-rg"
storage_account_name = "gallerytfstate"
container_name       = "tfstate"
key                  = "gallery/terraform.tfstate"
```

Migrate existing local state:
```bash
terraform init -backend-config=backend.conf -migrate-state
```

---

## Migration Order

Apply in phases to avoid losing SSH access to the VMs mid-migration.

```
Step 1 — Migrate state backend (out-of-band, before any terraform apply)
  See "Terraform State Backend" section above.

Step 2 — Add new network resources (additive only, no existing resources change)
  terraform apply \
    -target=azurerm_subnet.appgw \
    -target=azurerm_subnet.bastion \
    -target=azurerm_nat_gateway.main \
    -target=azurerm_nat_gateway_public_ip_association.main \
    -target=azurerm_subnet_nat_gateway_association.infra \
    -target=azurerm_subnet_nat_gateway_association.aks \
    -target=azurerm_network_security_group.appgw \
    -target=azurerm_network_security_group.bastion \
    -target=azurerm_private_dns_zone.internal \
    -target=azurerm_private_dns_zone_virtual_network_link.gallery \
    -target=azurerm_private_dns_a_record.gitlab \
    -target=azurerm_private_dns_a_record.vault

Step 3 — Deploy Azure Bastion (must exist BEFORE public IPs are removed from VMs)
  terraform apply -target=azurerm_bastion_host.main

Step 4 — Verify Bastion SSH works to both VMs
  az network bastion ssh --name gallery-bastion --resource-group gallery-rg \
    --target-resource-id $(az vm show -g gallery-rg -n gitlab-vm --query id -o tsv) \
    --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa

Step 5 — Deploy Application Gateway
  terraform apply -target=azurerm_application_gateway.main

Step 6 — Remove public IPs from VMs + tighten NSG rules
  terraform apply \
    -target=azurerm_network_interface.gitlab \
    -target=azurerm_network_interface.vault \
    -target=azurerm_network_security_group.gitlab \
    -target=azurerm_network_security_group.vault

Step 7 — AKS hardening (autoscaling, authorized IPs, narrowed role)
  terraform apply \
    -target=azurerm_kubernetes_cluster.gallery \
    -target=azurerm_role_assignment.aks_storage

Step 8 — Full reconcile
  terraform apply
```

### Breaking Changes

| Change | Impact | Mitigation |
|--------|--------|-----------|
| Public IPs removed from both VMs | Direct SSH via `admin_ssh_cidr` stops working | Complete Steps 3–4 first; verify Bastion before Step 6 |
| GitLab DNS must point to AppGW IP | `gitlab.boukingolts.art` unreachable during cutover | Update DNS A record after Step 5; plan a maintenance window |
| AKS `node_count` removed | Required when enabling autoscaling | Removed in same apply as `enable_auto_scaling = true` |
| Local → remote state | One-time migration | `terraform init -backend-config=backend.conf -migrate-state` |
| `aks_contributor` role deleted | Brief gap in dynamic PVC provisioning | Apply new `aks_storage` role (Step 7) before deleting old one |

---

## SSL Certificate Setup

The Application Gateway requires a PFX-format certificate for HTTPS termination.

**Initial deployment (self-signed):**
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj "/CN=gitlab.boukingolts.art"
openssl pkcs12 -export -in cert.pem -inkey key.pem \
  -out gallery-self-signed.pfx -passout pass:changeme
```

Pass to Terraform:
```bash
terraform apply \
  -var="appgw_ssl_cert_path=./gallery-self-signed.pfx" \
  -var="appgw_ssl_cert_password=changeme"
```

**Add to `.gitignore`:** `*.pfx`, `*.pem`, `backend.conf`

Replace with a CA-signed certificate (e.g. Let's Encrypt) once DNS is pointed at the AppGW IP.

---

## DNS Cutover

After Step 5 (AppGW deployed):
1. Get the AppGW public IP: `terraform output appgw_public_ip`
2. Update DNS A records for `gitlab.boukingolts.art` and `registry.boukingolts.art` to point to that IP
3. Wait for TTL to expire
4. Verify: `curl -I https://gitlab.boukingolts.art/`

---

## Known Gaps / Next Phases

The following are intentionally out of scope for this phase and should be addressed later:

| Item | Why deferred |
|------|-------------|
| Azure Key Vault integration | Requires additional managed identity permissions and application-level config in GitLab/Vault |
| OS disk encryption (CMK) | Requires a Disk Encryption Set and Key Vault key; separate operational runbook |
| Monitoring & alerting | Log Analytics Workspace + Azure Monitor alert rules — separate module |
| Azure Container Registry | Replace `docker.io` pulls with private registry — separate module |
| AKS full private cluster | Requires private DNS zone for API server; more complex network setup |
| AKS AGIC | Automates AppGW backend pool management from Kubernetes Ingress objects |
| Vault HA | Current single-VM Vault is a SPOF; Vault cluster or Azure-managed HSM for production |
