# M3 data side in Azure: a vault and a storage account, both closed to every
# public network. Storage is encrypted with a vault key through a user assigned
# identity. The private endpoints that reach them live in envs/ephemeral.

locals {
  m3_tags = merge(local.tags, { milestone = "M3" })
  suffix  = substr(replace(var.subscription_id, "-", ""), 0, 10)
}

resource "azurerm_user_assigned_identity" "storage" {
  name                = "id-meridian-storage"
  location            = azurerm_resource_group.meridian.location
  resource_group_name = azurerm_resource_group.meridian.name
  tags                = local.m3_tags
}

resource "azurerm_key_vault" "this" {
  #checkov:skip=CKV2_AZURE_32:Private endpoint is in envs/ephemeral by design (hourly cost). Tracked in POA&M.
  name                          = "kv-meridian-${local.suffix}"
  location                      = azurerm_resource_group.meridian.location
  resource_group_name           = azurerm_resource_group.meridian.name
  tenant_id                     = data.azuread_client_config.me.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false
  tags                          = local.m3_tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# Through ARM, not the vault data plane: the data plane is closed to this laptop.
resource "azapi_resource" "cmk" {
  type      = "Microsoft.KeyVault/vaults/keys@2023-07-01"
  name      = "storage-cmk"
  parent_id = azurerm_key_vault.this.id
  tags      = local.m3_tags
  body = {
    properties = {
      kty     = "RSA"
      keySize = 2048
      keyOps  = ["wrapKey", "unwrapKey"]
      rotationPolicy = {
        attributes = { expiryTime = "P1Y" }
        # Azure adds this Notify by default; listing it keeps plans clean.
        lifetimeActions = [
          { action = { type = "rotate" }, trigger = { timeAfterCreate = "P90D" } },
          { action = { type = "notify" }, trigger = { timeBeforeExpiry = "P30D" } },
        ]
      }
    }
  }
  response_export_values = ["properties.keyUri"]
  # ponytail: Azure echoes action types capitalised ("Rotate") but the azapi schema
  # only accepts lowercase, so the policy would show drift on every plan. Edit the
  # policy with az keyvault key rotation-policy update if it must change; never taint (replaces the CMK).
  lifecycle {
    ignore_changes = [body.properties.rotationPolicy]
  }
}

resource "azurerm_role_assignment" "storage_key" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.storage.principal_id
}

resource "azurerm_storage_account" "data" {
  #checkov:skip=CKV_AZURE_43:Name is computed from the subscription id; Azure validates it at create.
  #checkov:skip=CKV_AZURE_206:Lab data, LRS is enough. Tracked in POA&M.
  #checkov:skip=CKV_AZURE_33:No queues on this account. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_38:Lab lifetime under 30 days; no soft delete. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_41:Shared key is disabled, so no SAS can be issued. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_33:Private endpoint is in envs/ephemeral by design (hourly cost). Tracked in POA&M.
  name                            = "stmeridian${local.suffix}"
  location                        = azurerm_resource_group.meridian.location
  resource_group_name             = azurerm_resource_group.meridian.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  public_network_access_enabled   = false
  tags                            = local.m3_tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage.id]
  }

  customer_managed_key {
    key_vault_key_id          = azapi_resource.cmk.output.properties.keyUri
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }

  # Role assignments take a minute to land; rerun apply once if the key is refused.
  depends_on = [azurerm_role_assignment.storage_key]
}

resource "azurerm_storage_container" "docs" {
  #checkov:skip=CKV2_AZURE_21:Blob diagnostic logging arrives with the M5 diagnostic settings policy. Tracked in POA&M.
  name                  = "docs"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

# You hold the data role, so the SC-7 test fails on the network, not on RBAC.
resource "azurerm_role_assignment" "me_blob_reader" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_client_config.me.object_id
}

output "storage_account" {
  value = azurerm_storage_account.data.name
}

output "key_vault" {
  value = azurerm_key_vault.this.name
}
