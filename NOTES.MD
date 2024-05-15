# Kubernetes the hard way notes

- [Kubernetes the hard way notes](#kubernetes-the-hard-way-notes)
  - [01 Pre-requisites](#01-pre-requisites)
  - [Jumpbox](#jumpbox)
  - [Compute Resources](#compute-resources)
  - [Certificate Authority](#certificate-authority)
  - [Kubernetes Configuration Files](#kubernetes-configuration-files)
  - [Data Encryption Keys](#data-encryption-keys)
  - [Bootstrapping etcd](#bootstrapping-etcd)
  - [Bootstrapping Kubernetes Controllers](#bootstrapping-kubernetes-controllers)
  - [Bootstrapping Kubernetes Workers](#bootstrapping-kubernetes-workers)
  - [Configuring kubectl](#configuring-kubectl)
  - [Pod Network Routes](#pod-network-routes)
  - [Smoke Test](#smoke-test)
  - [Cleanup](#cleanup)


## 01 Pre-requisites

As per the instructions in [Pre-requisites](docs/01-prerequisites.md) 

Firstly create VMs following the **Virtual or Physical Machines** section and validated connectivity:

- Run `infra/00-prerequisites.sh` to create the public facing jumphost 
- Copy the node ssh key pair to the jumphost using the scp command from infra.log e.g.

```bash
scp -r /Users/n18576/source/edoatley/kubernetes-the-hard-way/infra/.ssh/ azureuser@20.126.158.213:~/
```
- ssh login to the jumphost then ssh to the nodes to prove connectivity (using the ssh commands from infra.log):

```bash
ssh azureuser@20.126.158.213
azureuser@vm-k8s-hard-way ~ ssh -i ~/.ssh/k8s azureuser@10.99.1.4
azureuser@server:~$ 
azureuser@server:~$ exit
logout
azureuser@vm-k8s-hard-way ~ ssh -i ~/.ssh/k8s azureuser@10.99.1.5
azureuser@node-0:~$ 
azureuser@node-0:~$ exit
logout
azureuser@vm-k81-hard-way ~ ssh -i ~/.ssh/k8s azureuser@10.99.1.6
azureuser@node-1:~$ 
azureuser@node-1:~$ exit
logout
```

Finally validated the VM distribution:

```bash
azureuser@server:~$ uname -mov
#1 SMP Debian 6.1.90-1 (2024-05-03) aarch64 GNU/Linux
```

## Jumpbox

As per the instructions in [Jumpbox](docs/02-jumpbox.md) 



## Compute Resources

As per the instructions in [Compute Resources](docs/03-compute-resources.md)

## Certificate Authority

As per the instructions in [Certificate Authority](docs/04-certificate-authority.md)

## Kubernetes Configuration Files

As per the instructions in [Kubernetes Configuration Files](docs/05-kubernetes-configuration-files.md)

## Data Encryption Keys

As per the instructions in [Data Encryption Keys](docs/06-data-encryption-keys.md)

## Bootstrapping etcd

As per the instructions in [Bootstrapping etcd](docs/07-bootstrapping-etcd.md)

## Bootstrapping Kubernetes Controllers

As per the instructions in [Bootstrapping Kubernetes Controllers](docs/08-bootstrapping-kubernetes-controllers.md)

## Bootstrapping Kubernetes Workers

As per the instructions in [Bootstrapping Kubernetes Workers](docs/09-bootstrapping-kubernetes-workers.md)

## Configuring kubectl

As per the instructions in [Configuring kubectl](docs/10-configuring-kubectl.md)

## Pod Network Routes

As per the instructions in [Pod Network Routes](docs/11-pod-network-routes.md)

## Smoke Test

As per the instructions in [Smoke Test](docs/12-smoke-test.md)

## Cleanup

As per the instructions in [Cleanup](docs/13-cleanup.md)