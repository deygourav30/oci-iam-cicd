# The one resource this project manages: an IAM user in your tenancy.
resource "oci_identity_user" "demo" {
  compartment_id = var.tenancy_ocid # users must be created in the tenancy (root)
  name           = var.user_name
  description    = var.user_description
  email          = var.user_email

  freeform_tags = {
    "managed-by" = "terraform"
    "pipeline"   = "github-actions"
  }
}
