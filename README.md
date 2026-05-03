# Azure Infrastructure — Gallery Platform

Terraform for a self-hosted DevOps platform on Azure: **GitLab CE**, **HashiCorp Vault**, and **AKS** workloads in `gallery-rg`, `westeurope`.

---

## Architecture

<table width="100%" cellpadding="10" cellspacing="0" style="border-collapse:collapse;font-family:sans-serif;font-size:13px">
  <tr>
    <td colspan="4" align="center" style="border:2px solid #94a3b8;background:#f1f5f9;padding:10px;border-radius:4px">
      🌐 &nbsp;<strong>Internet</strong>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center" style="padding:4px 0;color:#64748b;font-size:11px">↓ &nbsp;HTTP :80 &nbsp;HTTPS :443</td>
    <td colspan="2" align="center" style="padding:4px 0;color:#64748b;font-size:11px">↓ &nbsp;HTTPS :443</td>
  </tr>
  <tr>
    <td colspan="2" align="center" style="border:1px solid #93c5fd;background:#dbeafe;padding:8px">
      <strong>AppGW Public IP</strong><br/>
      <span style="font-size:11px;color:#3730a3">Static · Standard SKU · Zone 1/2/3</span>
    </td>
    <td colspan="2" align="center" style="border:1px solid #93c5fd;background:#dbeafe;padding:8px">
      <strong>Bastion Public IP</strong><br/>
      <span style="font-size:11px;color:#3730a3">Static · Standard SKU</span>
    </td>
  </tr>
  <tr>
    <td colspan="4" style="padding:4px 0;color:#64748b;font-size:11px;text-align:center">↓</td>
  </tr>
  <tr>
    <td colspan="4" style="border:2px solid #475569;background:#f8fafc;padding:16px;border-radius:4px">
      <strong>gallery-vnet &nbsp; 10.2.0.0/16</strong>
      <table width="100%" cellpadding="8" cellspacing="0" style="margin-top:10px;border-collapse:separate;border-spacing:0 6px">

        <tr>
          <td colspan="2" style="border:1px dashed #3b82f6;background:#eff6ff;padding:10px;border-radius:4px">
            <strong>appgw-subnet</strong> &nbsp;<span style="color:#6b7280;font-size:11px">10.2.0.0/24</span><br/>
            📦 &nbsp;<strong>Application Gateway</strong> Standard_v2 · autoscale 0–2<br/>
            <span style="font-size:11px;color:#374151">
              <code>gitlab.boukingolts.art</code> → GitLab VM &nbsp;·&nbsp;
              <code>argocd.boukingolts.art</code> → AKS &nbsp;·&nbsp;
              <code>grafana.boukingolts.art</code> → AKS &nbsp;·&nbsp;
              <code>boukingolts.art</code> → AKS<br/>
              HTTP :80 permanently redirects to HTTPS
            </span>
          </td>
        </tr>

        <tr>
          <td width="60%" style="border:1px dashed #16a34a;background:#f0fdf4;padding:10px;border-radius:4px">
            <strong>infra-subnet</strong> &nbsp;<span style="color:#6b7280;font-size:11px">10.2.1.0/24</span><br/>
            🖥 &nbsp;<strong>gitlab-vm</strong> &nbsp; 10.2.1.10 &nbsp;·&nbsp; D2s_v3 (2 vCPU / 8 GB) &nbsp;·&nbsp; 32 GB SSD<br/>
            🔒 &nbsp;<strong>vault-vm</strong> &nbsp;&nbsp; 10.2.1.20 &nbsp;·&nbsp; D2as_v4 (2 vCPU / 8 GB) &nbsp;·&nbsp; 32 GB SSD<br/>
            <span style="font-size:11px;color:#374151">Ubuntu 22.04 LTS · System-Assigned MI · No public IPs</span>
          </td>
          <td width="40%" style="border:1px dashed #9ca3af;background:#f9fafb;padding:10px;border-radius:4px;vertical-align:top;font-size:11px;color:#374151">
            🔁 &nbsp;NAT Gateway → Internet (outbound)<br/>
            🔑 &nbsp;Bastion SSH only<br/>
            🛡 &nbsp;NSGs at NIC level<br/>
            📡 &nbsp;Private DNS: <code>internal.gallery.local</code>
          </td>
        </tr>

        <tr>
          <td colspan="2" style="border:1px dashed #7c3aed;background:#faf5ff;padding:10px;border-radius:4px">
            <strong>aks-subnet</strong> &nbsp;<span style="color:#6b7280;font-size:11px">10.2.2.0/24</span><br/>
            ☸ &nbsp;<strong>gallery-aks</strong> &nbsp; Kubernetes 1.30 · Azure CNI · 2–4 × Standard_D2s_v3<br/>
            <span style="font-size:11px;color:#374151">
              Node pools: <code>default</code> (system, min 2) &nbsp;·&nbsp; <code>agents</code> (CI runners, scale 0–4)<br/>
              API restricted to admin CIDR + infra subnet &nbsp;·&nbsp; NAT Gateway outbound
            </span>
          </td>
        </tr>

        <tr>
          <td colspan="2" style="border:1px dashed #dc2626;background:#fff7f7;padding:10px;border-radius:4px">
            <strong>AzureBastionSubnet</strong> &nbsp;<span style="color:#6b7280;font-size:11px">10.2.3.0/26</span><br/>
            🏰 &nbsp;<strong>Azure Bastion</strong> Basic &nbsp;·&nbsp; SSH proxy to gitlab-vm and vault-vm
          </td>
        </tr>

      </table>
    </td>
  </tr>
  <tr>
    <td colspan="4" align="center" style="border:1px solid #e2e8f0;background:#fafafa;padding:6px;font-size:11px;color:#475569">
      🔍 &nbsp;Private DNS &nbsp;<code>internal.gallery.local</code> &nbsp;·&nbsp;
      <code>gitlab → 10.2.1.10</code> &nbsp;·&nbsp;
      <code>vault → 10.2.1.20</code> &nbsp;·&nbsp;
      <code>registry → 10.2.1.10</code> (internal only)
    </td>
  </tr>
  <tr>
    <td colspan="4" align="center" style="border:1px solid #e2e8f0;background:#fafafa;padding:6px;font-size:11px;color:#475569">
      💾 &nbsp;Terraform state → Azure Blob Storage &nbsp;·&nbsp;
      🗂 &nbsp;NFS storage → Azure Files Premium (<code>nfsstorage3fe</code>) &nbsp;·&nbsp;
      📤 &nbsp;Outbound → NAT Gateway (static IP)
    </td>
  </tr>
</table>

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
