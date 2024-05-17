#!/bin/bash
apt-get update -y
apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg

mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
chmod go+r /etc/apt/keyrings/microsoft.gpg

AZ_REPO=$(lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list

apt-get update -y && \
  apt-get install -y azure-cli wget curl vim openssl git 

git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git /root/kubernetes-the-hard-way

cd /root/kubernetes-the-hard-way
mkdir downloads
wget -q --show-progress \
  --https-only \
  --timestamping \
  -P downloads \
  -i downloads.txt
