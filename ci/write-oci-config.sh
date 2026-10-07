#!/bin/sh
# Builds ~/.oci/config and the private key file from environment variables
# (which GitHub Actions fills from repository secrets). Runs inside the job
# only; the runner machine is thrown away afterwards.
set -eu

mkdir -p "$HOME/.oci"

printf '%s\n' "$OCI_PRIVATE_KEY" > "$HOME/.oci/key.pem"
chmod 600 "$HOME/.oci/key.pem"

cat > "$HOME/.oci/config" <<EOF
[DEFAULT]
user=${OCI_USER_OCID}
fingerprint=${OCI_FINGERPRINT}
tenancy=${OCI_TENANCY_OCID}
region=${OCI_REGION}
key_file=${HOME}/.oci/key.pem
EOF
chmod 600 "$HOME/.oci/config"

echo "OCI config written for region ${OCI_REGION}"
