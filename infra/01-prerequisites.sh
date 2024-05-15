#!/bin/bash
###########################################################################################
# This script is used to create the required Azure resources for the kubernetes hard way
###########################################################################################
set -e # Exit script immediately on first error.

LOG_FILE="infra.log"
###########################################################################################
# Variables
###########################################################################################
location="westeurope"
rgName="rg-k8s-hard-way"
nsgName="nsg-k8s"
vnetName="vnet-k8s-hard-way"
vnetAddressPrefix="10.99.0.0/16"
jumpboxSnetName="snet-jumpbox"
jumpboxSnetPrefix="10.99.0.0/24"
nodeSnetName="snet-k8s"
nodeSnetPrefix="10.99.1.0/24"

vmName="vm-k8s-hard-way"
vmUserName="azureuser"
sshPublicKey="$HOME/.ssh/id_rsa.pub"
node_ssh_locn="$(pwd)/.ssh/k8s.pub" 
ssh_locn="$(pwd)/.ssh/k8s"
node_ssh_folder="$(pwd)/.ssh/" 
jumpSku="Standard_B16ms" # "Standard_B8ms"
nodeSku="Standard_D4pds_v5" # Arm compatible

###########################################################################################
# Functions
###########################################################################################
# redirect all the following to a file for easy access but also print it to the console
function printAndLog() {
    echo "$1" | tee -a ${LOG_FILE}
}

###########################################################################################
# Create the resource groups
###########################################################################################
az group create --name $rgName --location $location

###########################################################################################
# Create a Virtual Network, NSGs and subnets
###########################################################################################
az network vnet create \
  --resource-group $rgName \
  --name $vnetName \
  --address-prefix $vnetAddressPrefix \
  --location $location \
  --subnet-name $jumpboxSnetName \
  --subnet-prefix $jumpboxSnetPrefix

az network vnet subnet create \
    --resource-group $rgName \
    --vnet-name $vnetName \
    --name $nodeSnetName \
    --address-prefixes $nodeSnetPrefix

# Create a Network Security Group
az network nsg create --resource-group $rgName --name $nsgName --location $location

for snet in $jumpboxSnetName $nodeSnetName; do
    az network vnet subnet update --resource-group $rgName --vnet-name $vnetName \
      --name "${snet}" --network-security-group $nsgName
done

###########################################################################################
# Create the jumpbox
###########################################################################################
az vm create \
  --resource-group $rgName \
  --name $vmName \
  --image Ubuntu2204 \
  --admin-username $vmUserName \
  --ssh-key-values "${sshPublicKey}" \
  --location $location \
  --size $jumpSku \
  --public-ip-address-allocation static \
  --vnet-name $vnetName \
  --subnet $jumpboxSnetName \
  --assign-identity \
  --user-data userdata.sh \
  --nsg ""

# Assign the identity Contributor access to RG
az role assignment create \
  --assignee "$(az vm identity show --resource-group $rgName --name $vmName --query principalId -o tsv)" \
  --role Contributor \
  --scope "$(az group show --resource-group $rgName --query id -o tsv)"

# Create a security rule to allow SSH from your IP address
az network nsg rule create \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name "AllowSSHFromMyPublicIP" \
    --priority 100 \
    --protocol Tcp \
    --direction Inbound \
    --source-address-prefixes "$(curl -s https://api.ipify.org)" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 22 \
    --access Allow 

###########################################################################################
# Create the nodes
###########################################################################################

# Create an ssh key pair for the nodes
ssh-keygen -t rsa -b 4096 -f "${ssh_locn}" -N ""

# Here we get the most current non-daily build of Debian 12 for ARM64
image=$(az vm image list --offer "debian-12" --publisher Debian --sku 12-arm64 --architecture Arm64 --all --output tsv --query "[?contains(offer, 'daily') == \`false\`]|[sort_by(@, &version)][].{urn:urn, version:version} | reverse(@)[0]" | cut -f1)
# Create the nodes
for v in server node-0 node-1; do
    az vm create \
        --resource-group $rgName \
        --name $v \
        --image "$image" \
        --admin-username $vmUserName \
        --ssh-key-values "${node_ssh_locn}" \
        --location $location \
        --size $nodeSku \
        --vnet-name $vnetName \
        --subnet $nodeSnetName \
        --public-ip-address "" \
        --nsg ""
done

# # Create NSG rule that allows SSH only from jumpbox subnet
az network nsg rule create \
    --resource-group $rgName \
    --nsg-name $nsgName \
    --name "AllowSSHFromJumpbox" \
    --priority 200 \
    --protocol Tcp \
    --direction Inbound \
    --source-address-prefixes $jumpboxSnetPrefix \
    --source-port-ranges "*" \
    --destination-port-ranges 22 \
    --destination-address-prefixes $nodeSnetPrefix


###########################################################################################
# Print the results
###########################################################################################

# Start with fresh file
rm ${LOG_FILE}

# Print the public IP address of the VM
printAndLog "OUTPUTS:"
printAndLog ""
printAndLog "JUMPBOX VM:"
printAndLog ""
vmip=$(az vm show --resource-group $rgName --name $vmName --show-details --query publicIps -o tsv)
printAndLog "vmip=$vmip"
printAndLog "ssh ${vmUserName}@${vmip}"
printAndLog ""
printAndLog "JUMPBOX SCP for SSH KEYS:"
printAndLog ""
printAndLog "scp -r ${node_ssh_folder} ${vmUserName}@${vmip}:~/"

# Print the VM private IPs
for v in server node-0 node-1; do
    # vmPrivateIp=$(az vm show --resource-group $rgName --name $v --query 'privateIps' --output tsv)
    vmPrivateIp=$(az vm list-ip-addresses --resource-group $rgName --name $v --query '[0].virtualMachine.network.privateIpAddresses[0]' -o tsv)
    printAndLog "NODE $v:"
    printAndLog ""
    printAndLog "vmPrivateIp=$vmPrivateIp"
    printAndLog "ssh -i ~/.ssh/k8s ${vmUserName}@${vmPrivateIp}"
done