# variable "client_id" {
#   type = string
# }

# variable "client_secret" {
#   type = string
# }

# variable "tenant_id" {
#   type = string
# }

variable "storage_account_name" {
  type = string
}

variable "storage_account_id" {
  type = string
}

variable "virtual_network_name" {
  type = string
}

variable "virtual_network_id" {
  type = string
}

variable "project_name" {
  type = string
}

variable "resource_number" {
  type = string
  default = "001"
}

variable "resource_group_name" {
  type = string
}
