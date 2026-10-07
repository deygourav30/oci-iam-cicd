# Terraform "state" = Terraform's memory of what it already created.
# It is stored in an OCI Object Storage bucket so every pipeline run sees it.
# Without this, every run would forget the user exists and try to create it again.
#
# Replace the two placeholders:
#   <namespace>  -> your Object Storage namespace (Tenancy details page)
#   <region>     -> your home region identifier, e.g. ap-mumbai-1
#
# Credentials come from the environment variables AWS_ACCESS_KEY_ID and
# AWS_SECRET_ACCESS_KEY (an OCI "Customer Secret Key", NOT an AWS key).
terraform {
  backend "s3" {
    bucket = "tf-state"
    key    = "oci-iam-cicd/terraform.tfstate"
    region = "ap-hyderabad-1"

    endpoints = {
      s3 = "https://ax7j5hhd7ias.compat.objectstorage.ap-hyderabad-1.oraclecloud.com"
    }

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
