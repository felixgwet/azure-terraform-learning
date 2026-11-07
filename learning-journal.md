# Terraform Azure Journey

# Building an Azure Environment with Terraform

Building a complete Azure environment with Terraform, documented as I go. These lessons start with the core building blocks of a Terraform config and build up to the first real machine living in the network.

## Lesson 1: the core blocks

main.tf:

``` hcl
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

**terraform {} block** - the settings for Terraform itself. “required_providers” tells it to download the azurerm plugin from HashiCorp, version 5.x. required_version is just the minimum Terraform version my config will run on.

**provider “azurerm”** - a provider is the translator between Terraform and Azure’s API. This block configures that plugin, telling it which subscription to talk to. The empty features {} block looks odd, but it is necessary. It’s where Azure specific lifecycle behaviour gets toggled.

**resource block** - the actual thing you want to exist. Read it as “an Azure resource group which I’ll call main inside my code, named rg-terraform-learn in Azure, in UK South”. The main label is only for Terraform’s internal references, the name is what Azure sees.

Tags are basically sticky notes on the resource. Useful later for filtering and cost tracking.

![main.tf in VS Code](lesson1-main-tf.png)

## Lesson 2: terraform init and plan

Launched Terraform with terraform init in the VS Code terminal. init downloads the azurerm plugin (the translator from lesson 1) and sets up the working directory. Nothing touches Azure yet.

Then terraform plan, the dry run. It compares my code against what actually exists in Azure and shows me what it would do without doing any of it.

The output starts with a legend explaining the symbols. A “+” in front of a line means this will be created.

``` text
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

It will create azurerm_resource_group.main, with “main” being the nickname from my code. The details of the new group are in the + resource block underneath: it will live in UK South and its real name in Azure will be rg-terraform-learn. The id says “(known after apply)” because Azure only generates that once the thing actually exists.

The summary line at the bottom: 1 to add, 0 to change, 0 to destroy. That’s the line to check every time before applying anything.

The environment and managedby tags come through exactly as I wrote them. Sticky notes doing their job.

## Lesson 3: terraform apply and checking the portal

Ran terraform apply. It shows the same plan again, asks you to confirm, and then actually does it. Typed yes, and the resource group was created.

New files showed up in the folder after this, including terraform.tfstate. That one deserves its own notes, so it’s the next lesson.

![terraform apply in the VS Code terminal](lesson3-terraform-apply.png)

Then I went to the Azure portal to see it with my own eyes. rg-terraform-learn is there, sitting in UK South, exactly the name from my code. The main nickname stayed behind in Terraform, like it should.

The tags came through as well: Environment: learning and ManagedBy: terraform, both visible in the portal. The sticky notes made the trip.

No resources inside it yet, which is right. A resource group is just the container, and I haven’t told Terraform to put anything in it. That’s the next step.

One thing that clicked here: the plan said the id was “(known after apply)”, and now the group exists with a real Azure-generated ID. That’s the apply doing its job, turning the plan into something real.

![rg-terraform-learn in the Azure portal](lesson3-azure-portal.png)

## Lesson 4: the state file, Terraform’s memory

terraform.tfstate is Terraform’s memory. After apply, it wrote down what it created, the resource group, along with the ID Azure gave it. It’s basically a notebook of everything Terraform has built.

Two rules with this file: never edit it by hand, and never delete it. If Terraform loses this notebook, it forgets what it built and can’t manage those resources any more. The resources would still exist in Azure, but Terraform would have no idea they’re its.

This is also what makes plan work. When I next run terraform plan, Terraform reads this notebook and compares three things: what my code says, what I built last time, and what actually exists in Azure right now. Then it computes the diff, and that diff is the plan.

So the loop from here is: change the code, plan reads the notebook and shows the diff, apply makes it real and updates the notebook.

(Also worth repeating: this file does not get committed to git. It can hold sensitive values, and it’s a local working file, not source code.)

## Lesson 5: variables, or labelled boxes

Right now my main.tf has three values hard-coded: the location, the resource group name, and the environment tag. That works today, but it won’t scale. Values like location are going to show up in other places as the environment grows (network, VMs, all of it). Writing the same thing in 10 different locations means changing one means changing the other 9, and if I miss one, I’ve got a broken environment.

The fix is labelled boxes that I define once at the top of the project. I won’t write “uksouth” directly any more, I’ll write “whatever is in the box labelled location”. Change the box’s contents once, and every resource that reads from it updates.

So I’ve created a variables.tf file (a separate file, keeps main.tf clean) and started defining the boxes:

``` hcl
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

-   `variable "location"` means I’m creating a box labelled “location”.
-   `type = string` means this box only holds text. Other types exist too, like number and bool (true/false), so a box can refuse the wrong kind of contents.
-   `default = "uksouth"` means if nobody inputs otherwise, the box contains this region.
-   `description` is just a note to keep things organised. Future me will thank present me.

The boxes are defined, but main.tf still has the hard-coded values in it. Next step is swapping them out for references to the boxes, so the resource group reads its name and location from variables instead of strings I typed by hand.

![variables.tf alongside main.tf in VS Code](lesson5-variables.png)

## Lesson 6: reaching into the boxes

Did the swap. Edited the resource block in main.tf so it reaches into the boxes instead of holding hard-coded values. The resource group now reads like this:

``` hcl
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

The syntax is var.thelabel. So var.resource_group_name means “whatever is in the box labelled resource_group_name”. Three strings gone, three box references in.

One I deliberately left alone: ManagedBy = “terraform” stays hard-coded. That value should never change, everything in this project is managed by Terraform by definition, so there’s no box needed for it. Boxes are for values that might change or get reused, not for constants.

Worth noting: no quotes around the var references. “var.location” in quotes would be the literal text, var.location without quotes is the box lookup.

![main.tf using var references](lesson6-var-references.png)

## Lesson 7: outputs, or the receipt

An output is me telling Terraform: after applying, print this specific value to my terminal. Like a receipt after a purchase, letting me know what I got. Specifically, it’s how I make Terraform hand over that mysterious ID, the one the plan kept calling “(known after apply)”.

Created an outputs.tf file, same pattern as variables.tf, separate file, main.tf stays clean:

``` hcl
output "resource_group_id" {
  value       = azurerm_resource_group.main.id
  description = "The full Azure ID of the resource group"
}

output "resource_group_location" {
  value       = azurerm_resource_group.main.location
  description = "Where the resource group lives"
}
```

Reading the first one: `output "resource_group_id"` is creating a receipt line called resource_group_id. The value line is the new syntax bit: `azurerm_resource_group.main.id` means “from that resource, give me its id attribute”.

Breaking that down:

-   `azurerm_resource_group` is what kind of thing it is
-   `main` is the nickname (there’s the label from lesson 1 doing its job)
-   `.id` is which attribute I want off it. Could just as easily be .name, .location, .tags, whatever the resource has

I added a second receipt line for the location too, cheap to do and handy to see. After the next apply, both print to the terminal, and I can pull them up again any time with terraform output.

![outputs.tf and variables.tf in VS Code](lesson7-outputs.png)

## Lesson 8: the network skeleton

Time to build the network skeleton that all future resources (VMs, databases, whatever comes next) will live in. This is the first real piece of the environment beyond the container.

Created network.tf for it. The project files now have a clear split: main.tf is the core, variables.tf is the inputs, outputs.tf is the receipts, network.tf is the networking. Terraform doesn’t care which file what lives in, it reads them all together, this split is for human organisation. Makes things easy to find months later.

``` hcl
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

-   `azurerm_virtual_network` creates our private network, the neighbourhood to our subnet streets. The address range 10.0.0.0/16 gives 65,536 addresses. Big on purpose, it leaves room to grow.
-   The two `azurerm_subnet` blocks divide the network into streets: web (10.0.1.0/24, 256 addresses) and database (10.0.2.0/24). (Small print: Azure reserves 5 addresses per street for itself, so it’s 251 usable in practice.) The security boundaries come later, that’s where I’ll get to say things like “database only accepts traffic from web”.
-   `resource_group_name = azurerm_resource_group.main.name` is saying: take the name fact off the resource group’s fact sheet. Same reference syntax as the outputs lesson. Terraform sees these links and builds resources in the right order automatically, resource group first, then the VNet, then the subnets. I never told it that order, it worked it out from the references.

One inconsistency I’ve spotted in my own code: the VNet name is hard-coded (“vnet-terraform-learn”) while the location comes from a box. Lesson 5 me would say that name belongs in variables.tf. Leaving it for now, but noting it.

![network.tf in VS Code](lesson8-network.png)

## Lesson 9: the first failure, resource provider not registered

Ran the apply for the network skeleton and it failed. First proper error of the project. The VNet wouldn’t create because my Microsoft network switch was off, Azure’s words were “the resource provider isn’t registered”.

What’s actually going on: every service family in Azure (networking, compute, storage, and so on) sits behind a switch on your subscription called a resource provider. A new subscription doesn’t have them all on. The azurerm provider 5.x doesn’t auto-register them for you, so the first time you use a service family on a new subscription, the switch is off and the apply bounces.

The error signature to recognise: **409 MissingSubscriptionRegistration**.

The fix is a one-time command, flick the switch for networking:

    az provider register --namespace Microsoft.Network

Once that finished, the apply went through and the VNet and both subnets landed. You can check a switch’s state any time with `az provider show --namespace Microsoft.Network --query registrationState`, it should say Registered.

Lesson learned: new subscription plus first time using a service family equals run the register command once. Storage and compute may need the same treatment when I get to them (Microsoft.Storage, Microsoft.Compute), so that’s the first thing I’ll check if an apply bounces with a 409.

TLDR: azurerm provider 5.x doesn’t auto-register Azure resource providers. New subscription + first time using a service family = run `az provider register --namespace Microsoft.X` once. Error signature: 409 MissingSubscriptionRegistration.

## Lesson 10: the first machine (compute.tf)

The network skeleton is up, time to put a machine in it. New file, compute.tf, keeping the split: main.tf is core, variables.tf is inputs, outputs.tf is receipts, network.tf is networking, compute.tf is the VM and everything it needs to exist.

A VM in Azure is not one resource, it is a small pile of them. The pieces:

**The VM itself.** Ubuntu Linux. Reasons: it is cheap, it boots in seconds on a small size, and you manage it over SSH and the command line, which is the industry norm for servers. Also, most cloud VMs run Linux (around 70 percent), so this is the skill that matters.

**The network interface (NIC).** The VM’s network card. A VM cannot touch a subnet directly, the NIC is the cable that plugs it into the web subnet. Everything network related hangs off the NIC, not the VM.

**The public IP.** A front door address on the internet, attached to the NIC so I can reach the VM from my PC. Without it the VM only has its private 10.0.1.x address, reachable from inside the network only.

**The network security group (NSG).** The firewall. One rule only: allow SSH in on port 22, everything else stays blocked. Port 22 is the door number for SSH, the protocol for securely controlling a remote machine’s command line, which is exactly what I need to do. Port 3389 would be RDP for Windows remote desktop, not needed here. Ports 80 and 443 are for web traffic, which this VM does not serve yet, those get added the day I install a web server.

One detail worth noting: the firewall does not attach to the VM, it attaches to the NIC, through a separate association resource. Firewall clips onto the cable, not the computer.

The code (the visible parts):

``` hcl
# the one NSG rule, inside azurerm_network_security_group "web"
security_rule {
  # ...
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-terraform-learn"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_linux_virtual_machine" "main" {
  name = "vm-terraform-learn"
  # ...
}
```

Two things worth noticing in there. The NIC pulls its subnet and public IP off other resources’ fact sheets (azurerm_subnet.web.id, azurerm_public_ip.vm.id), same reference pattern as always. And the NSG does not attach inside the NIC block or the NSG block, it gets its own association resource gluing the two together. Terraform treats the wiring as a thing in its own right.

### Least exposure

The principle behind the single rule: every open port is a door an attacker can try. A server with 10 open ports has 10 doors. Ours has one.

### The key

In the VS Code terminal: `ssh-keygen -t ed25519`. Reading it back: ssh-keygen is “make me a key pair”, -t ed25519 is “of type ed25519”. Why that type: it is modern, the keys are short, it is fast, and it has been the recommended default since 2020. The old workhorse is `-t rsa -b 4096`, but RSA keys are huge and slower, and that option is really for ancient systems now.

The pair matters: a public key goes on the VM, the private key stays on my PC. Password login is disabled entirely, the key is the only way in.

### The star, and why it is a calculated risk

The NSG rule’s source is `"*"`, and it is worth understanding what the source fields actually mean, because they are about the caller, the computer trying to reach the VM:

-   `source_address_prefix` is WHERE the caller is calling from. `"*"` means any IP in the world.
-   `source_port_range` is which line the caller is using to place the call. When my PC calls out, it grabs a random high number as its line for that one conversation, so it can hold hundreds of connections at once without mixing them up. So the VM answers on 22, and the replies come back to something like 52341 on my end.

Reading the whole rule back in one sentence: allow any caller (source_address_prefix = “*”), calling from whatever line they happen to use (source_port_range = ”*”), to reach port 22 on our side (destination_port_range = “22”).

Leaving the source as `"*"` is not ideal. Bots scan the internet constantly, and they will find the VM and start trying to log in within minutes, you can watch them in the logs. It is acceptable here for one reason only: password login is disabled and the private key is the only way in. The door is visible, but it is vaulted shut. Trying is all they can do.

The proper fix, when it matters: replace `"*"` with my home IP, something like 86.143.22.9/32 (example address). Then the door is invisible to everyone except me.

![compute.tf in VS Code](lesson10-compute.png)

## Lesson 11: the plan before the machine

Before applying compute.tf, ran terraform plan. Two things in the output worth writing down, and one hygiene note.

**The refresh.** The first four lines of the output are “Refreshing state” against the four existing resources: the resource group, the virtual network, and the web and database subnets. That is everything from lessons 1 and 8. Refreshing means Terraform is re-reading the real world and updating its notebook (lesson 4) before it computes anything. The 4 are not being changed, they are being checked.

**The diff.** The summary line: `Plan: 5 to add, 0 to change, 0 to destroy.` The 5 are exactly the pile from lesson 10: the VM, the NIC, the public IP, the NSG, and the association that clips the firewall to the cable. Nothing existing gets touched.

Three details from the body of the plan:

-   In the VM block: `ssh-ed25519 AAAA... user1@DESKTOP-NQGM9HQ`. My public key, read off disk correctly by the admin_ssh_key block. The private half never leaves my PC.
-   In the NIC block: `subnet_id = "/subscriptions/.../resourceGroups/rg-terraform-learn/.../subnets/web"`. The reference azurerm_subnet.web.id has solved into a real Azure resource ID. The whole chain works: VM points at NIC, NIC points at subnet, subnet points at VNet, VNet points at the resource group. Terraform worked out the build order from those links, just like lesson 8 said it would.
-   In the outputs: `+ vm_public_ip = (known after apply)`. Added a new receipt line for the front door address, same pattern as lesson 7. After apply, the real public IP prints to the terminal.

Hygiene note to self: Azure resource IDs contain the subscription ID, so plan output gets that part masked before it goes anywhere public, this log included.

Next: the apply. Five resources, one machine, and a receipt with my front door address on it.

## Lesson 12: the same 409, a different switch

Ran terraform apply for the compute pile and typed yes. Got to watch the dependency order from lesson 8 happen live first: the NSG and the public IP created at the same time (they only need the resource group), then the NIC (needs the subnet and the public IP), then the association (needs the NIC and the NSG), and the VM went last, because it needs everything else to exist first.

Then it bounced. Error: 409 MissingSubscriptionRegistration. The exact same error as lesson 9, just a different switch: this time the namespace that is not registered is Microsoft.Compute, not Microsoft.Network. Lesson 9 literally said “storage and compute may need the same treatment when I get to them”, and here we are. Called it.

The fix is the same one simple command, different namespace:

    az provider register --namespace Microsoft.Compute

Where this leaves things: 4 of the 5 resources from the plan are built and written in the notebook (the NSG, the public IP, the NIC, the association). Only the VM is missing. Once the register command finishes, re-run apply and the plan should say 1 to add, just the VM. Nothing gets duplicated, because the notebook remembers what already exists (lesson 4).

Lesson learned, again: new subscription plus first time touching a service family equals run the register command once. The signature is the same every time, 409 MissingSubscriptionRegistration, and the error message names the exact namespace to register. No guessing.

![the apply, four resources up then the 409](lesson12-apply-error.png)

## Lesson 13: the shop is out of stock (SkuNotAvailable)

Registered the compute switch, re-ran apply, and the plan said exactly what lesson 12 predicted: 1 to add, just the VM. Typed yes. New error.

The message that matters this time: SkuNotAvailable: The requested VM size ‘Standard_B1s’ is currently not available in location ‘uksouth’.

Translation: Azure’s UK South datacentre has run out of spare capacity for the B1s size specifically. My code is fine, the shop is just out of stock on that shelf. This happens with the cheapest sizes, because everyone wants them.

Important note: this is the same HTTP status as lesson 12 (409), but a completely different cause. Always read the error code that comes after the status, SkuNotAvailable vs MissingSubscriptionRegistration. The status code alone tells you nothing.

The fix: pick a size that is in stock. Went into compute.tf and changed size = “Standard_B1s” to size = “Standard_B2s”, ran apply again. Same error. B2s is out of stock in uksouth too.

Next attempt: size = “Standard_B2ats_v2”. Except there was a typo detour before I even got the spelling right (next lesson), and the size hunt turned out to be nowhere near over (the lesson after that).

Note to self: there is a way to check the shelves before guessing. `az vm list-skus --location uksouth --size Standard_B --all --output table` shows which B sizes the subscription can actually get in that region (check the restrictions column). Doing that first next time, instead of trial and error.

![the B1s out of stock error](lesson13-sku-b1s.png)

![the B2s out of stock error, same shelf empty](lesson13-sku-b2s.png)

## Lesson 14: the typo in between, size names are exact

Honest footnote to lesson 13. Between B2s failing and the correctly spelled B2ats_v2 attempt, I made a mistake and typed the size wrong.

In compute.tf I put size = “Standard_B2ats/v2 family”. That is not a size name, that is the family description I had written down, copied straight in without thinking. Azure’s reply was a new flavour of error again:

400 Bad Request, InvalidParameter: The value Standard_B2ats/v2 family provided for the VM size is not valid.

So not out of stock this time, just not a real thing. Size names are exact strings: Standard_B2ats_v2. No slashes, no spaces, no “family” on the end, it is underscores all the way.

The useful part of this error: it lists every valid size in the region after the complaint, hundreds of them. The fix was literally inside the error message, I just had to read it and copy one exactly.

Also worth noting: terraform plan did not catch this. To Terraform the size is just a string, it has no idea what sizes exist. Only Azure knows, and it only gets asked at apply time. So a plan with no complaints is not a guarantee, it just means the shape of the code is right.

The running tally for the project so far: 409 MissingSubscriptionRegistration (switch was off), 409 SkuNotAvailable (out of stock), 400 InvalidParameter (my typo). Three failures, three different causes, same lesson every time: the bit after the status code is the bit to read.

Corrected compute.tf, full VM block visible: the key read off disk with file(pathexpand(“\~/.ssh/id_ed25519.pub”)), the disk settings, the Ubuntu image reference, and the receipt line for the public IP at the bottom (“this is what you SSH to”).

![the corrected compute.tf with the exact size name](lesson14-size-fix.png)

## Lesson 15: the size hunt, or how a trial subscription boxes you in

The full story of what lessons 13 and 14 were actually part of. The tally: 12 applies, 9 different sizes, 2 regions, 1 typo. Every single one red, until the very last one.

| \#  | Size tried                             | Region  | Result                                |
|-----|----------------------------------------|---------|---------------------------------------|
| 1   | Standard_B1s                           | uksouth | SkuNotAvailable                       |
| 2   | Standard_B2s                           | uksouth | SkuNotAvailable                       |
| 3   | Standard_B2ats/v2 family               | uksouth | InvalidParameter (my typo, lesson 14) |
| 4   | Standard_B2ats_v2                      | uksouth | SkuNotAvailable                       |
| 5   | Standard_D2s_v3                        | uksouth | SkuNotAvailable                       |
| 6   | Standard_D2as_v5                       | uksouth | SkuNotAvailable                       |
| 7   | Standard_D2s_v5                        | uksouth | SkuNotAvailable                       |
| 8   | Standard_B2ms                          | uksouth | SkuNotAvailable                       |
| 9   | Standard_A2_v2                         | uksouth | BadRequest                            |
| 10  | (region moved to ukwest, one variable) |         |                                       |
| 11  | Standard_B2s                           | ukwest  | SkuNotAvailable                       |
| 12  | Standard_D2als_v7                      | ukwest  | **Apply complete**                    |

**The region move.** At one point the theory was “uksouth is just dry, try another region”. The move itself was one line: edit variables.tf, set default = “ukwest”, save, terraform plan. That is lesson 5 paying for itself, one box changed and the whole environment planned to move. The results were the same though, B2s bounced in ukwest too. Region was never the real problem.

Side effect of the move, noticed after the fact: the whole environment now lives in ukwest, built by Terraform from the same code that built uksouth. That is the reproducibility test from the roadmap, passed by accident. Same code, different region, whole network back up.

**The real discovery.** This is a trial subscription. Trial subs are blocked from many VM families, and the only unrestricted ones available to me were the newer v7 families. First v7 attempt, Standard_D2als_v7, went straight through.

**For future reference:** trial subscription blocked from many families. The fix is either an allowed size (v7 here) or a quota increase request through support.

**The reflection, because it matters.** This was probably the most exhaustive part of the project so far, but it was never a knowledge or learning problem. The code was right the entire time (one typo aside). It was account restrictions the whole way, and no amount of studying fixes that. Knowing the difference between “I got this wrong” and “the platform said no” is its own skill.

**And a coda for lesson 13’s note to self.** The az vm list-skus command would have been genuinely useful here for once: on a restricted subscription, run it first with –all and only shortlist sizes whose Restrictions column is empty. It still cannot see live capacity, but it can see a locked door, and a trial subscription is a corridor full of locked doors.

![the full size hunt table](lesson15-size-hunt.png)

## Lesson 16: first contact, SSH into the machine

**Getting the address.** terraform output vm_public_ip, and there it was. The “(known after apply)” from lesson 11 is now known. This is what the outputs.tf block was for: Terraform captured the value at apply time and stored it in the notebook, and terraform output re-reads the receipt any time without touching Azure. We need this address because it is the front door we are about to knock on with SSH.

**Knocking.** ssh azureuser@ the receipt. Reading that back: connect as azureuser (the admin account we declared in code), to the public IP, through port 22 of course, the one NSG rule we opened. No password gets typed. The SSH client proves it holds the private key that matches the public key we installed on the VM.

First knock actually got “Connection closed by … port 22”. Most likely the VM was still finishing its first boot: apply saying complete means Azure finished building the machine, not that Ubuntu had finished waking up. Second knock, straight in.

The yes prompt on the way in: SSH saying “first contact, remember this machine’s identity so you can detect impostors later”. The fingerprint gets saved into known_hosts, and if a different machine ever answers at this address in future, SSH will scream about it.

**Verification, three commands:**

-   whoami said azureuser. The login worked, and we are the account we declared in code.
-   hostname said vm-terraform-learn. Our machine, not some random server.
-   ip addr is the big one. eth0 is the VM’s network card, the azurerm_network_interface block we wrote, and it shows inet 10.0.1.4/24. An address off our web street. Why .4: Azure reserves 5 addresses per subnet, .0 is the network itself, .1 the gateway, .2 and .3 DNS, .255 broadcast, so .4 is the first house number a machine can actually take. Our VM got house number 4 on the street we designed back in lesson 8.

The login banner spoils it before you even run anything: “IPv4 address for eth0: 10.0.1.4”. Then exit, and I am back on my own machine.

The terminal, trimmed (real public IP masked, this log goes public):

``` text
PS C:\terraform\lesson1> ssh azureuser@<masked>
Welcome to Ubuntu 24.04.5 LTS (GNU/Linux 7.0.0-1017-azure x86_64)
  IPv4 address for eth0: 10.0.1.4

azureuser@vm-terraform-learn:~$ whoami
azureuser
azureuser@vm-terraform-learn:~$ hostname
vm-terraform-learn
azureuser@vm-terraform-learn:~$ ip addr
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    inet 10.0.1.4/24 metric 100 brd 10.0.1.255 scope global eth0
azureuser@vm-terraform-learn:~$ exit
```

The summary of the whole compute arc: a VM is never one resource, it is five blocks wired together by references (public IP, firewall, NIC, association, machine), and SSH keys are how you prove identity without passwords.

![the receipt, the first knock getting closed, and the yes prompt](lesson16-first-ssh.png)

## Lesson 17: the notebook moves to Azure (remote state and locking)

So the notebook (terraform.tfstate) has been living only on my device this whole time. Everything so far worked, but if I lose that file, Terraform forgets everything it has ever built, and the whole inventory from lesson 4 dies with it. Time to give it a proper home: Azure Storage. Backed up, shareable, and locked. The locked part matters more than it sounds: two people cannot run apply at the same time and corrupt the file. The azurerm backend takes a lease on the state blob for the whole operation, so a second apply has to wait its turn instead of trampling the first one.

**Why az and not Terraform for this bit.** Chicken and egg. Terraform needs the storage to exist before it can store anything there, so the state’s home is the one thing Terraform cannot build for itself. Four commands did it:

<div id="cb11" class="sourceCode">

``` sourceCode
az provider register --namespace Microsoft.Storage
az group create --name rg-terraform-state --location ukwest
az storage account create --name tfstatelearn1990 --resource-group rg-terraform-state --sku Standard_LRS
az storage container create --name tfstate --account-name tfstatelearn1990
```

</div>

First line is lessons 1 and 12 paying off again: register the provider before Azure throws the 409 at me. Storage account names have rules: globally unique across all of Azure, lowercase, no dashes allowed at all, which is why digits do the heavy lifting. tfstatelearn1990 it is. Standard_LRS means locally redundant copies, cheapest option, fine for a notebook. The container command printed a warning about no credentials in the command, then quietly queried the account key by itself and answered “created”: true.

**Pointing Terraform at it.** Back in main.tf, inside the terraform block, above required_providers:

``` hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "tfstatelearn1990"
  container_name       = "tfstate"
  key                  = "lesson1.tfstate"
}
```

![the backend block above required_providers, subscription ID masked per lesson 11 hygiene](lesson17-backend-block.png)

Worth expanding on what this block actually is, because it sits in the same file as the resource blocks but it is not one of them. Every other block in my code describes a thing I want to exist in Azure. The backend block describes nothing in Azure at all. It is core Terraform configuration: instructions for the tool itself, telling it where the notebook lives. That is why it shares the terraform block with required_version and required_providers, which are also settings for the tool, not infrastructure. Three consequences fall out of that:

-   It creates nothing. No apply will ever build a backend, which is exactly why the storage had to be made by hand with az first.
-   It cannot use variables. Terraform reads the backend block before it has even loaded the variables, so the four values have to be typed literally. var.location in there would fail.
-   Changing it means re-running init. You changed how Terraform works, not what it manages, and Terraform itself says so in the init output: rerun this command if you ever set or change modules or backend configuration.

The key line is just the filename the notebook gets inside the container: lesson1.tfstate.

**The move.** terraform init -migrate-state. init because the backend configuration changed, and -migrate-state because there was already a local notebook to carry over rather than starting blank. The reply: “Successfully configured the backend”azurerm”!” followed by the usual “Terraform has been successfully initialized!”. The local tfstate got uploaded and the job handed over. From now on, every plan and apply reads and writes the blob in Azure, not a file on my disk.

![init -migrate-state doing the handover](lesson17-init-migrate.png)

**Check 1, the portal (visual proof).** Portal, resource group rg-terraform-state, storage account tfstatelearn1990, left menu Data storage, Containers, click tfstate. One blob sitting there: lesson1.tfstate, 20.28 KiB, block blob, Hot (inferred) tier, lease state Available. Available means nobody is mid-apply right now. The moment someone runs plan or apply, that lease flips to Leased and everyone else has to wait. The notebook has an official home, and the home has a bouncer.

![lesson1.tfstate sitting in the tfstate container](lesson17-portal-tfstate.png)

Hygiene note for future me: the tfstate contains real resource IDs and can contain secrets, which is why it never goes in git. Now it does not even live next to the code.

That is roadmap item 5 done: remote state and locking, what real teams use. Next up: the SQL database on the database street from lesson 8 (the one that only accepts traffic from web), or item 6, modules and environments.

## Lesson 18: one factory, two environments (modules)

Roadmap item 6. The idea: a module is just a folder of .tf files that takes inputs as variables and hands back outputs. The special part is you can call the same folder twice with different inputs. So I made a modules folder, and inside it an environment folder with three files: main.tf, variables.tf, outputs.tf.

![the new folder layout, module living inside the root](lesson18-folder-tree.png)

**variables.tf, the dials.** Anything that should differ between dev and prod becomes a variable here: the environment name, the location, the VM size, and the three address ranges (vnet, web subnet, database subnet). Six dials in total. And notice vm_size sitting there: VM size finally became a variable, the thing I have wanted since the great SKU hunt of lesson 15.

![the module’s dials](lesson18-module-variables.png)

**outputs.tf, the windows.** If the module is a black box, the outputs are little windows where it hands results back. “Here is the IP I built for you”, that kind of thing. Without these, the root code cannot see inside.

![the module’s windows](lesson18-module-outputs.png)

**main.tf, the blueprint.** The biggest piece. I merged the old network.tf and compute.tf and the resource group block into one file inside the module. This file is the answer to the question “what does one environment consist of?” A resource group, a VNet with a web street and a database street, a Network Security Group that only allows port 22, a public IP, a NIC, and a VM with key-only login. It is a single place where “how we build an environment at this company” is written down.

This matters because the one file gets used twice. Fix the firewall rule once, dev and prod both get the fix. Add monitoring once, dev and prod both get monitoring. Next project needs an environment, they use the same factory. Without this, the knowledge has to be copy-pasted into every folder.

The summary I keep in my head: variables.tf is the questions, main.tf is the machine that builds the answer, outputs.tf is the receipt. main.tf is the part that makes a module a module, the other two are just its front door and its letterbox.

![the blueprint, one file describing one whole environment](lesson18-module-main.png)

**Calling the factory twice.** Back in the root main.tf, the old resources get replaced by two module blocks:

``` hcl
module "dev" {
  source = "./modules/environment"

  environment     = "dev"
  vnet_cidr       = "10.0.0.0/16"
  web_subnet_cidr = "10.0.1.0/24"
  db_subnet_cidr  = "10.0.2.0/24"
  vm_size         = "Standard_D2als_v7"
}

module "prod" {
  source = "./modules/environment"

  environment     = "prod"
  vnet_cidr       = "10.1.0.0/16"
  web_subnet_cidr = "10.1.1.0/24"
  db_subnet_cidr  = "10.1.2.0/24"
  vm_size         = "Standard_D2als_v7"
}
```

![both module blocks sitting in the root main.tf](lesson18-root-main-modules.png)

Then terraform init again, because Terraform needs to install the new module into .terraform.

**The debugging, or why the plan number is a clue.** The maths first: one environment is 9 resources (resource group, VNet, two subnets, public IP, Network Security Group, the association, the NIC, the VM), so two environments should plan as 18 to add. Do not assume it is right if it is not. Double check.

-   First run said 9. One module block never made it into the file. Still not sure how, probably a paste that never landed or an unsaved buffer. Either way the plan number snitched: 9 means one environment, not two.
-   Fixed that, ran again, and now it said 27. Threw me off until I counted: 18 new from the modules, plus 9 old, because network.tf and compute.tf were still sitting in the root. Deleted both, their contents live safely inside the module now. The rule: when code moves into a module, delete the original, otherwise you are running the old design and the new design side by side. One job, one owner.
-   Also deleted the old resource group block from the root main.tf, since it lives in the module now too.
-   Then the root outputs.tf was still holding old receipts pointing at azurerm_resource_group.main.id and friends. Those addresses only work when the resource lives in the same folder. Replaced them so the receipts reach through the module windows:

``` hcl
output "dev_vm_ip" {
  value       = module.dev.vm_public_ip
  description = "Public IP of the dev environment VM"
}

output "prod_vm_ip" {
  value       = module.prod.vm_public_ip
  description = "Public IP of the prod environment VM"
}
```

module.dev.vm_public_ip reads as: the vm_public_ip receipt that the dev stamp printed.

![the old receipts, struck through](lesson18-old-outputs.png)

![the new receipts, reaching through the module windows](lesson18-new-outputs.png)

And then, finally: Plan: 18 to add, 0 to change, 0 to destroy. As desired.

![18 to add, the correct number](lesson18-plan-18.png)

**Apply.** terraform apply builds both environments in parallel. When it finished, the receipts printed dev_vm_ip and prod_vm_ip (masked here, they are real public addresses).

![apply complete, 18 added, both receipts printed](lesson18-apply-receipts.png)

**Portal check.** rg-dev and rg-prod both exist in UK West now, sitting next to rg-terraform-state from lesson 17.

![both environment resource groups in the list](lesson18-portal-rgs.png)

Each one holds a full stack: NIC, Network Security Group, public IP, VM, disk, VNet. Identical in both. And vnet-prod shows address space 10.1.0.0/16, exactly what the prod module block ordered.

![the dev stack, full house, subscription ID masked](lesson18-rg-dev.png)

![vnet-prod wearing the prod address range, subscription ID masked](lesson18-vnet-prod.png)

One thing the portal taught me: portal rows are not Terraform resources. Six rows showed per resource group, but Terraform tracked 9 resources per environment. The subnets hide inside the VNet, the NSG association is invisible, and the VM’s disk appears as a bonus row.

Tonight I learned modules. A module is just a folder of .tf files with inputs (variables.tf) and outputs (outputs.tf), and main.tf is the blueprint itself. Writing the code does nothing, only apply builds. The win: dev and prod now come from one design, so they can never drift apart, because they are stamped from the same cutter. Six dials control everything: name, location, VM size, and three address ranges. Adding a third environment like staging would take 8 lines and 30 seconds now, not an evening. We will try that later. And my favourite part was the debugging: each time the count was wrong, the plan number itself was the clue, because Terraform counts every resource in every .tf file, so a wrong number always tells you something true about what is really in play.

That is roadmap item 6 done. Remaining: the SQL database on the database street, tightening that port 22 rule down to my home IP (promised back in lesson 10), the rest of item 7 governance (tags are in already, Key Vault and RBAC to go), and item 8, running Terraform from a pipeline.

## Lesson 19: SQL databases and the error storm (roadmap item 7, database part)

Tonight’s job was adding a SQL database to both environments. Sounded like one resource. Turned into three resources, ten errors, an accidental move to France, and the most educational evening of the whole project so far. Writing it all down while it is fresh.

### Phase 1: secrets, or how the password gets in without ending up on GitHub

The SQL server needs an admin password, and that password cannot live in any file that gets committed. The chain works like this. The password itself goes in terraform.tfvars, which is my answer sheet that never leaves the machine because .gitignore blocks it. The root variables.tf declares an empty labelled box called sql_admin_password with sensitive = true on it, so Terraform knows the box exists, knows it is secret, and refuses to print it in plans and outputs. The module call passes the value through as a dial, and the resource inside the module reads it from its own variable. Four stops: tfvars, root variables, module dial, resource.

My mistake of the evening: I wrote a description on the variable and thought I had given it a value. A description is a note, not a value. It is a label on the box, and the box is still empty. So Terraform quite rightly complained:

![terraform complaining about the missing required argument](lesson19-missing-argument.png)

Missing required argument. Fair. Filled the answer sheet in terraform.tfvars, error gone. Also worth noting the variables screenshot below: no defaults on these. A variable with no default is mandatory, which is exactly what you want for a password, because Terraform will stop and ask rather than silently inventing one.

![module variables with no defaults, mandatory boxes](lesson19-variables.png)

Then the safety check before committing: git ls-files to list everything Git is tracking, and confirm no .tfvars and no .tfstate is in the list. The .gitignore has *.tfvars,* .tfstate and .terraform/ in it. Blueprints contain dials, not answers. If a file with real answers ever shows up in git ls-files, something has gone wrong.

### Phase 2: the three SQL resources

A database in Azure is not one resource, it is three. The azurerm_mssql_server is a logical container, not an actual server anyone manages for you in the traditional sense. It owns the admin login, the firewall rules, and the address (ours became sql-terraform-learning-dev.database.windows.net). The azurerm_mssql_database is the actual database, and I set the edition to Basic because Basic is nearly free and this is a lab. The azurerm_mssql_firewall_rule decides who can talk to it.

![the mssql server block](lesson19-mssql-server.png)

Two traps I fell into so you do not have to. Trap one: the internet is full of examples using azurerm_sql_server and azurerm_sql_database. Those names are retired. They were removed in version 4.0 of the azurerm provider, so any tutorial older than that will fail with confusing errors. The modern names all start with azurerm_mssql\_. Screenshot of the trap for the wall of shame:

![the retired resource names, do not use these](lesson19-old-sql-trap.png)

Trap two: the firewall rule. Setting start_ip_address to 0.0.0.0 and end_ip_address to 0.0.0.0 is a special shorthand that means Azure services only, which is what I wanted. But if you set end_ip_address to 255.255.255.255 you have just opened your database to every IP address on Earth. Same starting octet, completely different meaning. One is a door for Azure’s own services, the other is no door at all.

### Phase 3: the error storm

Ten errors between me and a working database. Every single one taught me something, so here is the honour roll.

1.  Missing required argument (above). Description is not a value.
2.  409 MissingSubscriptionRegistration. Azure subscriptions do not come with every resource provider switched on. Microsoft.Sql was not registered, so the very first apply failed on both environments at once:

![the 409 errors, both environments refusing at once](lesson19-sql-409.png)

The fix is one line: az provider register –namespace Microsoft.Sql. One command, both errors gone, because both environments live in the same subscription.

3.  ProvisioningDisabled. This one was evil. My trial subscription is quietly blocked from creating SQL servers in ukwest, uksouth, westeurope, northeurope, eastus and westus. No warning beforehand, just a refusal at apply time. France Central and Sweden Central work. I found this out by probing regions with an empty logical SQL server, because a server with no database on it costs nothing. Free region probe.
4.  InvalidResourceLocation. The ghost registrations. My failed applies had reserved the server name in regions that then refused me, and Azure remembered. Hunting them down with az sql server list -g and deleting them one by one was not how I planned to spend the hour.
5.  PasswordNotComplex. The SQL admin password needs 8 to 128 characters and three of the four categories (lower, upper, number, symbol), and it cannot contain the username sqladmin itself. My first password failed on that last rule.
6.  Provider produced inconsistent result after apply. The scariest one of the night. Azure said the server existed, Terraform’s state said it did not. Replication lag inside Azure meant the resource was real but orphaned from my state file. In production you fix this with terraform import to adopt the orphan. In a lab you can also just nuke the resource groups and rebuild, which is what I did, but I wrote down the import command for future me.
7.  UpsertLogicalServerRequestAlreadyInProgress. I hit Ctrl+C during a long apply. The watcher stopped. The kitchen did not. Azure carried on cooking my server in the background and then refused the retry because a request was already running. Lesson: Ctrl+C stops your terminal from watching, it does not stop Azure from working.
8.  Cannot import non-existent remote object. When I tried terraform import on one of the ghosts, Terraform refused because there was nothing real to adopt. Import is adoption, not conjuring. The thing has to actually exist first.
9.  The accidental France migration. At one point I changed location in the wrong place and the plan calmly told me it was going to destroy and recreate everything in France Central, because location is a ForceNew property, you cannot edit it, only rebuild. I caught it by reading the plan, where every resource showed the minus and plus symbols of destroy and create. Then I checked az vm list-skus –location francecentral, saw my VM size works there, and committed to the move on purpose. The scar stays in the journal as a reminder: read the plan, the plan tells the truth.
10. The final rebuild said 24 to add and my heart skipped until I did the maths: 18 rebuild plus 6 new SQL resources, three per environment across two environments. Correct.

### Phase 4: victory

Apply went green on both environments. rg-dev now holds 8 resources, all in France Central, including the SQL server and the database:

![rg-dev with all 8 resources in France Central](lesson19-rg-dev-france.png)

The database itself, online, Basic tier, tagged Environment dev and ManagedBy terraform:

![sqldb-dev overview in the portal](lesson19-sql-portal.png)

Best discovery of the night: the Activity Log blade. Every resource has one, and it is a timeline of everything Azure did to that resource, including my failed attempts. The NIC’s log shows the whole story arc: Failed, Failed, Failed, then Succeeded. Like a heartbeat monitor for the evening.

![nic-prod activity log, failed then succeeded](lesson19-activity-log.png)

Then terraform destroy at the end, as always. Everything comes down, the code on GitHub is the real thing, the subscription stays empty and cheap.

The errors were the curriculum. Anyone can follow a tutorial that works. Tonight I debugged region locks, state orphans, zombie requests and a stalled subscription, and that is the actual job.

That is the database side of roadmap item 7 done. Remaining: Key Vault and RBAC to finish item 7, tightening the port 22 rule down to my home IP, the staging environment test, and item 8, running Terraform from a pipeline.

## Lesson 20: closing the doors (SSH lockdown and Key Vault)

Last lesson I deliberately left two doors open. Tonight we close them.

Door one: inside modules\environment\main.tf, the security rule on the network security group had source_address_prefix set to "*", which is telling port 22 to let visitors try the door from any address on Earth. Every bot on the internet gets a free attempt, and the only thing protecting the VM is the SSH key.

Door two: the SQL admin password lives in plain text in terraform.tfvars on my laptop. It is safe from GitHub because .gitignore blocks it, but it is still a liability. It could accidentally get synced to OneDrive, or flash up on a screen share in a call. Passwords that matter should live in a digital safe, not a notepad file.

I also spotted a third thing while I was in there: the SQL firewall rule with 0.0.0.0 to 0.0.0.0 lets any Azure customer through, not just me. Noted for later, tonight is about the two doors.

### Part 1: the allowed_ssh_ip dial

First I needed my own IP address, and here I have to own a mistake. My first instinct was ipconfig in cmd, so that is what I did, and that is the address that went into my tfvars and into the plan below. Wrong address. ipconfig shows the address of my machine inside my house, the 192.168 one the router hands out locally. Azure's NSG sits on the internet, and the internet only ever sees my router's public address. A rule pointing at 192.168.anything is a door that exists for nobody, not even for me. The correct way takes ten seconds: a simple Google search for "what is my ip" gives you your actual internet address, and that public one is what belongs in tfvars. I am leaving the wrong-IP plan screenshot in below as evidence, because this is exactly the kind of mistake that otherwise costs an hour of "why can't I SSH into my own VM" before anyone spots it.

Then, instead of typing my IP into the rule itself, I made a new dial. Bottom of modules\environment\variables.tf:

![the new allowed_ssh_ip dial in the module](lesson20-module-variable.png)

Why a dial and not surgery on the blueprint: a home IP can change (router reboots, switching providers), it is personal, and it differs per person. One labelled line beats editing the blueprint every time.

Then the actual tightening, in the security_rule block of the NSG in modules\environment\main.tf. The change is on source_address_prefix (not source_port_range, that one stays "*"):

![the tightened rule, one address only](lesson20-nsg-rule.png)

Breaking down "${var.allowed_ssh_ip}/32":

- ${var.allowed_ssh_ip} is the glue I already know: "insert the dial's value here". So it becomes something like 82.12.34.56.
- /32 is the sizing suffix. Remember /24 from the subnets meant "256 addresses in this street"? The number says how many bits are fixed. /32 means all 32 bits fixed, which is a range containing exactly one address. One house. Mine.

The guard's instructions, before and after:

| | Guard's instructions | Result |
|---|---|---|
| Before | "Port 22? Let anyone in the world try the door." | Every bot on Earth can attempt SSH. Only protection is the key |
| After | "Port 22? Only Felix's house. Everyone else: the door does not exist." | Bots hit a wall. The port is invisible to them |

### Part 2: passing the dial through (and the error that reminded me how the chain works)

The dial exists inside the module, but the value still has to travel the same four-stop chain as the SQL password did: tfvars, root variables.tf, module call, resource.

My error: I forgot to add allowed_ssh_ip = var.allowed_ssh_ip to the module blocks in root main.tf. The dial was declared but nobody was passing a value into it, for either environment. Fixed by adding the line to both module blocks, exactly like sql_admin_password:

![both module blocks passing the new dial through](lesson20-module-pass.png)

The matching empty box in root variables.tf (same declaration, no default, so it is mandatory):

![the root variables.tf box](lesson20-root-variable.png)

And finally the actual answer goes in terraform.tfvars: allowed_ssh_ip = "your.ip.here". That file stays gitignored, obviously.

### Part 3: checking the plan before building anything

terraform plan. What I am looking for: source_address_prefix showing "my.ip/32" and not "*", and 24 to add, because everything was destroyed at the end of last night.

![the plan proving the rule is tightened](lesson20-plan.png)

There it is. One address, /32, nobody else. (In this screenshot it is the wrong one address, the 192.168 detour from Part 1, corrected afterwards to my real public IP from the Google search. The shape was right, the contents were not. tfvars updated, re-applied, door now exists for exactly one house.)

### Part 4: Key Vault, the digital safe

Decision made before writing any code: write ALL the Key Vault code first, then do one single apply at the end that builds everything. More efficient with time and money than applying twice.

So what is a Key Vault? Azure's digital safe. The password moves out of tfvars and into the vault, encrypted, with every access logged, and Terraform fetches it at apply time instead of reading a file off my laptop.

One new building block first: the data block. Everything so far has been resource blocks, which CREATE things. A data block READS things that already exist. I need it to answer the question "who am I?", because the vault needs to know who is allowed to manage its secrets.

And that word RBAC, which the code is about to use: Role-Based Access Control. Azure's permission system. Instead of a special access list bolted onto each resource, permissions are granted as roles, the same way everywhere in Azure. Every permission is three things: WHO gets it (the principal), WHAT they can do (the role, like Key Vault Secrets Officer), and WHERE (the scope, which vault). Once you see the who-what-where shape, every permission in Azure is the same sentence.

The code, all in the module so both environments get a safe each:

![all the Key Vault code: data block, vault, role assignment, secret](lesson20-keyvault.png)

What each piece does:

- data "azurerm_client_config" "current" looks up who is running Terraform and hands us their tenant ID and object ID. The "who am I" answer.
- azurerm_key_vault is the safe itself. The line rbac_authorization_enabled = true means permissions come from Azure roles instead of the old vault access policies. RBAC in action.
- azurerm_role_assignment is the rule: "you (principal_id) get the role Key Vault Secrets Officer on this vault (scope)". RBAC in one block: who, what role, on what.
- azurerm_key_vault_secret is the password itself, stored in the safe. The depends_on is there because Terraform can only write the secret after my permission exists. Permission first, then secret.

Learned the hard way from SQL server names: Key Vault names are globally unique too. Somebody else's vault name can collide with yours anywhere on Earth. Hence kv-felixgwet- with the environment stamped on, same trick as the storage account.

### Part 5: the 409 comes back, of course it does

First apply with the vault code in it: red again. 409 MissingSubscriptionRegistration, third time in this project. This time the switch that was off is Microsoft.KeyVault. And honestly this one felt good, because I did not even have to think about it. Lesson 9 was Microsoft.Network, lesson 12 was Microsoft.Compute, lesson 19 was Microsoft.Sql. Every new service family on this subscription has introduced itself the same way, and the error message literally names the namespace it wants. So the fix was muscle memory by now:

    az provider register --namespace Microsoft.KeyVault

One command, register, re-apply, vault builds. The screenshot even catches the "Registering is still on-going" message, Azure's way of saying give it a minute.

![the same old 409, this time for Key Vault, and the one-line fix](lesson20-kv-409.png)

The pattern is now officially a law of this project: new subscription plus first time touching a service family equals one 409, and the cure is always the same one-liner with a different namespace on the end.

### Part 6: the maths and the apply

Final plan check before the single apply: 30 to add. That is the 24 from before (the full rebuild after last night's destroy) plus 6 new security resources: 2 vaults, 2 role assignments, 2 secrets. One set per environment, two environments. The number is the truth, and the number adds up.

Then terraform apply, once, and everything goes up together with both doors closed.

### Part 7: the portal check

Apply said green, but the ritual is to go and see it with my own eyes.

Check one, the NSG. Portal, rg-dev, nsg-web-dev, inbound rules. The allow-ssh rule is sitting at priority 100 with my home IP as the source (masked here, it is a real public address):

![the allow-ssh rule, source locked to one address](lesson20-nsg-portal.png)

Worth reading the three rows underneath mine while we are here, because I did not write them. Azure ships every NSG with default rules: AllowVnetInBound (machines inside the VNet can talk to each other), AllowAzureLoadBalancerInBound (Azure's own load balancer health probes), and at the very bottom, priority 65500, DenyAllInBound. That last one is the wall. Priorities are checked lowest number first, so my rule at 100 gets asked "is this Felix's house?" before anything else, and everyone who is not me falls all the way down to 65500 and hits Deny. The port is not just closed to them, it is invisible.

Check two, the vault. Portal, kv-felixgwet-dev, Secrets, and there it is: sql-admin-password, status Enabled. The password is no longer a line in a text file on my laptop, it is an object living in a safe, with Azure logging every touch:

![the secret living in the vault](lesson20-kv-secret.png)

Three things I noted down while poking around the vault:

- The Vault URI, https://kv-felixgwet-dev.vault.azure.net/, is the safe's address. Apps and pipelines use that URL to ask for secrets. That is the endpoint my future CI/CD pipeline will knock on instead of ever seeing a password file.
- Soft-delete is enabled, 7 days (that is the soft_delete_retention_days = 7 line from my code doing its job). If the vault gets deleted, the contents survive a week, recoverable. And the trap that comes with it: when I terraform destroy tonight, the vault goes into this soft-deleted state but the NAME stays reserved. Rebuild tomorrow with the same name and Azure complains it "already exists". That is the soft-delete ghost. The cure, written here so future me does not have to go hunting: az keyvault purge --name kv-felixgwet-dev, which removes the ghost for good.
- The portal's own recommendation in the middle of the screen says to use a vault per application per environment. And here is the bit I am quietly proud of: I already did that, without knowing it was the recommendation. The vault code lives inside the environment module, the same factory from lesson 18, so calling the module twice stamped out one safe per environment automatically. kv-felixgwet-dev holds dev's password, kv-felixgwet-prod holds prod's. Separate safes, separate walls, separate access logs: a leak in dev can never open prod, and prod's secret never has to exist anywhere near dev. One line in the module, best practice for free.

Tonight I learned that security in Terraform is mostly about refusing convenience. It is easier to leave "*" in the rule and easier to leave the password in a text file, and both easies are how breaches start. The dial pattern and the vault pattern are the same idea really: anything personal or secret lives in exactly one place, gets referenced everywhere else, and never touches GitHub.

One last screenshot for the night: the portal's Recently viewed list, which accidentally reads like the project's family tree.

![everything the project has touched, in one list](lesson20-everything.png)

Every row on that list was born from code. The two resource groups, the NSG with its one locked door, the two SQL servers and their databases, the NIC, the VNet, and at the top the newest arrival, the key vault with the password sleeping in it. And sitting quietly at the bottom, the plumbing that makes the whole thing repeatable: rg-terraform-state and the tfstatelearn1990 storage account, the notebook's official home from lesson 17. And this is not even the full inventory. The invisible rows are missing, the subnets hiding inside the VNet, the NSG association, the role assignment, the secret itself, the same lesson the portal taught me back in lesson 18: portal rows are not Terraform resources. The notebook knows about all of them, the list only shows what I have clicked lately. Not one of these was clicked into existence by hand. Then destroy ran, and the list goes quiet until the next apply.

Roadmap: SSH lockdown done, Key Vault done. Remaining on item 7: the SQL firewall rule (0.0.0.0 still lets any Azure customer knock), then the staging environment test, and item 8, running Terraform from a pipeline.

## Lesson 21: the finale, CI/CD (roadmap item 8)

The last lesson of the project, and the one that turns it from "a thing on my laptop" into "a system". Right now I run terraform from my own machine. After tonight: I push code to GitHub, and GitHub runs plan and apply against Azure for me. Push becomes infrastructure.

The shape of it:

    git push → GitHub Actions wakes up → logs into Azure → terraform init/plan/apply → done

Why this matters, five reasons:

1. **The laptop is a single point of failure.** If the project runs from my device, what happens if the device dies, or I am on holiday, or I get hit by the proverbial bus? Nobody else can deploy. A pipeline runs in a clean, identical environment every single time, from anywhere, by anyone with merge rights.
2. **Humans skip steps.** A pipeline cannot. It validates, plans and logs every run, identically. No "I forgot to run plan", no "I applied from the wrong folder". The process stops depending on my memory.
3. **Audit trail.** Every apply through the pipeline is recorded: who pushed, what changed, what the plan said, when it deployed. Banks literally require this. "Who changed production, and when?" is a much harder question when everything ran off one person's laptop.
4. **Code review becomes real.** With CI, a colleague's pull request automatically gets a terraform plan run against it, and the plan output lands right there in the pull request for review before anything touches Azure. Mistakes get caught in review, not in production.
5. **Speed and confidence compound.** When deploying is one git push, you deploy small and often. Small changes mean a small blast radius and easy rollbacks. The alternative is one device accumulating weeks of changes and deploying them all at once, which is how big outages are born.

### Part 1: the robot identity

GitHub needs an identity to log into Azure as. Not my user account, a robot. Three commands build it, and each one maps to a piece of the puzzle:

    az ad app create --display-name github-terraform-pipeline

![creating the app registration](lesson21-app-create.png)

That registers an app in Entra ID. The app registration is the robot's passport: the identity document that says this thing exists. The output hands back an appId, which is the passport number, copy it for the next step (masked in the screenshot, this journal is public).

    az ad sp create --id <paste-the-appId>

That creates the service principal, which is the robot itself. The app registration is the passport, the service principal is the actual thing that can log in and hold permissions. (Same relationship as a passport and a person: the document proves identity, the person does the work.)

    az role assignment create --assignee <paste-the-appId> --role Contributor --scope /subscriptions/<subscription-id>

![the role assignment output](lesson21-role-assignment.png)

And that grants the robot Contributor on the subscription. This is RBAC again, the exact same who-what-where sentence from the Key Vault lesson: WHO (the robot's appId), WHAT role (Contributor), on WHAT (the whole subscription, via the scope). Lesson 20's pattern, repeated at subscription scale.

### Part 2: the trust handshake (no password, ever)

The robot exists now, but GitHub has no way to prove it is GitHub asking. The old way was to generate a client secret, basically a password for the robot, and paste it into GitHub. The modern way is a federated credential, and it is much better: a rule that says "Azure, trust tokens that come from GitHub Actions, but ONLY from the repo felixgwet/azure-terraform-learning, main branch". No password stored anywhere. The repo's identity IS the credential. If a token comes from any other repo, any other branch, any other system, Azure refuses it.

New file in the project root, github-fic.json:

``` json
{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:felixgwet/azure-terraform-learning:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
```

Reading it: issuer is who vouches for the token (GitHub Actions), subject is exactly which identity is trusted (this repo, main branch, nothing else), audiences is what the token is for (swapping for an Azure AD token). Then wire it up:

    az ad app federated-credential create --id <paste-the-appId> --parameters github-fic.json

![the federated credential created, issuer and subject visible](lesson21-federated.png)

The reply shows the rule registered: issuer token.actions.githubusercontent.com, subject repo:felixgwet/azure-terraform-learning:ref:refs/heads/main. The handshake exists.

### Part 3: teaching GitHub the five values

Out of VS Code and into the browser. Repo (the actual repo, not the personal account), Settings tab, left menu, Secrets and variables, Actions, New repository secret. Five of them, one by one:

| Name | Value | Where it came from |
|---|---|---|
| AZURE_CLIENT_ID | the appId | The passport number from the az ad app create output in Part 1 |
| AZURE_TENANT_ID | the tenant GUID | Which Entra directory the robot lives in. Same tenant the data "azurerm_client_config" block read back in lesson 20, also shown by az account show |
| AZURE_SUBSCRIPTION_ID | the subscription GUID | Which subscription to build in. The same ID I have been masking all journal, az account show again |
| TF_VAR_sql_admin_password | the SQL password | The exact same value as in terraform.tfvars |
| TF_VAR_allowed_ssh_ip | my home public IP | The Google "what is my ip" address from lesson 20. No /32 here, the code adds the /32 itself |

The two TF_VAR_ ones deserve an explanation, because they are the clever bit. There is no terraform.tfvars on the pipeline, the answer sheet stays on my laptop. So how do the dials get answered? Terraform automatically reads any environment variable that starts with TF_VAR_ and uses it as the value for the variable with the matching name. GitHub secrets become environment variables on the runner, so TF_VAR_sql_admin_password quietly fills in the sql_admin_password box, and the tfvars file is never needed in the cloud at all. Same chain as lesson 19, just with a different first stop.

All five in place:

![the five repository secrets](lesson21-github-secrets.png)

Notice what is NOT there: no password for the robot. There is no AZURE_CLIENT_SECRET, because the federated credential from Part 2 replaced it. The secrets list holds identifiers and app config, not the robot's key. The robot has no key. That is the whole point of OIDC.

### Part 4: the workflow file

Back in VS Code, one new file at .github/workflows/terraform.yml, the pipeline definition itself. It tells GitHub: on a push to main, spin up a clean runner, check out the code, log into Azure with OIDC (the handshake from Part 2, using the three AZURE_ secrets), set up Terraform, then init, plan, apply. The TF_VAR_ secrets ride in as environment variables so the dials get answered.

Then I pushed, and the pipeline immediately punched back. Two failures, two lessons.

### Part 5: the pipeline fights back

**Failure zero, the badge that did not match the key.** Before any of the failures below, the first three runs all died within seconds at the same step: the Azure login. The error was AADSTS700213: No matching federated identity record found for presented assertion subject. Reading it slowly: GitHub shows Azure a badge (the subject inside its token), Azure compares it against the subject written on the federated credential from Part 2, and if they are not identical, character for character, the door stays shut.

Two things were wrong with my key. First, GitHub has started issuing tokens with the account and repo IDs embedded in the subject, so the badge actually reads repo:felixgwet@148398273/azure-terraform-learning@1445051988:ref:refs/heads/main, not the shorter repo:owner/name form I had written in github-fic.json from the docs. Second, when I first copied that long number across, I dropped two digits (144501988 instead of 1445051988), and Azure quite reasonably said no. "Close enough" is a concept that does not exist here.

The fix: the correct subject is printed inside the rejection itself, in the presented assertion subject part of the error. To be extra sure of the numbers, check them against GitHub's own API: curl https://api.github.com/repos/OWNER/REPO and read the id fields. Put the exact string into github-fic.json, then delete and recreate the credential, because Azure will not let you edit one in place:

    az ad app federated-credential delete --id <paste-the-appId> --federated-credential-id github-main
    az ad app federated-credential create --id <paste-the-appId> --parameters github-fic.json

Lesson: when a system rejects your identity, the error message is the documentation. The correct badge was printed inside the "no" the whole time.

**Failure one, the file that does not exist.** The run died at the validate step:

![validate failing on the runner, no SSH key file there](lesson21-validate-error.png)

The error: Invalid function argument, pointing at line 85 of the module, public_key = file(pathexpand("~/.ssh/id_ed25519.pub")). That line means "open the file called id_ed25519.pub sitting in the home folder of whoever is running this command". On my laptop that works, the key lives in my home folder. But the pipeline runs on a GitHub-hosted runner, a blank, disposable Linux computer created fresh for every run and thrown away after. Its home folder has no SSH key. file() threw, and the whole run died before anything was built.

The general principle, and it matters far beyond this project: Terraform code must be self-contained. It can only rely on things inside the repo or values handed in from outside, never on files that happen to exist on one particular machine.

**The fix: the key becomes a dial.** Same pattern as the SQL password and the allowed IP before it. First, get the key text. In the terminal:

    type $env:USERPROFILE\.ssh\id_ed25519.pub

It prints one long line starting ssh-ed25519 AAAA.... Copy the whole line, it gets pasted twice later. (A public key is safe to handle like this: it is the lock, not the key.)

Then the three-storey plumbing, by now familiar. One: the module's dial, declare variable "ssh_public_key" in modules\environment\variables.tf, and change line 85 of the module's main.tf from the file() call to public_key = var.ssh_public_key. Same key reaches the VM, just delivered by hand instead of fetched from a file. Two: the root's dial, declare the same variable in the root variables.tf:

![the root variables.tf with the new ssh_public_key box at the bottom](lesson21-root-variable-ssh.png)

Three: pass it down in both module blocks, exactly like sql_admin_password and allowed_ssh_ip before it:

![both module blocks passing the ssh key dial down](lesson21-module-pass-ssh.png)

And the actual values, one per environment. Locally: the key line goes in terraform.tfvars, read automatically by plan and apply (gitignored as always, though a public key is not actually secret, it is the lock). On the pipeline: a GitHub Secret called TF_VAR_ssh_public_key, same TF_VAR_ convention as Part 3, so the robot plugs the dial without ever seeing my tfvars file.

Two hiccups along the way, both worth writing down. The squiggles: VS Code underlined var.ssh_public_key before the matching variable block existed, the editor is a helpful but slow assistant, and terraform validate is the real referee (it came back with "Success! The configuration is valid" once everything was wired). The duplicate: the variable block got pasted into the root variables.tf twice, and Terraform refuses two dials with the same name. Delete the duplicate, done.

**Failure two, the secret that never arrived.** Pushed again, and this time validate passed but plan died:

![plan failing, no value for the required variable](lesson21-plan-no-value.png)

Error: No value for required variable, ssh_public_key is not set. The cause was in the workflow file, not the variables. The env: block at the top mapped only two of the three secrets:

``` yaml
env:
  TF_VAR_sql_admin_password: ${{ secrets.TF_VAR_sql_admin_password }}
  TF_VAR_allowed_ssh_ip: ${{ secrets.TF_VAR_allowed_ssh_ip }}
```

TF_VAR_ssh_public_key was missing. And here is the key thing about how GitHub Actions works: secrets do NOT automatically reach the runner. Nothing gets onto that machine unless the workflow file explicitly maps it, line by line. That is deliberate, a workflow can only touch the secrets its author explicitly granted it, not everything in the vault. So even though I had created the secret correctly, the robot never received it, and Terraform quite rightly said the box was empty.

The fix is one line, added to the env: block, lined up exactly with the two above it (YAML is picky about indentation, two spaces in from env:):

``` yaml
  TF_VAR_ssh_public_key: ${{ secrets.TF_VAR_ssh_public_key }}
```

Before pushing, double-check the secret itself exists: repo, Settings, Secrets and variables, Actions, and the list should now show six secrets, the three AZURE_ ones and the three TF_VAR_ ones. Then:

    git add -A
    git commit -m "Wire ssh_public_key secret into workflow env"
    git push

**Failure three, and this one was full of good news.** Pushed again, and the run got all the way through the plan. The log is worth reading properly, because the good news is the whole middle of it:

``` text
Plan: 28 to add, 0 to change, 0 to destroy.
```

Twenty eight. The entire estate, planned correctly by the robot: both environments, the networks, the VMs, the NSGs, the SQL servers and databases, the key vaults, the secrets, the role assignments. And one lovely detail in the log: source_address_prefix = "*** /32". GitHub automatically masked my home IP in the output, because the value came from a secret. Secrets hygiene working as designed, visible in the wild.

The one error, buried in the middle:

``` text
Error: expected "admin_ssh_key.0.public_key" to not be an empty string or whitespace
```

Read that error carefully and it tells you exactly what happened. It does not say "variable not set" like failure two did. The variable ARRIVED this time (the workflow env line worked), but it arrived EMPTY. That is the signature of a GitHub Secret that does not exist, or exists with a blank value. When a workflow asks for a secret that is not there, GitHub does not complain. It quietly substitutes an empty string and lets you find out downstream. Terraform was the one who complained, because an empty SSH key is not a key.

The fix needed no code change at all: repo, Settings, Secrets and variables, Actions, check TF_VAR_ssh_public_key. Missing? New repository secret. There but blank? Update it. Name TF_VAR_ssh_public_key, value the full one-line ssh-ed25519 AAAA... output from the type command. And because no code changed, no push was needed either: open the failed run and click Re-run failed jobs. Secrets are read fresh at the start of every run, so the re-run picks the fixed value up on its own.

**Failure four, the robot that can build anything but grant nothing.** The re-run after the secret fix finally got through the whole plan and deep into the apply. The key vaults themselves got created. Then red, twice, once per environment:

403 AuthorizationFailed: the client does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write' over scope .../vaults/kv-felixgwet-dev/...

What is going on: to write the SQL password into each vault, the robot first has to create the role assignment from lesson 20, the one granting it Key Vault Secrets Officer on that vault. But the robot's permission is Contributor, and Contributor has a deliberate blind spot: it can create and manage resources, all of them, but it cannot grant access to anything. Microsoft separates the two powers on purpose. If Contributor could grant permissions, anyone with Contributor could simply make themselves Owner and take over the whole subscription. Building things and handing out keys are two different jobs in Azure, and the robot only had the first.

The fix: give the robot the second power, scoped as tight as possible. The role for it is called User Access Administrator, and I granted it on the two project resource groups only, not the whole subscription:

    az role assignment create --assignee <robot-object-id> --role "User Access Administrator" --scope /subscriptions/<subscription-id>/resourceGroups/rg-dev
    az role assignment create --assignee <robot-object-id> --role "User Access Administrator" --scope /subscriptions/<subscription-id>/resourceGroups/rg-prod

The who-what-where sentence from lesson 20, third time now: who (the robot's object id), what (User Access Administrator), where (rg-dev and rg-prod, nowhere else in the subscription). Each command answered with a block of JSON confirming the assignment. Then the by-now familiar move, because no code changed: failed run, Re-run failed jobs. Roles, like secrets, are read fresh at the start of every run.

Then the long quiet stretch to wait through: 28 resources including two SQL servers means 20 plus minutes of the robot building in France, as we learned the hard way back in lesson 19.

The Actions tab told the whole story of the evening in one list:

![the five runs, the mistakes in red, the last one going the distance](lesson21-run-list.png)

Read it bottom to top, because the commit messages are literally the lesson's table of contents. Runs 1, 2 and 3 ("Add CI/CD pipeline with OIDC + hardened security", then the two "Restore journal, README and screenshots" pushes), dead in 12, 16 and 24 seconds: all failure zero, the badge mismatch at the login step. And here is the thing I had not thought about until I saw it: the pipeline runs on EVERY push to main, even a push that only touches documentation. Fix the README, trigger an infrastructure pipeline. (A future improvement is a path filter so docs pushes skip the build. Noted for later.) Run 4, "Pass SSH public key as variable instead of local file", dead in 26 seconds: failure one, the file() that does not exist on a blank runner. Run 5, "Wire ssh_public_key secret into workflow env": the env fix for failure two, which then walked straight through failure three (the empty secret, fixed in GitHub settings) and failure four (the 403, fixed with the two scoped role assignments), each time needing nothing but Re-run failed jobs, until it finally went green.

And that is the run in the screenshot showing In progress at the 7 minute mark. Not dead in seconds like the others. Quietly cooking. The two SQL servers take their time.

### Part 6: the first green run

The re-run went the distance. Every step green: checkout, the Azure login via OIDC (you can see the federated token details in the log, issuer and subject matching the handshake exactly), Terraform installed, init configured the azurerm backend and pulled the state from the storage account, modules loaded:

![the pipeline run, every step green](lesson21-pipeline-run.png)

That log is the whole project in one screenshot. The backend from lesson 17 being configured by a machine that is not me. The modules from lesson 18 being installed by a runner I do not own. The identity from tonight logging in with no password. And every future change to the environment now flows the same way: edit code, push, pipeline validates and applies, audit trail written.

Tonight I learned what CI/CD actually is, from the inside: not a tool, a transfer of trust. Trust moves from "Felix's laptop, hopefully" to "a defined identity, a defined repo, a defined branch, a recorded run". And the five failures taught the supporting rules: an identity badge must match the key digit for digit, code must be self-contained because the runner knows nothing about any one machine, secrets reach a workflow only when someone writes the line that grants them, a missing secret fails silently until something downstream complains, and in Azure building resources and granting access are two separate powers, so the robot needed Contributor AND a scoped User Access Administrator. The pipeline is the project growing up.

That is item 8 done, and with it the whole original roadmap: core blocks, variables, outputs, the network, the first VM, the size hunt, SSH, remote state, modules, SQL, the secrets chain, Key Vault, the locked-down NSG, and now the pipeline. Loose ends still on the list: the SQL firewall rule, and the staging environment test. Then the real exams: rebuild it all for a fictional business, then rebuild it from memory.

Final tally for the finale: five runs, four red crosses, five distinct failures, one green. Every mistake is documented above, and the run list on GitHub is the receipt. Push to main, infrastructure appears. That is the job.
