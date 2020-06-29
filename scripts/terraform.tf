variable "oidc_client_id" {}
variable "oidc_client_secret" {}
variable "allowed_groups" { type = list }
variable "gsuite_admin_email" {}
variable "gsuite_service_account" {}
variable "plugin_path" {
  default = "../tmp/plugins/vault-plugin-auth-jwt"
}

variable "plugin_name" {
  default = "vault-plugin-auth-jwt"
}

variable "plugin_catalog_name" {
  default = "gsuite"
}

data "vault_policy_document" "admin" {
  rule {
    path         = "*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    description  = "Manage auth backends broadly across Vault"
  }
}

resource "vault_policy" "admin" {
  name   = "admin"
  policy = data.vault_policy_document.admin.hcl
}


resource "null_resource" "gsuite_plugin" {
  provisioner "local-exec" {
    command=<<EOF
vault write sys/plugins/catalog/${var.plugin_catalog_name} sha_256="${filesha256(var.plugin_path)}" command="${var.plugin_name}"
vault auth enable -path=oidc -listing-visibility=unauth "${var.plugin_catalog_name}"
EOF
  }
  triggers = {
    sha256sum = filesha256(var.plugin_path)
  }
}

resource "vault_generic_secret" "gsuite_config" {
  path = "auth/oidc/config"
  data_json = <<EOF
{
   "oidc_discovery_url": "https://accounts.google.com",
   "oidc_client_id": "${var.oidc_client_id}",
   "oidc_client_secret": "${var.oidc_client_secret}",
   "bound_issuer": "https://accounts.google.com",
   "gsuite_service_account": "${var.gsuite_service_account}",
   "gsuite_admin_impersonate": "${var.gsuite_admin_email}"
}
EOF
  depends_on = [null_resource.gsuite_plugin]
}

resource "vault_jwt_auth_backend_role" "gsuite" {
  backend         = "oidc"
  role_name       = "admin"
  token_policies  = ["admin"]

  bound_audiences       = [var.oidc_client_id]
  user_claim            = "sub"
  role_type             = "oidc"
  allowed_redirect_uris = ["http://127.0.0.1:8200/ui/vault/auth/oidc/oidc/callback"]
  
  bound_claims = {
    groups = join(", ", var.allowed_groups)
  }
  depends_on = [vault_generic_secret.gsuite_config]
}
