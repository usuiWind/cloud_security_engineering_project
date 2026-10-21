# The private path to the persistent storage account and vault: VNet, private
# endpoints with their DNS zones, and VNet flow logs.

locals {
  rg_name = "rg-meridian"
  rg_id   = "/subscriptions/${var.subscription_id}/resourceGroups/${local.rg_name}"
  suffix  = substr(replace(var.subscription_id, "-", ""), 0, 10)
  storage = "stmeridian${local.suffix}"
  vault   = "kv-meridian-${local.suffix}"
  private = {
    blob  = { zone = "privatelink.blob.core.windows.net", target = "${local.rg_id}/providers/Microsoft.Storage/storageAccounts/${local.storage}" }
    vault = { zone = "privatelink.vaultcore.azure.net", target = "${local.rg_id}/providers/Microsoft.KeyVault/vaults/${local.vault}" }
  }
}

# Created explicitly in the tagged group: the one Azure auto-creates lands in an
# untagged NetworkWatcherRG, which the M2 tag policy denies.
resource "azurerm_network_watcher" "this" {
  name                = "nw-meridian-${var.azure_location}"
  location            = var.azure_location
  resource_group_name = local.rg_name
  tags                = local.azure_tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-meridian"
  location            = var.azure_location
  resource_group_name = local.rg_name
  address_space       = ["10.50.0.0/24"]
  tags                = local.azure_tags
  depends_on          = [azurerm_network_watcher.this]
}

resource "azurerm_subnet" "private" {
  name                 = "snet-private"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.50.0.0/26"]
}

resource "azurerm_network_security_group" "private" {
  name                = "nsg-meridian-private"
  location            = var.azure_location
  resource_group_name = local.rg_name
  tags                = local.azure_tags
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = local.private
  name                = each.value.zone
  resource_group_name = local.rg_name
  tags                = local.azure_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = local.private
  name                  = "link-${each.key}"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = local.azure_tags
}

resource "azurerm_private_endpoint" "this" {
  for_each            = local.private
  name                = "pe-meridian-${each.key}"
  location            = var.azure_location
  resource_group_name = local.rg_name
  subnet_id           = azurerm_subnet.private.id
  tags                = local.azure_tags

  private_service_connection {
    name                           = "psc-${each.key}"
    private_connection_resource_id = each.value.target
    subresource_names              = [each.key]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.this[each.key].id]
  }
}

resource "azurerm_storage_account" "flowlogs" {
  #checkov:skip=CKV_AZURE_43:Name is computed from the subscription id; Azure validates it at create.
  #checkov:skip=CKV_AZURE_59:Default action Deny with only the trusted service bypass; disabling public access would also block Network Watcher. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_1:Flow log sink only, no data; Microsoft managed keys. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_33:Network Watcher writes as a trusted service; no private endpoint needed for a log sink. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_40:Shared key left at the default so Network Watcher delivery is not blocked. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_41:No SAS is ever issued on this account. Tracked in POA&M.
  #checkov:skip=CKV_AZURE_33:No queues on this account. Tracked in POA&M.
  #checkov:skip=CKV_AZURE_206:Lab log sink, LRS is enough. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_38:Logs are rewritten hourly and retained 7 days; no soft delete. Tracked in POA&M.
  name                            = "stmflow${local.suffix}"
  location                        = var.azure_location
  resource_group_name             = local.rg_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.azure_tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_network_watcher_flow_log" "vnet" {
  #checkov:skip=CKV_AZURE_12:7 day retention; the lab is torn down nightly and lives four days. Tracked in POA&M.
  name                 = "fl-vnet-meridian"
  network_watcher_name = azurerm_network_watcher.this.name
  resource_group_name  = local.rg_name
  location             = var.azure_location
  target_resource_id   = azurerm_virtual_network.this.id
  storage_account_id   = azurerm_storage_account.flowlogs.id
  enabled              = true
  version              = 2
  tags                 = local.azure_tags

  retention_policy {
    enabled = true
    days    = 7
  }
}
