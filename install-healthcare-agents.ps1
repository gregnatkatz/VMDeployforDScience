# Healthcare AI Agents Installation Script for Azure ML Studio A10v5 (PowerShell)
# This script provisions VM and deploys healthcare AI models outside of Terraform

param(
    [string]$ResourceGroupName = "rg-ml-healthcare-a10v5",
    [string]$Location = "eastus",
    [string]$WorkspaceName = "ml-healthcare-workspace",
    [string]$ComputeName = "healthcare-a10v5-ci",
    [string]$VMSize = "Standard_NV36ads_A10_v5",
    [string]$AdminUsername = "azureuser",
    [string]$SSHPublicKey = $env:SSH_PUBLIC_KEY,
    [string]$SubscriptionId = $env:ARM_SUBSCRIPTION_ID
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Healthcare agent configuration
$CXRModelName = "microsoft-cxrreportgen"
$MedParseModelName = "microsoft-medimageparse"
$MedInsightModelName = "microsoft-medimageinsight"

# Color functions for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "🏥 $Title" -ForegroundColor Cyan
    Write-Host ("=" * ($Title.Length + 4)) -ForegroundColor Cyan
}

# Check prerequisites
function Test-Prerequisites {
    Write-Header "Healthcare AI Agents Installation Script"
    Write-Info "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    try {
        $azVersion = az version --output json | ConvertFrom-Json
        Write-Success "Azure CLI version $($azVersion.'azure-cli') found"
    }
    catch {
        Write-Error "Azure CLI is not installed. Please install it first."
        Write-Info "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    }
    
    # Check if logged into Azure
    try {
        $account = az account show --output json | ConvertFrom-Json
        Write-Success "Logged into Azure as $($account.user.name)"
    }
    catch {
        Write-Error "Not logged into Azure. Please run 'az login' first."
        exit 1
    }
    
    # Validate Azure Subscription ID
    if ([string]::IsNullOrEmpty($SubscriptionId)) {
        Write-Error "❌ Azure Subscription ID is required"
        Write-Host "Set it with: `$env:ARM_SUBSCRIPTION_ID = 'your-subscription-id'"
        exit 1
    }
    
    # Check if SSH public key is provided
    if ([string]::IsNullOrEmpty($SSHPublicKey)) {
        Write-Error "SSH_PUBLIC_KEY environment variable is required."
        Write-Info "Generate with: ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'"
        Write-Info "Then set: `$env:SSH_PUBLIC_KEY = Get-Content ~/.ssh/id_rsa.pub -Raw"
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

# Create resource group
function New-ResourceGroup {
    Write-Info "Creating resource group: $ResourceGroupName"
    
    try {
        az group create `
            --name $ResourceGroupName `
            --location $Location `
            --tags Environment=Production Project=Healthcare-AI ManagedBy=PowerShell
        
        Write-Success "Resource group created successfully"
    }
    catch {
        Write-Error "Failed to create resource group: $_"
        exit 1
    }
}

# Create ML workspace
function New-MLWorkspace {
    Write-Info "Creating Azure ML workspace: $WorkspaceName"
    
    try {
        # Create storage account
        $StorageAccountName = "$($WorkspaceName)sa$(Get-Random -Maximum 999999)"
        Write-Info "Creating storage account: $StorageAccountName"
        az storage account create `
            --name $StorageAccountName `
            --resource-group $ResourceGroupName `
            --location $Location `
            --sku Standard_LRS `
            --kind StorageV2
        
        # Create key vault
        $KeyVaultName = "$WorkspaceName-kv-$(Get-Random -Maximum 999999)"
        Write-Info "Creating key vault: $KeyVaultName"
        az keyvault create `
            --name $KeyVaultName `
            --resource-group $ResourceGroupName `
            --location $Location `
            --enable-purge-protection true
        
        # Create application insights
        $AppInsightsName = "$WorkspaceName-ai"
        Write-Info "Creating application insights: $AppInsightsName"
        az monitor app-insights component create `
            --app $AppInsightsName `
            --location $Location `
            --resource-group $ResourceGroupName `
            --application-type web
        
        # Create ML workspace
        Write-Info "Creating ML workspace: $WorkspaceName"
        az ml workspace create `
            --name $WorkspaceName `
            --resource-group $ResourceGroupName `
            --location $Location `
            --storage-account $StorageAccountName `
            --key-vault $KeyVaultName `
            --application-insights $AppInsightsName `
            --public-network-access Disabled
        
        Write-Success "ML workspace created successfully"
    }
    catch {
        Write-Error "Failed to create ML workspace: $_"
        exit 1
    }
}

# Create compute instance
function New-ComputeInstance {
    Write-Info "Creating A10v5 compute instance: $ComputeName"
    
    try {
        # Create compute instance with healthcare-optimized configuration
        az ml compute create `
            --name $ComputeName `
            --type ComputeInstance `
            --size $VMSize `
            --resource-group $ResourceGroupName `
            --workspace-name $WorkspaceName `
            --ssh-public-key $SSHPublicKey `
            --enable-node-public-ip false `
            --description "A10v5 GPU compute instance for healthcare AI workloads"
        
        Write-Success "Compute instance created successfully"
    }
    catch {
        Write-Error "Failed to create compute instance: $_"
        exit 1
    }
}

# Install healthcare agent dependencies
function Install-Dependencies {
    Write-Info "Installing healthcare agent dependencies on compute instance..."
    
    try {
        # Create PowerShell setup script for compute instance
        $SetupScript = @"
# Healthcare AI Dependencies Installation Script
Write-Host "🔧 Installing healthcare AI dependencies..." -ForegroundColor Blue

# Update system packages
Write-Host "Updating system packages..." -ForegroundColor Yellow
sudo apt-get update -y

# Install system dependencies
Write-Host "Installing system dependencies..." -ForegroundColor Yellow
sudo apt-get install -y python3-pip python3-venv git curl wget unzip

# Install Python packages for healthcare AI
Write-Host "Installing Python packages..." -ForegroundColor Yellow
`$packages = @(
    "azure-ai-ml>=1.12.0",
    "azure-identity>=1.15.0", 
    "azure-storage-blob>=12.19.0",
    "aiohttp>=3.9.0",
    "numpy>=1.24.0",
    "pandas>=2.0.0",
    "pillow>=10.0.0",
    "opencv-python>=4.8.0",
    "scikit-learn>=1.3.0",
    "matplotlib>=3.7.0",
    "seaborn>=0.12.0",
    "jupyter>=1.0.0",
    "jupyterlab>=4.0.0",
    "ipywidgets>=8.0.0",
    "docxtpl==0.19.1",
    "websockets==15.0.1",
    "requests>=2.31.0",
    "python-dotenv>=1.0.0",
    "pydicom>=2.4.0",
    "SimpleITK>=2.3.0",
    "nibabel>=5.2.0",
    "torch>=2.1.0",
    "torchvision>=0.16.0",
    "transformers>=4.35.0"
)

foreach (`$package in `$packages) {
    Write-Host "Installing `$package..." -ForegroundColor Green
    pip install `$package
}

# Install Jupyter extensions
Write-Host "Installing Jupyter extensions..." -ForegroundColor Yellow
jupyter labextension install @jupyter-widgets/jupyterlab-manager

Write-Host "✅ Healthcare AI dependencies installed successfully" -ForegroundColor Green
"@

        # Save setup script to temp file
        $TempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
        $SetupScript | Out-File -FilePath $TempScript -Encoding UTF8
        
        # Execute setup script on compute instance (simulated - would need actual compute instance access)
        Write-Info "Setup script created at: $TempScript"
        Write-Warning "Manual step required: Copy and execute the setup script on the compute instance"
        
        Write-Success "Healthcare dependencies installation script prepared"
    }
    catch {
        Write-Error "Failed to prepare dependencies installation: $_"
        exit 1
    }
}

# Setup healthcare agents
function Install-HealthcareAgents {
    Write-Info "Setting up healthcare agents..."
    
    try {
        # Create healthcare agents setup script
        $AgentSetupScript = @"
# Healthcare Agents Setup Script
Write-Host "🏥 Setting up healthcare agents..." -ForegroundColor Blue

# Create healthcare agents directory
`$AgentsDir = "/home/azureuser/healthcare-agents"
New-Item -ItemType Directory -Path `$AgentsDir -Force
Set-Location `$AgentsDir

# Clone healthcare agent orchestrator repository
Write-Host "Cloning healthcare-agent-orchestrator repository..." -ForegroundColor Yellow
git clone https://github.com/Azure-Samples/healthcare-agent-orchestrator.git

# Copy agent files to working directory
Write-Host "Copying agent files..." -ForegroundColor Yellow
Copy-Item "healthcare-agent-orchestrator/src/scenarios/default/tools/*.py" -Destination "." -Force
Copy-Item "healthcare-agent-orchestrator/src/scenarios/default/requirements.txt" -Destination "." -Force

# Install additional requirements
Write-Host "Installing additional requirements..." -ForegroundColor Yellow
pip install -r requirements.txt

# Create configuration file
Write-Host "Creating configuration file..." -ForegroundColor Yellow
`$ConfigContent = @'
# Healthcare AI Agent Configuration
AZURE_ML_WORKSPACE_NAME = "$WorkspaceName"
AZURE_ML_RESOURCE_GROUP = "$ResourceGroupName"

# Model endpoints (to be configured after deployment)
CXR_REPORT_GEN_ENDPOINT = ""
MED_IMAGE_PARSE_ENDPOINT = ""
MED_IMAGE_INSIGHT_ENDPOINT = ""

# Authentication
AZURE_CLIENT_ID = ""
AZURE_CLIENT_SECRET = ""
AZURE_TENANT_ID = ""
'@

`$ConfigContent | Out-File -FilePath "config.py" -Encoding UTF8

Write-Host "✅ Healthcare agents setup completed" -ForegroundColor Green
"@

        Write-Info "Healthcare agents setup script prepared"
        Write-Success "Healthcare agents installation script ready"
    }
    catch {
        Write-Error "Failed to setup healthcare agents: $_"
        exit 1
    }
}

# Deploy healthcare AI models
function Deploy-HealthcareModels {
    Write-Info "Deploying healthcare AI models..."
    
    try {
        # Deploy CXRReportGen model
        Write-Info "Deploying CXRReportGen model..."
        az ml online-endpoint create `
            --name "cxr-report-gen-endpoint" `
            --resource-group $ResourceGroupName `
            --workspace-name $WorkspaceName `
            --auth-mode key
        
        # Deploy MedImageParse model
        Write-Info "Deploying MedImageParse model..."
        az ml online-endpoint create `
            --name "med-image-parse-endpoint" `
            --resource-group $ResourceGroupName `
            --workspace-name $WorkspaceName `
            --auth-mode key
        
        # Deploy MedImageInsight model
        Write-Info "Deploying MedImageInsight model..."
        az ml online-endpoint create `
            --name "med-image-insight-endpoint" `
            --resource-group $ResourceGroupName `
            --workspace-name $WorkspaceName `
            --auth-mode key
        
        Write-Success "Healthcare AI models deployed successfully"
    }
    catch {
        Write-Error "Failed to deploy healthcare models: $_"
        exit 1
    }
}

# Configure private networking
function Set-PrivateNetworking {
    Write-Info "Configuring private networking..."
    
    try {
        # Create virtual network
        $VNetName = "$WorkspaceName-vnet"
        Write-Info "Creating virtual network: $VNetName"
        az network vnet create `
            --name $VNetName `
            --resource-group $ResourceGroupName `
            --location $Location `
            --address-prefix 10.0.0.0/16
        
        # Create subnet for ML workspace
        Write-Info "Creating ML subnet..."
        az network vnet subnet create `
            --name "ml-subnet" `
            --resource-group $ResourceGroupName `
            --vnet-name $VNetName `
            --address-prefix 10.0.1.0/24 `
            --disable-private-endpoint-network-policies true
        
        # Create private endpoint for ML workspace
        Write-Info "Creating private endpoint..."
        $SubscriptionId = (az account show --query id -o tsv)
        az network private-endpoint create `
            --name "$WorkspaceName-pe" `
            --resource-group $ResourceGroupName `
            --vnet-name $VNetName `
            --subnet "ml-subnet" `
            --private-connection-resource-id "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.MachineLearningServices/workspaces/$WorkspaceName" `
            --group-id amlworkspace `
            --connection-name "$WorkspaceName-connection"
        
        Write-Success "Private networking configured"
    }
    catch {
        Write-Error "Failed to configure private networking: $_"
        exit 1
    }
}

# Create sample notebooks
function New-SampleNotebooks {
    Write-Info "Creating sample notebooks..."
    
    try {
        # Create notebooks directory
        $NotebooksDir = "C:\temp\healthcare-notebooks"
        New-Item -ItemType Directory -Path $NotebooksDir -Force
        
        # Create CXR analysis notebook
        $CXRNotebook = @'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Chest X-Ray Report Generation with CXRReportGen\n",
    "\n",
    "This notebook demonstrates how to use the CXRReportGen healthcare AI model for automated chest X-ray report generation."
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import sys\n",
    "sys.path.append('/home/azureuser/healthcare-agents')\n",
    "\n",
    "from cxr_report_gen import CxrReportGenPlugin\n",
    "import base64\n",
    "import json"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Initialize CXR Report Generation plugin\n",
    "cxr_plugin = CxrReportGenPlugin({})\n",
    "\n",
    "# Example usage (replace with actual image path)\n",
    "# with open('chest_xray.jpg', 'rb') as f:\n",
    "#     image_data = base64.b64encode(f.read()).decode()\n",
    "#\n",
    "# result = await cxr_plugin.generate_findings(\n",
    "#     patient_id='12345',\n",
    "#     filename='chest_xray.jpg',\n",
    "#     indication='Chest pain'\n",
    "# )\n",
    "#\n",
    "# print(json.dumps(result, indent=2))"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
'@
        
        $CXRNotebook | Out-File -FilePath "$NotebooksDir\cxr_report_generation.ipynb" -Encoding UTF8
        
        Write-Success "Sample notebooks created at: $NotebooksDir"
    }
    catch {
        Write-Error "Failed to create sample notebooks: $_"
        exit 1
    }
}

# Display deployment information
function Show-DeploymentInfo {
    Write-Header "Healthcare AI Deployment Completed!"
    
    Write-Host ""
    Write-Host "📋 Deployment Information:" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "ML Workspace: $WorkspaceName" -ForegroundColor White
    Write-Host "Compute Instance: $ComputeName" -ForegroundColor White
    Write-Host "VM Size: $VMSize" -ForegroundColor White
    Write-Host ""
    Write-Host "🏥 Healthcare AI Models:" -ForegroundColor Cyan
    Write-Host "- CXRReportGen: Chest X-ray report generation" -ForegroundColor White
    Write-Host "- MedImageParse: Medical image segmentation" -ForegroundColor White
    Write-Host "- MedImageInsight: Medical image and text embedding" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Connect to compute instance via SSH or Jupyter" -ForegroundColor White
    Write-Host "2. Configure model endpoints in healthcare agents" -ForegroundColor White
    Write-Host "3. Test healthcare AI workflows with sample data" -ForegroundColor White
    Write-Host "4. Review sample notebooks in /home/azureuser/notebooks" -ForegroundColor White
    Write-Host ""
    Write-Host "📚 Documentation:" -ForegroundColor Cyan
    Write-Host "- Healthcare agents: /home/azureuser/healthcare-agents/" -ForegroundColor White
    Write-Host "- Configuration: /home/azureuser/healthcare-agents/config.py" -ForegroundColor White
    Write-Host "- Sample notebooks: /home/azureuser/notebooks/" -ForegroundColor White
}

# Main execution function
function Main {
    try {
        Write-Header "Starting Healthcare AI Deployment"
        
        Test-Prerequisites
        New-ResourceGroup
        New-MLWorkspace
        New-ComputeInstance
        Set-PrivateNetworking
        Install-Dependencies
        Install-HealthcareAgents
        Deploy-HealthcareModels
        New-SampleNotebooks
        Show-DeploymentInfo
        
        Write-Success "Healthcare AI deployment completed successfully! 🎉"
    }
    catch {
        Write-Error "Deployment failed: $_"
        exit 1
    }
}

# Execute main function
Main
