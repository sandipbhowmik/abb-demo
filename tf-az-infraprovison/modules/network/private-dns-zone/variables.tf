variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
variable "zone_name" { type = string }
variable "vnet_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
