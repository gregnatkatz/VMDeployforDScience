# Azure ML Studio A10v5 Deployment Guide

## Quick Start

1. **Prerequisites**
   - Azure CLI installed and authenticated (`az login`)
   - Terraform >= 1.0 installed
   - Azure Subscription ID (required for Azure Provider 4.0+)
   - SSH key pair generated

2. **Deploy**
   ```bash
   # Clone or download the configuration files
   cd azure-ml-a10v5-terraform
   
   # Copy and edit configuration
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values (REQUIRED: subscription_id)
   
   # Run deployment script
   ./deploy.sh
   ```

## What Gets Deployed

### Core Infrastructure
- **Resource Group**: Container for all resources
- **Virtual Network**: 10.0.0.0/16 with two subnets
  - ML Subnet (10.0.1.0/24): For compute instance
  - Private Endpoint Subnet (10.0.2.0/24): For private endpoints

### Azure ML Components
- **ML Workspace**: With private endpoint access only
- **A10v5 Compute Instance**: GPU-enabled compute for healthcare AI workloads
- **Healthcare AI Endpoints**: Online endpoints for the three healthcare models
- **Application Insights**: For monitoring and logging
- **Key Vault**: For secrets and key management
- **Storage Account**: For ML workspace storage

### Healthcare AI Models
- **CXRReportGen Endpoint**: Chest X-ray report generation
- **MedImageParse Endpoint**: Medical image segmentation
- **MedImageInsight Endpoint**: Medical image and text embedding

### Security & Networking
- **Private Endpoints**: Secure access to ML workspace and model endpoints
- **Private DNS Zones**: 
  - privatelink.api.azureml.ms
  - privatelink.notebooks.azure.net
- **No Public Access**: All resources secured in private network

## A10v5 VM Size Options

| Size | vCPUs | RAM | GPU | Best For |
|------|-------|-----|-----|----------|
| Standard_NV6ads_A10_v5 | 6 | 55 GiB | 1/6 GPU | Development, light ML |
| Standard_NV12ads_A10_v5 | 12 | 110 GiB | 1/3 GPU | Medium ML workloads |
| Standard_NV18ads_A10_v5 | 18 | 165 GiB | 1/2 GPU | Heavy ML workloads |
| Standard_NV36ads_A10_v5 | 36 | 330 GiB | 1 GPU | Full GPU ML workloads |
| Standard_NV72ads_A10_v5 | 72 | 660 GiB | 2 GPUs | Multi-GPU ML workloads |

## Configuration Files

- `main.tf`: Core infrastructure definition with healthcare AI endpoints
- `variables.tf`: Configurable parameters including healthcare settings
- `outputs.tf`: Important output values including healthcare endpoint URIs
- `terraform.tfvars.example`: Example configuration with healthcare variables
- `deploy.sh`: Automated deployment script
- `install-healthcare-agents.sh`: Standalone healthcare AI installation script (Linux/macOS)
- `install-healthcare-agents.ps1`: Standalone healthcare AI installation script (Windows PowerShell)
- `DATA_SCIENCE_TOOLS.md`: Data science tooling recommendations

## Post-Deployment

1. **Access ML Workspace**: Through Azure Portal
2. **Connect to Compute Instance**: Via SSH using private key
3. **Configure Healthcare Agents**: Update endpoint URLs in configuration
4. **Start Healthcare AI Development**: Use Jupyter notebooks with healthcare samples
5. **Test Healthcare Models**: Run inference with the deployed endpoints

### Healthcare Agent Configuration

```bash
# SSH into compute instance
ssh azureuser@<compute-instance-ip>

# Update healthcare agent configuration
cd /home/azureuser/healthcare-agents
vim config.py

# Test the healthcare agents
python -c "from cxr_report_gen import CxrReportGenPlugin; print('CXR agent ready')"
python -c "from med_image_parse import MedImageParsePlugin; print('Parse agent ready')"
python -c "from med_image_insight import MedImageInsightPlugin; print('Insight agent ready')"
```

### Alternative Installation

Use the standalone installation script for deployment without Terraform:

### **Linux/macOS (Bash)**
```bash
# Set required environment variables
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
export RESOURCE_GROUP_NAME="rg-healthcare-ai"
export LOCATION="eastus"

# Run the installation script
./install-healthcare-agents.sh
```

### **Windows (PowerShell)**
```powershell
# Set required environment variables
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"
$env:SSH_PUBLIC_KEY = Get-Content ~/.ssh/id_rsa.pub -Raw

# Run the installation script with parameters
.\install-healthcare-agents.ps1 -ResourceGroupName "rg-healthcare-ai" -Location "eastus"
```

## Cost Considerations

- A10v5 instances are charged per hour when running
- Stop compute instances when not in use
- Monitor costs through Azure Cost Management
- Consider smaller VM sizes for development/testing

## Troubleshooting

- **Quota Issues**: Check A10v5 quota in your subscription
- **Region Availability**: A10v5 not available in all regions
- **SSH Access**: Ensure SSH key is correctly formatted
- **DNS Resolution**: Private DNS zones may take time to propagate

For detailed documentation, see README.md
