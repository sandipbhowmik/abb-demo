output "account_id" {
  value = try(one(azapi_resource.account[*].id), null)
}

output "account_name" {
  value = try(one(azapi_resource.account[*].name), null)
}

output "deployment_id" { value = try(azapi_resource.deployment[0].id, null) }
output "deployment_name" { value = try(azapi_resource.deployment[0].name, null) }
