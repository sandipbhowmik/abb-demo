variable "location" { type = string }
variable "rg_name" { type = string }
variable "sa_name" { type = string }
variable "container_name" {
  type    = string
  default = "tfstate"
}

variable "subscription_id" { type = string }
variable "tenant_id"       { type = string }
