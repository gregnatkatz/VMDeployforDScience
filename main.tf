terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "ml_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_virtual_network" "ml_vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name

  tags = var.tags
}

resource "azurerm_subnet" "ml_subnet" {
  name                 = "${var.prefix}-ml-subnet"
  resource_group_name  = azurerm_resource_group.ml_rg.name
  virtual_network_name = azurerm_virtual_network.ml_vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  private_endpoint_network_policies_enabled = false
}

resource "azurerm_subnet" "private_endpoint_subnet" {
  name                 = "${var.prefix}-pe-subnet"
  resource_group_name  = azurerm_resource_group.ml_rg.name
  virtual_network_name = azurerm_virtual_network.ml_vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  private_endpoint_network_policies_enabled = false
}

resource "azurerm_application_insights" "ml_ai" {
  name                = "${var.prefix}-ai"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  application_type    = "web"

  tags = var.tags
}

resource "azurerm_key_vault" "ml_kv" {
  name                       = "${var.prefix}-kv-${random_string.suffix.result}"
  location                   = azurerm_resource_group.ml_rg.location
  resource_group_name        = azurerm_resource_group.ml_rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
      "List",
      "Delete",
      "Update",
      "Recover",
      "Purge",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "List",
      "Delete",
      "Recover",
      "Purge",
    ]

    certificate_permissions = [
      "Create",
      "Get",
      "List",
      "Delete",
      "Update",
      "Recover",
      "Purge",
    ]
  }

  tags = var.tags
}

resource "azurerm_storage_account" "ml_storage" {
  name                     = "${var.prefix}sa${random_string.suffix.result}"
  location                 = azurerm_resource_group.ml_rg.location
  resource_group_name      = azurerm_resource_group.ml_rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  tags = var.tags
}

resource "azurerm_machine_learning_workspace" "ml_workspace" {
  name                    = "${var.prefix}-mlw"
  location                = azurerm_resource_group.ml_rg.location
  resource_group_name     = azurerm_resource_group.ml_rg.name
  application_insights_id = azurerm_application_insights.ml_ai.id
  key_vault_id            = azurerm_key_vault.ml_kv.id
  storage_account_id      = azurerm_storage_account.ml_storage.id

  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_key_vault.ml_kv,
    azurerm_storage_account.ml_storage,
    azurerm_application_insights.ml_ai
  ]
}

resource "azurerm_private_dns_zone" "ml_workspace_dns" {
  name                = "privatelink.api.azureml.ms"
  resource_group_name = azurerm_resource_group.ml_rg.name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ml_workspace_dns_link" {
  name                  = "${var.prefix}-ml-dns-link"
  resource_group_name   = azurerm_resource_group.ml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.ml_workspace_dns.name
  virtual_network_id    = azurerm_virtual_network.ml_vnet.id
  registration_enabled  = false

  tags = var.tags
}

resource "azurerm_private_endpoint" "ml_workspace_pe" {
  name                = "${var.prefix}-ml-pe"
  location            = azurerm_resource_group.ml_rg.location
  resource_group_name = azurerm_resource_group.ml_rg.name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-ml-psc"
    private_connection_resource_id = azurerm_machine_learning_workspace.ml_workspace.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "ml-workspace-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.ml_workspace_dns.id]
  }

  tags = var.tags
}

resource "azurerm_private_dns_zone" "notebooks_dns" {
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = azurerm_resource_group.ml_rg.name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "notebooks_dns_link" {
  name                  = "${var.prefix}-notebooks-dns-link"
  resource_group_name   = azurerm_resource_group.ml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.notebooks_dns.name
  virtual_network_id    = azurerm_virtual_network.ml_vnet.id
  registration_enabled  = false

  tags = var.tags
}

resource "azurerm_machine_learning_compute_instance" "a10v5_instance" {
  name                          = "${var.prefix}-a10v5-ci"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.ml_workspace.id
  virtual_machine_size          = var.a10v5_vm_size
  authorization_type            = "personal"
  subnet_resource_id            = azurerm_subnet.ml_subnet.id
  node_public_ip_enabled        = false
  description                   = "A10v5 GPU compute instance for healthcare AI workloads with private endpoint access"

  ssh {
    public_key = var.ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  assign_to_user {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
  }

  tags = var.tags

  depends_on = [
    azurerm_machine_learning_workspace.ml_workspace,
    azurerm_private_endpoint.ml_workspace_pe
  ]
}

resource "azurerm_machine_learning_online_endpoint" "cxr_report_gen" {
  name                    = "${var.prefix}-cxr-endpoint"
  location                = azurerm_resource_group.ml_rg.location
  workspace_id            = azurerm_machine_learning_workspace.ml_workspace.id
  description             = "CXRReportGen healthcare AI model endpoint for chest X-ray report generation"
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_machine_learning_online_endpoint" "med_image_parse" {
  name                    = "${var.prefix}-medparse-endpoint"
  location                = azurerm_resource_group.ml_rg.location
  workspace_id            = azurerm_machine_learning_workspace.ml_workspace.id
  description             = "MedImageParse healthcare AI model endpoint for medical image segmentation"
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_machine_learning_online_endpoint" "med_image_insight" {
  name                    = "${var.prefix}-medinsight-endpoint"
  location                = azurerm_resource_group.ml_rg.location
  workspace_id            = azurerm_machine_learning_workspace.ml_workspace.id
  description             = "MedImageInsight healthcare AI model endpoint for medical image and text embedding"
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
