# Azure Infrastructure — Gallery Platform

Terraform for a self-hosted DevOps platform on Azure: **GitLab CE**, **HashiCorp Vault**, and **AKS** workloads in `gallery-rg`, `westeurope`.

---

## Quick Deploy

```bash
# 1. Create terraform.tfvars (already gitignored)
cat > terraform.tfvars <<EOF
admin_ssh_cidr          = "YOUR_IP/32"
appgw_ssl_cert_path     = "/path/to/gallery.pfx"
appgw_ssl_cert_password = "changeme"
storage_account_name    = "nfsstorage3fe"
EOF

# 2. Init & apply
terraform init
terraform apply
```

**Three required variables** (no defaults): `admin_ssh_cidr`, `appgw_ssl_cert_path`, `storage_account_name`.

### SSH to VMs (via Bastion — no direct SSH)

```bash
az network bastion ssh \
  --name gallery-bastion --resource-group gallery-rg \
  --target-resource-id $(az vm show -g gallery-rg -n gitlab-vm --query id -o tsv) \
  --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa
```

### SSL Certificate (Let's Encrypt → PFX)

```bash
openssl pkcs12 -export \
  -in fullchain.pem -inkey privkey.pem \
  -out gallery.pfx -passout pass:changeme
```

---

## Modules

| Module | Resources |
|--------|-----------|
| `modules/network` | VNet, 4 subnets, NAT Gateway, NSGs, Private DNS |
| `modules/vms` | gitlab-vm, vault-vm (no public IPs, managed identity) |
| `modules/aks` | AKS cluster + CI agents node pool |
| `modules/ingress` | Application Gateway, Azure Bastion |
| `modules/storage` | Azure Files Premium NFS share |

See [ARCHITECTURE.md](ARCHITECTURE.md) for security posture, NSG rules, migration order, and known gaps.
