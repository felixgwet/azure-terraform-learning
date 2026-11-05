output "dev_vm_ip" {
  value       = module.dev.vm_public_ip
  description = "Public IP of the dev environment VM"
}

output "prod_vm_ip" {
  value       = module.prod.vm_public_ip
  description = "Public IP of the prod environment VM"
}