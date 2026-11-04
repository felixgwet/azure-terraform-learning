# Azure Environment with Terraform

Hands-on learning project: building a complete Azure environment with Terraform (v1.16.x, azurerm provider 5.x), documented step by step.

## What's built so far

- **Resource group** (`azurerm_resource_group`) — the container for everything
- **Virtual network** (`azurerm_virtual_network`, `10.0.0.0/16`) with two subnets:
  - `web` — `10.0.1.0/24`
  - `database` — `10.0.2.0/24`
- **Linux VM** (`azurerm_linux_virtual_machine`, Ubuntu 24.04 LTS) in the `web` subnet, with its supporting pile:
  - Public IP (`azurerm_public_ip`) — the front door address
  - Network interface (`azurerm_network_interface`) — the cable into the subnet
  - Network security group (`azurerm_network_security_group`) — one rule only: SSH on port 22
  - NIC/NSG association — the firewall clips onto the cable, not the VM
  - SSH key auth only (`ed25519`), password login disabled
- **Remote state** — `terraform.tfstate` lives in Azure Storage (`backend "azurerm"`) with blob lease locking, migrated from local state
- **Variables** (`variables.tf`) for location, naming and environment tag
- **Outputs** (`outputs.tf`) printing the resource group ID, location and VM public IP after apply

## File layout

| File | Purpose |
|---|---|
| `main.tf` | Provider config, remote state backend + resource group |
| `variables.tf` | Input variables (the labelled boxes) |
| `outputs.tf` | Values printed after apply (the receipt) |
| `network.tf` | VNet and subnets |
| `compute.tf` | The VM and everything it needs to exist (public IP, NSG, NIC, association) |
| `learning-journal.md` | Full build journal, lessons 1–17 with screenshots |
| `lesson1-terraform-fundamentals.md` | Standalone notes: lesson 1 |
| `lesson2-terraform-init-and-plan.md` | Standalone notes: lesson 2 |
| `app/index.html` | The full journal as a single readable web page |

## Usage

```powershell
az login
terraform init
terraform plan
terraform apply
terraform destroy   # when done - the code is the real thing, resources are disposable
```

## Lessons learned so far

- `init -> plan -> apply -> destroy` is the core loop
- Read the plan summary line before every apply (`X to add, Y to change, Z to destroy`)
- Resource references (`azurerm_resource_group.main.name`) wire resources together; Terraform derives build order from them
- The state file is Terraform's memory — never edit or commit it; remote state in Azure Storage adds locking via blob leases
- azurerm provider 5.x does not auto-register Azure resource providers: `409 MissingSubscriptionRegistration` means run `az provider register --namespace Microsoft.X` once per subscription
- Always read the error code after the HTTP status: `409 MissingSubscriptionRegistration` (provider switch off), `409 SkuNotAvailable` (size out of stock) and `400 InvalidParameter` (typo) need three different fixes
- Trial subscriptions are blocked from many VM families — check `az vm list-skus --location <region> --all` before guessing sizes
- A VM is never one resource: it's a small pile (public IP, NSG, NIC, association, VM) wired together by references
- Changing backend configuration means re-running `terraform init` (use `-migrate-state` to carry existing state over)

## Roadmap

Done: Linux VM in the `web` subnet, remote state in Azure Storage with locking. Next up: a SQL database on the `database` subnet (accepting traffic from `web` only), then modules and environments, Key Vault/RBAC, and CI/CD.
