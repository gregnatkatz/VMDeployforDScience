variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-ml-a10v5"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "ml-a10v5"
  
  validation {
    condition     = length(var.prefix) <= 10
    error_message = "Prefix must be 10 characters or less to avoid naming conflicts."
  }
}

variable "a10v5_vm_size" {
  description = "Azure VM size for A10v5 compute instance"
  type        = string
  default     = "Standard_NV6ads_A10_v5"
  
  validation {
    condition = contains([
      "Standard_NV6ads_A10_v5",
      "Standard_NV12ads_A10_v5",
      "Standard_NV18ads_A10_v5",
      "Standard_NV36ads_A10_v5",
      "Standard_NV72ads_A10_v5"
    ], var.a10v5_vm_size)
    error_message = "VM size must be a valid NVads A10 v5-series size."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for compute instance access"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDExample... your-email@example.com"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "ML-A10v5"
    ManagedBy   = "Terraform"
  }
}

variable "healthcare_agents_enabled" {
  description = "Enable deployment of healthcare AI agents"
  type        = bool
  default     = true
}

variable "cxr_model_name" {
  description = "Name of the CXRReportGen model to deploy"
  type        = string
  default     = "microsoft-cxrreportgen"
}

variable "medparse_model_name" {
  description = "Name of the MedImageParse model to deploy"
  type        = string
  default     = "microsoft-medimageparse"
}

variable "medinsight_model_name" {
  description = "Name of the MedImageInsight model to deploy"
  type        = string
  default     = "microsoft-medimageinsight"
}

variable "healthcare_agent_instance_type" {
  description = "Instance type for healthcare agent deployments"
  type        = string
  default     = "Standard_NC6s_v3"
  
  validation {
    condition = contains([
      "Standard_NC6s_v3",
      "Standard_NC12s_v3",
      "Standard_NC24s_v3",
      "Standard_NV6ads_A10_v5",
      "Standard_NV12ads_A10_v5",
      "Standard_NV18ads_A10_v5",
      "Standard_NV36ads_A10_v5"
    ], var.healthcare_agent_instance_type)
    error_message = "Instance type must be a valid GPU-enabled VM size."
  }
}
