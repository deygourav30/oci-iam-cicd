# Values for the variables in variables.tf. None of these are secrets,
# so this file is committed to Git. Terraform loads it automatically.

tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaaskqrspbaujbng6ftp7dv6skqathap3qzfmhwxumrtmjjygzwte4q"
user_name        = "cicd-demo-user"
user_description = "Demo user created by Terraform through GitHub Actions"
user_email       = "cicd-demo-user@example.com"
