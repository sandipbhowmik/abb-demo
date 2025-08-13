variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
variable "subnet_id" { type = string }

variable "log_analytics_workspace_id" { type = string }

variable "aad_admin_group_object_ids" {
  type    = list(string)
  default = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
