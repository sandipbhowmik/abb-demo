variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
variable "tf_operator_object_id" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aad_admin_group_object_ids" {
  type    = list(string)
  default = []
}

variable "mysql_administrator_login" {
  type        = string
  description = "MySQL admin login"
  default     = "mysqladmin"
}
