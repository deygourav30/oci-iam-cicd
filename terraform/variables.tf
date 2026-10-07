variable "tenancy_ocid" {
  description = "OCID of your tenancy. IAM users always live in the tenancy (root compartment)."
  type        = string
}

variable "user_name" {
  description = "Login name of the IAM user to create."
  type        = string
}

variable "user_description" {
  description = "Free-text description shown in the OCI console."
  type        = string
  default     = "Created by Terraform through GitHub Actions"
}

variable "user_email" {
  description = "Email address for the new user (optional)."
  type        = string
  default     = null
}
