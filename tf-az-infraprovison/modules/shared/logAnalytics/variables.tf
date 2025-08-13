variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
#variable "tags"        { type = map(string) default = {} }
variable "tags" {
  type    = map(string)
  default = {}
}
