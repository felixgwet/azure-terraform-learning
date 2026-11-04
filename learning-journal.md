# Building an Azure Environment with Terraform: Lessons 1 and 2

Building a complete Azure environment with Terraform, documented as I go. These lessons start with the core building blocks of a Terraform config and build up to the network skeleton that everything else will live in.

## Lesson 1: the core blocks

main.tf:

```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "PASTE-YOUR-SUBSCRIPTION-ID-HERE"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-terraform-learn"
  location = "uksouth"

  tags = {
    Environment = "learning"
    ManagedBy   = "terraform"
  }
}
```

**terraform {} block** - the settings for Terraform itself. "required_providers" tells it to download the azurerm plugin from HashiCorp, version 5.x. required_version is just the minimum Terraform version my config will run on.

**provider "azurerm"** - a provider is the translator between Terraform and Azure's API. This block configures that plugin, telling it which subscription to talk to. The empty features {} block looks odd, but it is necessary. It's where Azure specific lifecycle behaviour gets toggled.

**resource block** - the actual thing you want to exist. Read it as "an Azure resource group which I'll call main inside my code, named rg-terraform-learn in Azure, in UK South". The main label is only for Terraform's internal references, the name is what Azure sees.

Tags are basically sticky notes on the resource. Useful later for filtering and cost tracking.

## Lesson 2: terraform init and plan

Launched Terraform with terraform init in the VS Code terminal. init downloads the azurerm plugin (the translator from lesson 1) and sets up the working directory. Nothing touches Azure yet.

Then terraform plan, the dry run. It compares my code against what actually exists in Azure and shows me what it would do without doing any of it.

The output starts with a legend explaining the symbols. A "+" in front of a line means this will be created.

```text
Terraform will perform the following actions:

  # azurerm_resource_group.main will be created
  + resource "azurerm_resource_group" "main" {
      + id       = (known after apply)
      + location = "uksouth"
      + name     = "rg-terraform-learn"
      + tags     = {
          + "Environment" = "learning"
          + "ManagedBy"   = "terraform"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

It will create azurerm_resource_group.main, with "main" being the nickname from my code. The details of the new group are in the + resource block underneath: it will live in UK South and its real name in Azure will be rg-terraform-learn. The id says "(known after apply)" because Azure only generates that once the thing actually exists.

The summary line at the bottom: 1 to add, 0 to change, 0 to destroy. That's the line to check every time before applying anything.

The environment and managedby tags come through exactly as I wrote them. Sticky notes doing their job.

## Lesson 3: terraform apply and checking the portal

Ran terraform apply. It shows the same plan again, asks you to confirm, and then actually does it. Typed yes, and the resource group was created.

New files showed up in the folder after this, including terraform.tfstate. That one deserves its own notes, so it's the next lesson.

Then I went to the Azure portal to see it with my own eyes. rg-terraform-learn is there, sitting in UK South, exactly the name from my code. The main nickname stayed behind in Terraform, like it should.

The tags came through as well: Environment: learning and ManagedBy: terraform, both visible in the portal. The sticky notes made the trip.

No resources inside it yet, which is right. A resource group is just the container, and I haven't told Terraform to put anything in it. That's the next step.

One thing that clicked here: the plan said the id was "(known after apply)", and now the group exists with a real Azure-generated ID. That's the apply doing its job, turning the plan into something real.

## Lesson 4: the state file, Terraform's memory

terraform.tfstate is Terraform's memory. After apply, it wrote down what it created, the resource group, along with the ID Azure gave it. It's basically a notebook of everything Terraform has built.

Two rules with this file: never edit it by hand, and never delete it. If Terraform loses this notebook, it forgets what it built and can't manage those resources any more. The resources would still exist in Azure, but Terraform would have no idea they're its.

This is also what makes plan work. When I next run terraform plan, Terraform reads this notebook and compares three things: what my code says, what I built last time, and what actually exists in Azure right now. Then it computes the diff, and that diff is the plan.

So the loop from here is: change the code, plan reads the notebook and shows the diff, apply makes it real and updates the notebook.

(Also worth repeating: this file does not get committed to git. It can hold sensitive values, and it's a local working file, not source code.)

## Lesson 5: variables, or labelled boxes

Right now my main.tf has three values hard-coded: the location, the resource group name, and the environment tag. That works today, but it won't scale. Values like location are going to show up in other places as the environment grows (network, VMs, all of it). Writing the same thing in 10 different locations means changing one means changing the other 9, and if I miss one, I've got a broken environment.

The fix is labelled boxes that I define once at the top of the project. I won't write "uksouth" directly any more, I'll write "whatever is in the box labelled location". Change the box's contents once, and every resource that reads from it updates.

So I've created a variables.tf file (a separate file, keeps main.tf clean) and started defining the boxes:

```hcl
variable "location" {
  type        = string
  default     = "uksouth"
  description = "Which Azure region everything goes in"
}

variable "resource_group_name" {
  type        = string
  default     = "rg-terraform-learn"
  description = "Name of the resource group"
}

variable "environment" {
  type        = string
  default     = "learning"
  description = "Environment tag value"
}
```

Reading one of these back:

- `variable "location"` means I'm creating a box labelled "location".
- `type = string` means this box only holds text. Other types exist too, like number and bool (true/false), so a box can refuse the wrong kind of contents.
- `default = "uksouth"` means if nobody inputs otherwise, the box contains this region.
- `description` is just a note to keep things organised. Future me will thank present me.

The boxes are defined, but main.tf still has the hard-coded values in it. Next step is swapping them out for references to the boxes, so the resource group reads its name and location from variables instead of strings I typed by hand.

## Lesson 6: reaching into the boxes

Did the swap. Edited the resource block in main.tf so it reaches into the boxes instead of holding hard-coded values. The resource group now reads like this:

```hcl
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

The syntax is var.thelabel. So var.resource_group_name means "whatever is in the box labelled resource_group_name". Three strings gone, three box references in.

One I deliberately left alone: ManagedBy = "terraform" stays hard-coded. That value should never change, everything in this project is managed by Terraform by definition, so there's no box needed for it. Boxes are for values that might change or get reused, not for constants.

Worth noting: no quotes around the var references. "var.location" in quotes would be the literal text, var.location without quotes is the box lookup.

## Lesson 7: outputs, or the receipt

An output is me telling Terraform: after applying, print this specific value to my terminal. Like a receipt after a purchase, letting me know what I got. Specifically, it's how I make Terraform hand over that mysterious ID, the one the plan kept calling "(known after apply)".

Created an outputs.tf file, same pattern as variables.tf, separate file, main.tf stays clean:

```hcl
output "resource_group_id" {
  value       = azurerm_resource_group.main.id
  description = "The full Azure ID of the resource group"
}

output "resource_group_location" {
  value       = azurerm_resource_group.main.location
  description = "Where the resource group lives"
}
```

Reading the first one: `output "resource_group_id"` is creating a receipt line called resource_group_id. The value line is the new syntax bit: `azurerm_resource_group.main.id` means "from that resource, give me its id attribute".

Breaking that down:

- `azurerm_resource_group` is what kind of thing it is
- `main` is the nickname (there's the label from lesson 1 doing its job)
- `.id` is which attribute I want off it. Could just as easily be .name, .location, .tags, whatever the resource has

I added a second receipt line for the location too, cheap to do and handy to see. After the next apply, both print to the terminal, and I can pull them up again any time with terraform output.

## Lesson 8: the network skeleton

Time to build the network skeleton that all future resources (VMs, databases, whatever comes next) will live in. This is the first real piece of the environment beyond the container.

Created network.tf for it. The project files now have a clear split: main.tf is the core, variables.tf is the inputs, outputs.tf is the receipts, network.tf is the networking. Terraform doesn't care which file what lives in, it reads them all together, this split is for human organisation. Makes things easy to find months later.

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-terraform-learn"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name                 = "web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "database" {
  name                 = "database"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}
```

What it does:

- `azurerm_virtual_network` creates our private network, the neighbourhood to our subnet streets. The address range 10.0.0.0/16 gives 65,536 addresses. Big on purpose, it leaves room to grow.
- The two `azurerm_subnet` blocks divide the network into streets: web (10.0.1.0/24, 256 addresses) and database (10.0.2.0/24). (Small print: Azure reserves 5 addresses per street for itself, so it's 251 usable in practice.) The security boundaries come later, that's where I'll get to say things like "database only accepts traffic from web".
- `resource_group_name = azurerm_resource_group.main.name` is saying: take the name fact off the resource group's fact sheet. Same reference syntax as the outputs lesson. Terraform sees these links and builds resources in the right order automatically, resource group first, then the VNet, then the subnets. I never told it that order, it worked it out from the references.

One inconsistency I've spotted in my own code: the VNet name is hard-coded ("vnet-terraform-learn") while the location comes from a box. Lesson 5 me would say that name belongs in variables.tf. Leaving it for now, but noting it.

## Lesson 9: the first failure, resource provider not registered

Ran the apply for the network skeleton and it failed. First proper error of the project. The VNet wouldn't create because my Microsoft network switch was off, Azure's words were "the resource provider isn't registered".

What's actually going on: every service family in Azure (networking, compute, storage, and so on) sits behind a switch on your subscription called a resource provider. A new subscription doesn't have them all on. The azurerm provider 5.x doesn't auto-register them for you, so the first time you use a service family on a new subscription, the switch is off and the apply bounces.

The error signature to recognise: **409 MissingSubscriptionRegistration**.

The fix is a one-time command, flick the switch for networking:

```powershell
az provider register --namespace Microsoft.Network
```

Once that finished, the apply went through and the VNet and both subnets landed. You can check a switch's state any time with `az provider show --namespace Microsoft.Network --query registrationState`, it should say Registered.

Lesson learned: new subscription plus first time using a service family equals run the register command once. Storage and compute may need the same treatment when I get to them (Microsoft.Storage, Microsoft.Compute), so that's the first thing I'll check if an apply bounces with a 409.

TLDR: azurerm provider 5.x doesn't auto-register Azure resource providers. New subscription + first time using a service family = run `az provider register --namespace Microsoft.X` once. Error signature: 409 MissingSubscriptionRegistration.
