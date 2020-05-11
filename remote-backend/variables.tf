# company
variable "company" {
  type = string
  description = "This variable defines the name of the company"
}

# owner
variable "owner" {
  type = string
  description = "Owner email to append to resource group"
}

# environment
variable "environment" {
  type = string
  description = "This variable defines the environment to be built"
}

# azure region
variable "location" {
  type = string
  description = "Azure region where resources will be created"
  default = "UK South"
}
