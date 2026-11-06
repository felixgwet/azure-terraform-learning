# Azure Environment with Terraform

Hands-on learning project: building a complete Azure environment with Terraform (v1.16.x, azurerm provider 5.x), documented step by step.

## What's built so far

- **Reusable module** (`modules/environment`) — one parameterised blueprint for a whole environment, stamped out twice:
  - `dev` (VNet `10.0.0.0/16`) and `prod` (VNet `10.1.0.0/16`), each in its own resource group
  - Inputs: environment name, location, VM size, VNet/subnet CIDR ranges
- **Per environment** the module builds:
  - Resource group with environment tagging
  - Virtual network with two subnets (`web` and `database`)
  - Ubuntu 24.04 VM in the `web` subnet, with its supporting pile: public IP, network interface, network security group (SSH/22 only), NIC/NSG association
  - SSH key auth only (`ed25519`), password login disabled
- **Remote state** — `terraform.tfstate` lives in Azure Storage (`backend "azurerm"`) with blob lease locking, migrated from local state
- **Azure SQL per environment** (`azurerm_mssql_server` + `azurerm_mssql_database`, Basic tier) with an Azure-services-only firewall rule; admin password injected via a sensitive variable from a gitignored tfvars file; SQL lives in France Central (trial sub blocks SQL provisioning in UK regions)
- **Outputs** printing the dev and prod VM public IPs after apply

## File layout

| File | Purpose |
|---|---|
| `main.tf` | Provider config, remote state backend, and the two `module` calls (dev + prod) |
| `variables.tf` | Root input variables |
| `outputs.tf` | Receipts: dev and prod VM public IPs |
| `modules/environment/main.tf` | The blueprint: RG, VNet, subnets, VM stack |
| `modules/environment/variables.tf` | The module's dials (environment, location, vm_size, CIDRs) |
| `modules/environment/outputs.tf` | The module's receipts (VM IP, RG name) |
| `learning-journal.md` | Full build journal with screenshots |
| `lesson1-terraform-fundamentals.md` | Standalone notes: lesson 1 |
| `lesson2-terraform-init-and-plan.md` | Standalone notes: lesson 2 |
| `app/index.html` | The full journal as a single readable web page |

## Usage

```powershell
az login
terraform init
terraform plan    # expect 18 resources: the 9-piece stack, stamped twice
terraform apply
terraform destroy   # when done - the code is the real thing, resources are disposable
```

## Lessons learned so far

- `init -> plan -> apply -> destroy` is the core loop
- Read the plan summary line before every apply (`X to add, Y to change, Z to destroy`) — a wrong number always tells you what's really in play
- Resource references (`azurerm_subnet.web.id`) wire resources together; Terraform derives build order from them
- The state file is Terraform's memory — never edit or commit it; remote state in Azure Storage adds locking via blob leases
- A module is just a folder of .tf files with inputs and outputs: variables.tf = the questions, main.tf = the blueprint, outputs.tf = the receipts
- Moving resources into a module breaks direct references — root must read them via `module.<name>.<output>`
- azurerm provider 5.x does not auto-register Azure resource providers: `409 MissingSubscriptionRegistration` means run `az provider register --namespace Microsoft.X` once per subscription
- Always read the error code after the HTTP status: `409 MissingSubscriptionRegistration` (provider switch off), `409 SkuNotAvailable` (size out of stock) and `400 InvalidParameter` (typo) need three different fixes
- Trial subscriptions are blocked from many VM families — check `az vm list-skus --location <region> --all` before guessing sizes
- A VM is never one resource: it's a small pile (public IP, NSG, NIC, association, VM) wired together by references
- Changing backend configuration means re-running `terraform init` (use `-migrate-state` to carry existing state over)

## Roadmap

Done: Linux VM in the `web` subnet, remote state in Azure Storage with locking, reusable module stamping out dev and prod environments, Azure SQL database per environment with secrets kept out of git. Next up: security hardening (Key Vault, NSG restrictions, RBAC), then a GitHub Actions CI/CD pipeline.
