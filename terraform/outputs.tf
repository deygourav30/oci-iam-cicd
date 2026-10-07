output "user_ocid" {
  description = "OCID of the user Terraform created."
  value       = oci_identity_user.demo.id
}

output "user_name" {
  value = oci_identity_user.demo.name
}

output "user_state" {
  description = "Should be ACTIVE once the user exists."
  value       = oci_identity_user.demo.state
}
