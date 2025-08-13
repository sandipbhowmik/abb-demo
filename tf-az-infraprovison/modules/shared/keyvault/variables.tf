variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
variable "tf_operator_object_id" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
