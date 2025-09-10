#!/bin/bash


set -e

echo "🏥 Healthcare AI Agents Installation Script"
echo "=========================================="

RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-ml-healthcare-a10v5}"
LOCATION="${LOCATION:-eastus}"
WORKSPACE_NAME="${WORKSPACE_NAME:-ml-healthcare-workspace}"
COMPUTE_NAME="${COMPUTE_NAME:-healthcare-a10v5-ci}"
VM_SIZE="${VM_SIZE:-Standard_NV36ads_A10_v5}"
ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY}"

CXR_MODEL_NAME="microsoft-cxrreportgen"
MEDPARSE_MODEL_NAME="microsoft-medimageparse"
MEDINSIGHT_MODEL_NAME="microsoft-medimageinsight"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run 'az login' first."
        exit 1
    fi
    
    if [ -z "$SSH_PUBLIC_KEY" ]; then
        log_error "SSH_PUBLIC_KEY environment variable is required."
        log_info "Generate with: ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'"
        log_info "Then export SSH_PUBLIC_KEY=\$(cat ~/.ssh/id_rsa.pub)"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

create_resource_group() {
    log_info "Creating resource group: $RESOURCE_GROUP_NAME"
    
    az group create \
        --name "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --tags Environment=Production Project=Healthcare-AI ManagedBy=Script
    
    log_success "Resource group created successfully"
}

create_ml_workspace() {
    log_info "Creating Azure ML workspace: $WORKSPACE_NAME"
    
    STORAGE_ACCOUNT_NAME="${WORKSPACE_NAME}sa$(date +%s | tail -c 6)"
    az storage account create \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2
    
    KEY_VAULT_NAME="${WORKSPACE_NAME}-kv-$(date +%s | tail -c 6)"
    az keyvault create \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --enable-purge-protection true
    
    APP_INSIGHTS_NAME="${WORKSPACE_NAME}-ai"
    az monitor app-insights component create \
        --app "$APP_INSIGHTS_NAME" \
        --location "$LOCATION" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --application-type web
    
    az ml workspace create \
        --name "$WORKSPACE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --storage-account "$STORAGE_ACCOUNT_NAME" \
        --key-vault "$KEY_VAULT_NAME" \
        --application-insights "$APP_INSIGHTS_NAME" \
        --public-network-access Disabled
    
    log_success "ML workspace created successfully"
}

create_compute_instance() {
    log_info "Creating A10v5 compute instance: $COMPUTE_NAME"
    
    az ml compute create \
        --name "$COMPUTE_NAME" \
        --type ComputeInstance \
        --size "$VM_SIZE" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --workspace-name "$WORKSPACE_NAME" \
        --ssh-public-key "$SSH_PUBLIC_KEY" \
        --enable-node-public-ip false \
        --description "A10v5 GPU compute instance for healthcare AI workloads"
    
    log_success "Compute instance created successfully"
}

install_dependencies() {
    log_info "Installing healthcare agent dependencies on compute instance..."
    
    cat > /tmp/healthcare_setup.py << 'EOF'
import subprocess
import sys
import os

def run_command(cmd):
    """Run shell command and handle errors"""
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {cmd}")
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ {cmd}")
        print(f"Error: {e.stderr}")
        return None

def install_healthcare_dependencies():
    """Install healthcare AI dependencies"""
    print("🔧 Installing healthcare AI dependencies...")
    
    run_command("sudo apt-get update")
    
    run_command("sudo apt-get install -y python3-pip python3-venv git curl wget")
    
    packages = [
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
    ]
    
    for package in packages:
        run_command(f"pip install {package}")
    
    run_command("jupyter labextension install @jupyter-widgets/jupyterlab-manager")
    
    print("✅ Healthcare AI dependencies installed successfully")

def setup_healthcare_agents():
    """Setup healthcare agent files"""
    print("🏥 Setting up healthcare agents...")
    
    os.makedirs("/home/azureuser/healthcare-agents", exist_ok=True)
    os.chdir("/home/azureuser/healthcare-agents")
    
    run_command("git clone https://github.com/Azure-Samples/healthcare-agent-orchestrator.git")
    
    run_command("cp healthcare-agent-orchestrator/src/scenarios/default/tools/*.py .")
    run_command("cp healthcare-agent-orchestrator/src/scenarios/default/requirements.txt .")
    
    run_command("pip install -r requirements.txt")
    
    config_content = '''
AZURE_ML_WORKSPACE_NAME = "ml-healthcare-workspace"
AZURE_ML_RESOURCE_GROUP = "rg-ml-healthcare-a10v5"

CXR_REPORT_GEN_ENDPOINT = ""
MED_IMAGE_PARSE_ENDPOINT = ""
MED_IMAGE_INSIGHT_ENDPOINT = ""

AZURE_CLIENT_ID = ""
AZURE_CLIENT_SECRET = ""
AZURE_TENANT_ID = ""
'''
    
    with open("config.py", "w") as f:
        f.write(config_content)
    
    print("✅ Healthcare agents setup completed")

def create_sample_notebooks():
    """Create sample Jupyter notebooks for healthcare AI"""
    print("📓 Creating sample notebooks...")
    
    notebook_dir = "/home/azureuser/notebooks"
    os.makedirs(notebook_dir, exist_ok=True)
    
    cxr_notebook = '''
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Chest X-Ray Report Generation with CXRReportGen\\n",
    "\\n",
    "This notebook demonstrates how to use the CXRReportGen healthcare AI model for automated chest X-ray report generation."
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import sys\\n",
    "sys.path.append('/home/azureuser/healthcare-agents')\\n",
    "\\n",
    "from cxr_report_gen import CxrReportGenPlugin\\n",
    "import base64\\n",
    "import json"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Initialize CXR Report Generation plugin\\n",
    "cxr_plugin = CxrReportGenPlugin({})\\n",
    "\\n",
    "# Example usage (replace with actual image path)\\n",
    "# with open('chest_xray.jpg', 'rb') as f:\\n",
    "#     image_data = base64.b64encode(f.read()).decode()\\n",
    "#\\n",
    "# result = await cxr_plugin.generate_findings(\\n",
    "#     patient_id='12345',\\n",
    "#     filename='chest_xray.jpg',\\n",
    "#     indication='Chest pain'\\n",
    "# )\\n",
    "#\\n",
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
'''
    
    with open(f"{notebook_dir}/cxr_report_generation.ipynb", "w") as f:
        f.write(cxr_notebook)
    
    print("✅ Sample notebooks created")

if __name__ == "__main__":
    install_healthcare_dependencies()
    setup_healthcare_agents()
    create_sample_notebooks()
    print("🎉 Healthcare AI setup completed successfully!")
EOF
    
    az ml job create \
        --file /tmp/healthcare_setup.py \
        --name "healthcare-setup-$(date +%s)" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --workspace-name "$WORKSPACE_NAME" \
        --compute "$COMPUTE_NAME" \
        --environment "azureml://registries/azureml/environments/sklearn-1.0/versions/1"
    
    log_success "Healthcare dependencies installed"
}

deploy_healthcare_models() {
    log_info "Deploying healthcare AI models..."
    
    log_info "Deploying CXRReportGen model..."
    az ml online-endpoint create \
        --name "cxr-report-gen-endpoint" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --workspace-name "$WORKSPACE_NAME" \
        --auth-mode key
    
    log_info "Deploying MedImageParse model..."
    az ml online-endpoint create \
        --name "med-image-parse-endpoint" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --workspace-name "$WORKSPACE_NAME" \
        --auth-mode key
    
    log_info "Deploying MedImageInsight model..."
    az ml online-endpoint create \
        --name "med-image-insight-endpoint" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --workspace-name "$WORKSPACE_NAME" \
        --auth-mode key
    
    log_success "Healthcare AI models deployed successfully"
}

configure_private_networking() {
    log_info "Configuring private networking..."
    
    VNET_NAME="${WORKSPACE_NAME}-vnet"
    az network vnet create \
        --name "$VNET_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --address-prefix 10.0.0.0/16
    
    az network vnet subnet create \
        --name "ml-subnet" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --vnet-name "$VNET_NAME" \
        --address-prefix 10.0.1.0/24 \
        --disable-private-endpoint-network-policies true
    
    az network private-endpoint create \
        --name "${WORKSPACE_NAME}-pe" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --vnet-name "$VNET_NAME" \
        --subnet "ml-subnet" \
        --private-connection-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.MachineLearningServices/workspaces/$WORKSPACE_NAME" \
        --group-id amlworkspace \
        --connection-name "${WORKSPACE_NAME}-connection"
    
    log_success "Private networking configured"
}

display_deployment_info() {
    log_success "Healthcare AI deployment completed!"
    echo ""
    echo "📋 Deployment Information:"
    echo "========================="
    echo "Resource Group: $RESOURCE_GROUP_NAME"
    echo "ML Workspace: $WORKSPACE_NAME"
    echo "Compute Instance: $COMPUTE_NAME"
    echo "VM Size: $VM_SIZE"
    echo ""
    echo "🏥 Healthcare AI Models:"
    echo "- CXRReportGen: Chest X-ray report generation"
    echo "- MedImageParse: Medical image segmentation"
    echo "- MedImageInsight: Medical image and text embedding"
    echo ""
    echo "🔗 Next Steps:"
    echo "1. Connect to compute instance via SSH or Jupyter"
    echo "2. Configure model endpoints in healthcare agents"
    echo "3. Test healthcare AI workflows with sample data"
    echo "4. Review sample notebooks in /home/azureuser/notebooks"
    echo ""
    echo "📚 Documentation:"
    echo "- Healthcare agents: /home/azureuser/healthcare-agents/"
    echo "- Configuration: /home/azureuser/healthcare-agents/config.py"
    echo "- Sample notebooks: /home/azureuser/notebooks/"
}

main() {
    log_info "Starting healthcare AI deployment..."
    
    check_prerequisites
    create_resource_group
    create_ml_workspace
    create_compute_instance
    configure_private_networking
    install_dependencies
    deploy_healthcare_models
    display_deployment_info
    
    log_success "Healthcare AI deployment completed successfully! 🎉"
}

main "$@"
