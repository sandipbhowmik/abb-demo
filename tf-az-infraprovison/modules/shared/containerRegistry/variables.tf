variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
# was: variable "sku" { type = string default = "Premium" }
variable "sku" {
  type    = string
  default = "Premium"
}
variable "tags" {
  type    = map(string)
  default = {}
}
