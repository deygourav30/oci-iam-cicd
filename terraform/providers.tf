# The OCI provider reads its login details (user, fingerprint, key, tenancy,
# region) from ~/.oci/config. In GitHub Actions that file is written from
# secrets by ci/write-oci-config.sh. On your laptop, `oci setup config` creates it.
#
# IMPORTANT: IAM objects (users, groups, policies) can only be created in your
# tenancy's HOME region, so the region in the config must be the home region.
provider "oci" {
  config_file_profile = "DEFAULT"
}
