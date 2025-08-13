variable "enable" {
  type    = bool
  default = false
}

variable "location" { type = string }
variable "rg_name" { type = string }
variable "name_prefix" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_deployment" {
  type    = bool
  default = true
}
variable "deployment_name" {
  type    = string
  default = "gpt-4o-mini"
}
variable "model_format" {
  type    = string
  default = "OpenAI"
} 
variable "model_name" {
  type    = string
  default = "gpt-4o-mini"
}
variable "model_version" {
  type    = string
  default = "latest"
}

variable "sku_name" {
  type    = string
  default = "S0"
}
variable "capacity" {
  type    = number
  default = 20
}

variable "assign_role_to_principal_id" {
  type    = string
  default = null
}
