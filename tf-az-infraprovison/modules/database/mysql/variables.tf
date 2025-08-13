variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
variable "subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "administrator_login" { type = string }
variable "administrator_password" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
