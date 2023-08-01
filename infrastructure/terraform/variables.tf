variable "location" {
  description = "Azure region to deploy"
  type        = string
  default     = "East US"
}

variable "name" {
  description = "Common name used in all resources"
  type        = string
  default     = "multitenant"
}