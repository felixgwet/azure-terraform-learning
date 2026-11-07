# Lesson 2: terraform init and terraform plan

Code written, time to actually run Terraform. Two commands this lesson: `terraform init` and `terraform plan`.

## terraform init

First command you run in any Terraform working directory. It reads the `terraform {}` block, downloads the azurerm provider plugin (the translator from lesson 1) into a hidden `.terraform` folder, and gets the directory ready to work. Nothing touches Azure at this point.

## terraform plan

This is the dry run. Terraform compares what my code says should exist against what actually exists in Azure right now, then shows me what it would do, without doing any of it.

The output starts with a legend explaining the symbols. The only one I needed today: a `+` in front of a line means "this will be created".

```
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

Reading it back:

- `azurerm_resource_group.main will be created`. There's the nickname from lesson 1 again, `main` is how Terraform refers to this resource internally, and it's how the plan labels it.
- The indented block underneath spells out exactly what Azure will get: a resource group named `rg-terraform-learn` in `uksouth` (UK South), with my two tags attached.
- `id = (known after apply)` is Terraform being honest. Azure generates the resource ID at creation time, so until I actually apply, that value doesn't exist yet.
- The summary line, `1 to add, 0 to change, 0 to destroy`, is the bit I'll be checking every single time before applying anything. One unexpected "to destroy" in a real environment and you stop and find out why.

## Tags as sticky notes

The `Environment` and `ManagedBy` tags showed up in the plan exactly as written. Think of tags as sticky notes slapped on the resource: they don't change how anything works, but they pay off later for filtering, cost tracking, and answering "where did this thing come from" at a glance.

## The habit forming here

plan before apply, every time, no exceptions. The plan is free, it touches nothing, and it's your last chance to catch a mistake before it becomes real infrastructure.

## Screenshot

![terraform plan output in VS Code terminal](lesson2-terraform-plan.png)
