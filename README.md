# Azure ML Studio A10v5 Healthcare AI Terraform Configuration

This Terraform configuration deploys an Azure Machine Learning workspace with an A10v5 GPU compute instance, private endpoint support, and integrated healthcare AI agents for medical image analysis and report generation.

## Architecture

The configuration creates the following resources:

- **Resource Group**: Container for all resources
- **Virtual Network**: Private network with dedicated subnets
- **Azure Machine Learning Workspace**: ML workspace with private endpoint configuration
- **A10v5 Compute Instance**: GPU-enabled compute instance for healthcare AI workloads
- **Healthcare AI Endpoints**: Online endpoints for CXRReportGen, MedImageParse, and MedImageInsight models
- **Private Endpoints**: Secure network access to ML workspace and model endpoints
- **Supporting Resources**: Key Vault, Storage Account, Application Insights
- **DNS Configuration**: Private DNS zones for name resolution

### Healthcare AI Agents

The configuration includes three specialized healthcare AI agents:

1. **CXRReportGen**: Automated chest X-ray report generation
2. **MedImageParse**: Medical image segmentation and tumor size calculation
3. **MedImageInsight**: Medical image and text embedding for tumor malignancy assessment

## Prerequisites

1. **Azure CLI**: Install and authenticate with Azure
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Terraform**: Install Terraform >= 1.0
   ```bash
   # On macOS with Homebrew
   brew install terraform
   
   # On Ubuntu/Debian
   wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

3. **SSH Key Pair**: Generate SSH keys for compute instance access
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
   ```

## Configuration

1. **Copy the example variables file**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars** with your specific values:
   - Update `ssh_public_key` with your public key content
   - Modify `resource_group_name`, `location`, and `prefix` as needed
   - Choose appropriate `a10v5_vm_size` based on your requirements
   - Configure healthcare agent settings (`healthcare_agents_enabled`, model names)
   - Add relevant tags for your organization

## A10v5 VM Sizes

| Size | vCPUs | RAM (GiB) | GPU Fraction | Use Case |
|------|-------|-----------|--------------|----------|
| Standard_NV6ads_A10_v5 | 6 | 55 | 1/6 GPU | Light ML workloads, development |
| Standard_NV12ads_A10_v5 | 12 | 110 | 1/3 GPU | Medium ML workloads |
| Standard_NV18ads_A10_v5 | 18 | 165 | 1/2 GPU | Heavy ML workloads |
| Standard_NV36ads_A10_v5 | 36 | 330 | 1 GPU | Full GPU ML workloads |
| Standard_NV72ads_A10_v5 | 72 | 660 | 2 GPUs | Multi-GPU ML workloads |

## Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Validate configuration**:
   ```bash
   terraform validate
   ```

3. **Plan deployment**:
   ```bash
   terraform plan
   ```

4. **Apply configuration**:
   ```bash
   terraform apply
   ```

## Private Endpoint Access

The configuration creates private endpoints for secure access to the ML workspace. The workspace is configured with `public_network_access_enabled = false`, meaning it can only be accessed through the private endpoint.

### DNS Configuration

Private DNS zones are automatically configured for:
- `privatelink.api.azureml.ms` - ML workspace API access
- `privatelink.notebooks.azure.net` - Jupyter notebooks access

### Network Access

- The compute instance is deployed in a private subnet with no public IP
- SSH access is available through the private network only
- All ML workspace communication happens over private endpoints

## Outputs

After successful deployment, the following outputs are available:

- `resource_group_name`: Name of the created resource group
- `machine_learning_workspace_name`: Name of the ML workspace
- `compute_instance_name`: Name of the A10v5 compute instance
- `private_endpoint_ip`: Private IP of the ML workspace endpoint
- `key_vault_uri`: URI of the associated Key Vault
- `storage_account_name`: Name of the storage account
- `cxr_report_gen_endpoint_uri`: CXRReportGen model endpoint URI
- `med_image_parse_endpoint_uri`: MedImageParse model endpoint URI
- `med_image_insight_endpoint_uri`: MedImageInsight model endpoint URI
- `healthcare_endpoints`: All healthcare AI model endpoints

## Post-Deployment

1. **Access ML Workspace**: Through Azure Portal
2. **Connect to Compute Instance**: Via SSH using private key
3. **Configure Healthcare Agents**: Update endpoint URLs in agent configuration
4. **Start Healthcare AI Development**: Use Jupyter notebooks with healthcare AI samples
5. **Deploy Models**: Use the healthcare AI endpoints for inference

### Healthcare Agent Setup

After deployment, configure the healthcare agents:

```bash
# SSH into the compute instance
ssh azureuser@<compute-instance-ip>

# Navigate to healthcare agents directory
cd /home/azureuser/healthcare-agents

# Update configuration with deployed endpoint URLs
vim config.py

# Test healthcare agents
python cxr_report_gen.py --test
python med_image_parse.py --test
python med_image_insight.py --test
```

## Security Considerations

1. **Private Network**: All resources are deployed in a private network
2. **No Public Access**: ML workspace has public access disabled
3. **Key Vault**: Secrets and keys are stored in Azure Key Vault with purge protection
4. **SSH Keys**: Compute instance access requires SSH key authentication
5. **Network Policies**: Private endpoint network policies are properly configured

## Configuration Files

- `main.tf`: Core infrastructure definition with healthcare AI endpoints
- `variables.tf`: Configurable parameters including healthcare agent settings
- `outputs.tf`: Important output values including healthcare endpoint URIs
- `terraform.tfvars.example`: Example configuration with healthcare variables
- `deploy.sh`: Automated deployment script
- `install-healthcare-agents.sh`: Standalone healthcare AI installation script (Linux/macOS)
- `install-healthcare-agents.ps1`: Standalone healthcare AI installation script (Windows PowerShell)
- `DATA_SCIENCE_TOOLS.md`: Comprehensive data science tooling recommendations

## Healthcare AI Models

### CXRReportGen
- **Purpose**: Automated chest X-ray report generation
- **Input**: Chest X-ray images (DICOM or standard formats)
- **Output**: Structured radiology reports with findings
- **Use Cases**: Radiology workflow automation, preliminary screening

### MedImageParse
- **Purpose**: Medical image segmentation and analysis
- **Input**: Medical images (CT, MRI, X-ray)
- **Output**: Segmentation masks, tumor measurements
- **Use Cases**: Tumor detection, organ segmentation, quantitative analysis

### MedImageInsight
- **Purpose**: Medical image and text embedding
- **Input**: Medical images and clinical text
- **Output**: Malignancy likelihood scores, embeddings
- **Use Cases**: Tumor classification, clinical decision support

## Alternative Installation

For installation without Terraform, use the standalone script:

### **Linux/macOS (Bash)**
```bash
# Set environment variables
export RESOURCE_GROUP_NAME="rg-healthcare-ai"
export LOCATION="eastus"
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"

# Run installation script
./install-healthcare-agents.sh
```

### **Windows (PowerShell)**
```powershell
# Set environment variables
$env:SSH_PUBLIC_KEY = Get-Content ~/.ssh/id_rsa.pub -Raw

# Run installation script with parameters
.\install-healthcare-agents.ps1 -ResourceGroupName "rg-healthcare-ai" -Location "eastus"
```

## Cost Optimization

- A10v5 instances are charged per hour when running
- Consider using smaller VM sizes for development/testing
- Stop compute instances when not in use to reduce costs
- Monitor usage through Azure Cost Management

## Troubleshooting

### Common Issues

1. **Quota Limits**: Ensure your subscription has sufficient quota for A10v5 VMs
2. **Region Availability**: A10v5 VMs are not available in all regions
3. **SSH Access**: Ensure your SSH public key is correctly formatted
4. **DNS Resolution**: Private DNS zones may take time to propagate

### Useful Commands

```bash
# Check Terraform state
terraform state list

# Show specific resource details
terraform state show azurerm_machine_learning_compute_instance.a10v5_instance

# Refresh state
terraform refresh

# Destroy resources (use with caution)
terraform destroy
```

## Support

For issues related to:
- **Terraform**: Check the [Terraform Azure Provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- **Azure ML**: Refer to [Azure Machine Learning documentation](https://docs.microsoft.com/en-us/azure/machine-learning/)
- **A10v5 VMs**: See [Azure VM sizes documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-gpu)

For detailed documentation and data science tooling recommendations, see:
- `README.md` - This file
- `DATA_SCIENCE_TOOLS.md` - Comprehensive tooling guide
- `DEPLOYMENT_GUIDE.md` - Quick deployment guide

## License

This configuration is provided as-is for educational and deployment purposes.
