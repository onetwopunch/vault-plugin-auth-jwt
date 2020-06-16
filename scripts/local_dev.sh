#!/usr/bin/env bash
set -e

MNT_PATH="oidc"
PLUGIN_NAME="vault-plugin-auth-jwt"
PLUGIN_CATALOG_NAME="oidc"

#
# Helper script for local development. Automatically builds and registers the
# plugin. Requires `vault` is installed and available on $PATH.
#

# Get the right dir
DIR="$(cd "$(dirname "$(readlink "$0")")" && pwd)"

echo "==> Starting dev"

echo "--> Scratch dir"
echo "    Creating"
SCRATCH="$DIR/tmp"
TFDIR=$DIR/scripts

mkdir -p "$SCRATCH/plugins"

echo "--> Vault server"
echo "    Writing config"
tee "$SCRATCH/vault.hcl" > /dev/null <<EOF
plugin_directory = "$SCRATCH/plugins"
EOF

echo "    Envvars"
export VAULT_DEV_ROOT_TOKEN_ID="root"
export VAULT_ADDR="http://127.0.0.1:8200"

echo "    Starting"
vault server \
  -dev \
  -log-level="debug" \
  -config="$SCRATCH/vault.hcl" \
  -dev-ha -dev-transactional -dev-root-token-id=root \
  &
sleep 2
VAULT_PID=$!

function cleanup {
  echo ""
  echo "==> Cleaning up"
  kill -INT "$VAULT_PID"
  rm -rf "$SCRATCH"
  rm $TFDIR/terraform.tfstate*
  rm -rf $TFDIR/.terraform
}
trap cleanup EXIT

echo "    Authing"
vault login root &>/dev/null

echo "--> Building"
go build -o "$SCRATCH/plugins/$PLUGIN_NAME" "./cmd/$PLUGIN_NAME" 
SHASUM=$(shasum -a 256 "$SCRATCH/plugins/$PLUGIN_NAME" | cut -d " " -f1)

if [ -e scripts/custom.sh ]
then
  . scripts/custom.sh
fi

echo '==> Ready! Now run `cd scripts; terraform init && terraform apply`'
wait $!

