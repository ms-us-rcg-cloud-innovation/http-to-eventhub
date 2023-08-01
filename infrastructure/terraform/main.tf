resource "azurecaf_name" "resource_group" {
  name          = var.name
  resource_type = "azurerm_resource_group"
}

resource "azurerm_resource_group" "default" {
  name     = azurecaf_name.resource_group.result
  location = var.location
}

resource "azurecaf_name" "storage_account" {
  name          = var.name
  resource_type = "azurerm_storage_account"
}

resource "azurerm_storage_account" "default" {
  name                     = azurecaf_name.storage_account.result
  resource_group_name      = azurerm_resource_group.default.name
  location                 = azurerm_resource_group.default.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurecaf_name" "eventhub_namespace" {
  name          = var.name
  resource_type = "azurerm_eventhub_namespace"
}

resource "azurerm_eventhub_namespace" "default" {
  name                = azurecaf_name.eventhub_namespace.result
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku                 = "Standard"
  capacity            = 1
}

resource "azurecaf_name" "eventhub" {
  name          = var.name
  resource_type = "azurerm_eventhub"
}

resource "azurerm_eventhub" "default" {
  name                = azurecaf_name.eventhub.result
  namespace_name      = azurerm_eventhub_namespace.default.name
  resource_group_name = azurerm_resource_group.default.name
  partition_count     = 2
  message_retention   = 1

  capture_description {
    enabled             = true
    encoding            = "Avro"
    interval_in_seconds = 120

    destination {
      name                = "EventHubArchive.AzureBlockBlob"
      blob_container_name = "capturedevents"
      archive_name_format = "{Namespace}/{EventHub}_{PartitionId}/{Year}-{Month}-{Day}-{Hour}-{Minute}/{Second}"
      storage_account_id  = azurerm_storage_account.default.id
    }
  }
}

resource "azurecaf_name" "app_service_plan" {
  name          = var.name
  resource_type = "azurerm_app_service_plan"
}

resource "azurerm_service_plan" "default" {
  name                = azurecaf_name.app_service_plan.result
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku_name            = "S1"
  os_type             = "Linux"
}

resource "azurerm_linux_function_app" "default" {
  name                = "${var.name}-func"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  storage_account_name       = azurerm_storage_account.default.name
  storage_account_access_key = azurerm_storage_account.default.primary_access_key
  service_plan_id            = azurerm_service_plan.default.id

  site_config {
    always_on = true

    cors {
      allowed_origins     = ["https://portal.azure.com"]
      support_credentials = true
    }

    application_stack {
      dotnet_version = "6.0"
    }
  }

  app_settings = {
    "AzureWebJobsStorage"      = azurerm_storage_account.default.primary_connection_string
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
    "EventHubConnection"       = azurerm_eventhub_namespace.default.default_primary_connection_string
    "EventHubName"             = azurerm_eventhub.default.name
  }

}
