#!/bin/bash


set -e

echo "🚀 Azure ML A10v5 Terraform Deployment"
echo "======================================"

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install Terraform first."
    echo "   Visit: https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install Azure CLI first."
    echo "   Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Please run 'az login' first."
    exit 1
fi

echo "✅ Prerequisites check passed"

if [ ! -f "terraform.tfvars" ]; then
    echo "⚠️  terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "📝 Please edit terraform.tfvars with your specific values before continuing."
    echo "   Key items to update:"
    echo "   - ssh_public_key: Your SSH public key"
    echo "   - resource_group_name: Your preferred resource group name"
    echo "   - location: Your preferred Azure region"
    echo "   - a10v5_vm_size: Your preferred A10v5 VM size"
    echo ""
    read -p "Press Enter after updating terraform.tfvars to continue..."
fi

echo "🔧 Initializing Terraform..."
terraform init

echo "🔍 Validating Terraform configuration..."
terraform validate

echo "📋 Planning deployment..."
terraform plan -out=tfplan

echo ""
echo "📊 Deployment Summary:"
echo "====================="
echo "The plan above shows what resources will be created."
echo "This includes:"
echo "- Azure ML Workspace with private endpoint"
echo "- A10v5 GPU compute instance"
echo "- Virtual network and subnets"
echo "- Key Vault, Storage Account, Application Insights"
echo "- Private DNS zones for secure access"
echo ""

read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Applying Terraform configuration..."
    terraform apply tfplan
    
    echo ""
    echo "✅ Deployment completed successfully!"
    echo ""
    echo "📋 Important outputs:"
    terraform output
    
    echo ""
    echo "🔗 Next steps:"
    echo "1. Access your ML workspace through the Azure portal"
    echo "2. Connect to the compute instance via SSH using your private key"
    echo "3. Start developing your ML models on the A10v5 GPU instance"
    echo ""
    echo "📚 For more information, see the README.md file"
else
    echo "❌ Deployment cancelled"
    rm -f tfplan
fi
