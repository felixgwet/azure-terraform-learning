# Azure Environment with Terraform

Hands-on learning project: building a complete Azure environment with Terraform (v1.16.x, azurerm provider 5.x), documented step by step.

## What's built so far

- **Resource group** (`azurerm_resource_group`) — the container for everything
- **Virtual network** (`azurerm_virtual_network`, `10.0.0.0/16`) with two subnets:
  - `web` — `10.0.1.0/24`
  - `database` — `10.0.2.0/24`
- **Variables** (`variables.tf`) for location, naming and environment tag
- **Outputs** (`outputs.tf`) printing the resource group ID and location after apply

## File layout

| File | Purpose |
|---|---|
| `main.tf` | Provider config + resource group |
| `variables.tf` | Input variables (the labelled boxes) |
| `outputs.tf` | Values printed after apply (the receipt) |
| `network.tf` | VNet and subnets |
| `learning-journal.md` | Full build journal with lessons learned |

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
- The state file is Terraform's memory — never edit or commit it
- azurerm provider 5.x does not auto-register Azure resource providers: `409 MissingSubscriptionRegistration` means run `az provider register --namespace Microsoft.X` once per subscription

## Roadmap

Next up: a Linux VM in the `web` subnet, then remote state in Azure Storage, modules, Key Vault/RBAC, and CI/CD.
