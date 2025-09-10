output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.ml_rg.name
}

output "machine_learning_workspace_id" {
  description = "ID of the Azure Machine Learning workspace"
  value       = azurerm_machine_learning_workspace.ml_workspace.id
}

output "machine_learning_workspace_name" {
  description = "Name of the Azure Machine Learning workspace"
  value       = azurerm_machine_learning_workspace.ml_workspace.name
}

output "compute_instance_name" {
  description = "Name of the A10v5 compute instance"
  value       = azurerm_machine_learning_compute_instance.a10v5_instance.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.ml_vnet.id
}

output "private_endpoint_ip" {
  description = "Private IP address of the ML workspace private endpoint"
  value       = azurerm_private_endpoint.ml_workspace_pe.private_service_connection[0].private_ip_address
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.ml_kv.vault_uri
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.ml_storage.name
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.ml_ai.instrumentation_key
  sensitive   = true
}

output "cxr_report_gen_endpoint_uri" {
  description = "CXRReportGen model endpoint URI"
  value       = azurerm_machine_learning_online_endpoint.cxr_report_gen.scoring_uri
}

output "med_image_parse_endpoint_uri" {
  description = "MedImageParse model endpoint URI"
  value       = azurerm_machine_learning_online_endpoint.med_image_parse.scoring_uri
}

output "med_image_insight_endpoint_uri" {
  description = "MedImageInsight model endpoint URI"
  value       = azurerm_machine_learning_online_endpoint.med_image_insight.scoring_uri
}

output "healthcare_endpoints" {
  description = "Healthcare AI model endpoints"
  value = {
    cxr_report_gen    = azurerm_machine_learning_online_endpoint.cxr_report_gen.scoring_uri
    med_image_parse   = azurerm_machine_learning_online_endpoint.med_image_parse.scoring_uri
    med_image_insight = azurerm_machine_learning_online_endpoint.med_image_insight.scoring_uri
  }
}
