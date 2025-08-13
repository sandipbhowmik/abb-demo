variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
variable "vnet_cidr" { type = string }
variable "aks_subnet_cidr" { type = string }
variable "mysql_subnet_cidr" { type = string }
variable "app_subnet_cidr" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}