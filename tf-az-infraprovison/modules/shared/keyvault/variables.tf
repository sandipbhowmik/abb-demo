variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
# variables.tf (root or keyvault module)
variable "tf_operator_object_id" {
  type = string
}
#variable "tags"        { type = map(string) default = {} }
variable "tags" {
  type    = map(string)
  default = {}
}
