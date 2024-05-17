# Kubernetes the hard way notes

- [Kubernetes the hard way notes](#kubernetes-the-hard-way-notes)
  - [01 Pre-requisites](#01-pre-requisites)
  - [Set Up The Jumpbox](#set-up-the-jumpbox)
  - [Provisioning Compute Resources](#provisioning-compute-resources)
    - [Set up ssh access as root](#set-up-ssh-access-as-root)
    - [Set up hostnames](#set-up-hostnames)
    - [Set up DNS](#set-up-dns)
  - [Provisioning a CA and Generating TLS Certificates](#provisioning-a-ca-and-generating-tls-certificates)
  - [Generating Kubernetes Configuration Files for Authentication](#generating-kubernetes-configuration-files-for-authentication)
    - [Kubelet kubeconfig file](#kubelet-kubeconfig-file)
      - [Background information](#background-information)
      - [Steps](#steps)
    - [Kubeproxy kubeconfig file](#kubeproxy-kubeconfig-file)
      - [Background](#background)
      - [Steps](#steps-1)
    - [kube-controller-manager kubeconfig file](#kube-controller-manager-kubeconfig-file)
      - [Background](#background-1)
      - [Steps](#steps-2)
    - [kube-scheduler kubeconfig file](#kube-scheduler-kubeconfig-file)
      - [Background](#background-2)
      - [Steps](#steps-3)
    - [admin user kubeconfig file](#admin-user-kubeconfig-file)
    - [Distributing the kubeconfig files](#distributing-the-kubeconfig-files)
      - [Nodes](#nodes)
      - [Controller instance](#controller-instance)
  - [Generating the Data Encryption Config and Key](#generating-the-data-encryption-config-and-key)
  - [Bootstrapping the etcd Cluster](#bootstrapping-the-etcd-cluster)
    - [Pre-requisites](#pre-requisites)
    - [Bootstrapping etcd](#bootstrapping-etcd)
  - [Bootstrapping the Kubernetes Control Plane](#bootstrapping-the-kubernetes-control-plane)
    - [Copy over the binaries to server](#copy-over-the-binaries-to-server)
    - [Set up the Kubernetes Control Plane](#set-up-the-kubernetes-control-plane)
    - [RBAC for Kubelet Authorization](#rbac-for-kubelet-authorization)
  - [Bootstrapping the Kubernetes Worker Nodes](#bootstrapping-the-kubernetes-worker-nodes)
    - [Pre-requisites](#pre-requisites-1)
    - [Setup individual nodes](#setup-individual-nodes)
  - [Configuring kubectl for Remote Access](#configuring-kubectl-for-remote-access)
    - [The Admin Kubernetes Configuration File](#the-admin-kubernetes-configuration-file)
  - [Pod Network Routes](#pod-network-routes)
  - [Smoke Test](#smoke-test)
    - [Test ability to encrypt secrets at rest](#test-ability-to-encrypt-secrets-at-rest)
    - [Ability to create and manage Deployments](#ability-to-create-and-manage-deployments)
    - [Access applications remotely using port forwarding](#access-applications-remotely-using-port-forwarding)
    - [Check container logs](#check-container-logs)
    - [Exec into a container](#exec-into-a-container)
    - [Create and use a Service](#create-and-use-a-service)
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

## Set Up The Jumpbox

As per the instructions in [Jumpbox](docs/02-jumpbox.md) 

The [userdata.sh](infra/userdata.sh) file we used for our jumpbox saved us some work installing dependencies, 
downloading the git repository and downloading the software:

We can connect to the jumpbox and check the downloads look good:

```bash
azureuser@vm-k8s-hard-way ~$ sudo su
root@vm-k8s-hard-way:/home/azureuser/# cd /root/kubernetes-the-hard-way
root@vm-k8s-hard-way:/root/kubernetes-the-hard-way# ls -loh downloads
total 584M
-rw-r--r-- 1 root  41M May  9  2023 cni-plugins-linux-arm64-v1.3.0.tgz
-rw-r--r-- 1 root  34M Oct 26  2023 containerd-1.7.8-linux-arm64.tar.gz
-rw-r--r-- 1 root  22M Aug 14  2023 crictl-v1.28.0-linux-arm.tar.gz
-rw-r--r-- 1 root  15M Jul 11  2023 etcd-v3.4.27-linux-arm64.tar.gz
-rw-r--r-- 1 root 111M Oct 18  2023 kube-apiserver
-rw-r--r-- 1 root 107M Oct 18  2023 kube-controller-manager
-rw-r--r-- 1 root  51M Oct 18  2023 kube-proxy
-rw-r--r-- 1 root  52M Oct 18  2023 kube-scheduler
-rw-r--r-- 1 root  46M Oct 18  2023 kubectl
-rw-r--r-- 1 root 101M Oct 18  2023 kubelet
-rw-r--r-- 1 root 9.6M Aug 11  2023 runc.arm64
```

That looks good so we can now install `kubectl`:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# {
  chmod +x downloads/kubectl
  cp downloads/kubectl /usr/local/bin/
}
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# kubectl version --client
Client Version: v1.28.3
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
```

## Provisioning Compute Resources

As per the instructions in [Compute Resources](docs/03-compute-resources.md)

### Set up ssh access as root

- Created the [machines.txt](./infra/machines.txt) file as suggested
- Allowed root ssh by setting **PermitRootLogin yes** `/etc/ssh/sshd_config` (typically not a good idea due to security risk) then restarted ssh with `systemctl restart sshd`
- generated a root key and distributed - I deviated slightly from the suggested as Azure did not like me using **ssh-copy-id**:

```bash 
ssh-keygen -t rsa -b 4096 -N ""
cat ~/.ssh/id_rsa.pub
```

Next we copy the output and log onto each node and update the contents of `/home/root/.ssh/authorized_keys` to match.

We can now test connectivity:

```bash
while read IP FQDN HOST SUBNET; do 
  ssh -n root@${IP} uname -o -m
done < machines.txt
```

### Set up hostnames

Although there is a command provided that should automatically update the `/etc/hosts` on each node this did not work for me so I manually replaced the lines like:

```text
127.0.0.1   localhost
```

with a line like this

```text
127.0.0.1   node-0.kubernetes.local node-0
```

Note: looking more closely the sed command provided likely fails as it is **127.0.0.1** not **127.0.1.1**

but I was able to verify the hostnames were set on each machine:

```bash
while read IP FQDN HOST SUBNET; do
  ssh -n root@${IP} hostname --fqdn
done < machines.txt
```

```text
server.kubernetes.local
node-0.kubernetes.local
node-1.kubernetes.local
```

### Set up DNS

I only needed a slight modification:

```bash
echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts
while read IP FQDN HOST SUBNET; do 
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY >> hosts
done < machines.txt
cat hosts | sudo tee -a /etc/hosts
```

but was able to validate as suggested after acceting messages like:

```text
The authenticity of host 'server (10.99.1.4)' can't be established.
ED25519 key fingerprint is SHA256:G62OUb9TvwyBB/pbrgYkLvNkvRRJd3DF7bb2cbz0jFg.
This host key is known by the following other names/addresses:
    ~/.ssh/known_hosts:1: [hashed name]
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'server' (ED25519) to the list of known hosts.
server aarch64 GNU/Linux
```

## Provisioning a CA and Generating TLS Certificates

As per the instructions in [Certificate Authority](docs/04-certificate-authority.md)

- navigate to `/root/kubernetes-the-hard-way` on the jumpbox (where we checked out the git repo with `ca.conf`)
- make directory `certs` copy `ca.conf` inside and then cd into it
- generate a self-signed root key and cert:
```bash
{
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -sha512 -noenc \
    -key ca.key -days 3653 \
    -config ca.conf \
    -out ca.crt
}
```
- define all the required certs:
```bash
# array listing all the certs we need
certs=(
  "admin" "node-0" "node-1"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

# for each array entry
for i in ${certs[*]}; do
  # generate a new key 
  openssl genrsa -out "${i}.key" 4096

  # generate a certificate signing request
  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"
  
  # sign the CSR with the root CA key
  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done
```

The output looks like this:

```text
Certificate request self-signature ok
subject=CN = admin, O = system:masters
Certificate request self-signature ok
subject=CN = system:node:node-0, O = system:nodes, C = US, ST = Washington, L = Seattle
Certificate request self-signature ok
subject=CN = system:node:node-1, O = system:nodes, C = US, ST = Washington, L = Seattle
Certificate request self-signature ok
subject=CN = system:kube-proxy, O = system:node-proxier, C = US, ST = Washington, L = Seattle
Certificate request self-signature ok
subject=CN = system:kube-scheduler, O = system:system:kube-scheduler, C = US, ST = Washington, L = Seattle
Certificate request self-signature ok
subject=CN = system:kube-controller-manager, O = system:kube-controller-manager, C = US, ST = Washington, L = Seattle
Certificate request self-signature ok
subject=CN = kubernetes, C = US, ST = Washington, L = Seattle
Certificate request self-signature ok
subject=CN = service-accounts
```

and the full listing of certs now looks like this:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way/certs# ls -loh
total 116K
-rw-r--r-- 1 root 2.0K May 16 14:42 admin.crt
-rw-r--r-- 1 root 1.8K May 16 14:42 admin.csr
-rw------- 1 root 3.2K May 16 14:42 admin.key
-rw-r--r-- 1 root 5.8K May 15 15:15 ca.conf
-rw-r--r-- 1 root 1.9K May 16 14:38 ca.crt
-rw------- 1 root 3.2K May 16 14:38 ca.key
-rw-r--r-- 1 root   41 May 16 14:43 ca.srl
-rw-r--r-- 1 root 2.3K May 16 14:43 kube-api-server.crt
-rw-r--r-- 1 root 2.2K May 16 14:43 kube-api-server.csr
-rw------- 1 root 3.2K May 16 14:43 kube-api-server.key
-rw-r--r-- 1 root 2.2K May 16 14:43 kube-controller-manager.crt
-rw-r--r-- 1 root 2.0K May 16 14:43 kube-controller-manager.csr
-rw------- 1 root 3.2K May 16 14:43 kube-controller-manager.key
-rw-r--r-- 1 root 2.2K May 16 14:43 kube-proxy.crt
-rw-r--r-- 1 root 2.0K May 16 14:43 kube-proxy.csr
-rw------- 1 root 3.2K May 16 14:43 kube-proxy.key
-rw-r--r-- 1 root 2.2K May 16 14:43 kube-scheduler.crt
-rw-r--r-- 1 root 2.0K May 16 14:43 kube-scheduler.csr
-rw------- 1 root 3.2K May 16 14:43 kube-scheduler.key
-rw-r--r-- 1 root 2.1K May 16 14:42 node-0.crt
-rw-r--r-- 1 root 2.0K May 16 14:42 node-0.csr
-rw------- 1 root 3.2K May 16 14:42 node-0.key
-rw-r--r-- 1 root 2.1K May 16 14:43 node-1.crt
-rw-r--r-- 1 root 2.0K May 16 14:43 node-1.csr
-rw------- 1 root 3.2K May 16 14:43 node-1.key
-rw-r--r-- 1 root 2.0K May 16 14:43 service-accounts.crt
-rw-r--r-- 1 root 1.8K May 16 14:43 service-accounts.csr
-rw------- 1 root 3.2K May 16 14:43 service-accounts.key
```

We can now copy machines.txt to our certs folder and distribute the certs:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way/certs# cp /home/azureuser/machines.txt .
root@vm-k8s-hard-way:~/kubernetes-the-hard-way/certs# for host in node-0 node-1; do
  ssh root@$host mkdir /var/lib/kubelet/

  scp ca.crt root@$host:/var/lib/kubelet/

  scp $host.crt \
    root@$host:/var/lib/kubelet/kubelet.crt

  scp $host.key \
    root@$host:/var/lib/kubelet/kubelet.key
done
The authenticity of host 'node-0 (10.99.1.5)' can't be established.
ED25519 key fingerprint is SHA256:B6mORvLYeT6wkk+2qpirlK7HU1dyzYZGWuuqIwyOSmo.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'node-0' (ED25519) to the list of known hosts.
root@node-0: Permission denied (publickey).
root@node-0: Permission denied (publickey).
scp: Connection closed
root@node-0: Permission denied (publickey).
scp: Connection closed
root@node-0: Permission denied (publickey).
scp: Connection closed
```

So it bombed out totally...

I realised this is because when I ran the ssh-keygen on the jumphost I was `azureuser` not `root` so to fix this I ran:

```bash
sudo su - root
root@vm-k8s-hard-way:~# cd .ssh
root@vm-k8s-hard-way:~/.ssh# cp /home/azureuser/.ssh/id_rsa .
root@vm-k8s-hard-way:~/.ssh# cp /home/azureuser/.ssh/id_rsa.pub .
```

So now we can copy as expected and copy the certificates. and run the following to copy the remaining ones to the server:

```bash
scp \
  ca.key ca.crt \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  root@server:~/
```

## Generating Kubernetes Configuration Files for Authentication

As per the instructions in [Kubernetes Configuration Files](docs/05-kubernetes-configuration-files.md)

### Kubelet kubeconfig file

#### Background information

From the [docs](https://kubernetes.io/docs/concepts/overview/components/#kubelet) 

> Kubelet: An agent that runs on each node in the cluster. It makes sure that containers are running in a Pod.
>
> The kubelet takes a set of PodSpecs that are provided through various mechanisms and ensures that the containers described in those PodSpecs are running and healthy. The kubelet doesn't manage containers which were not created by Kubernetes.

When generating kubeconfig files for Kubelets the client certificate matching the Kubelet's node name must be used. 
This will ensure Kubelets are properly authorized by the Kubernetes [Node Authorization](https://kubernetes.io/docs/reference/access-authn-authz/node/).

> Node authorization is a special-purpose authorization mode that specifically authorizes API requests made by kubelets.
>
> In order to be authorized by the Node authorizer, kubelets must use a credential that identifies them as being in the system:nodes group, with a username of system:node:<nodeName>. This group and user name format match the identity created for each kubelet as part of kubelet TLS bootstrapping.
>
> The value of <nodeName> must match precisely the name of the node as registered by the kubelet. By default, this is the host name as provided by hostname, or overridden via the kubelet option --hostname-override. However, when using the --cloud-provider kubelet option, the specific hostname may be determined by the cloud provider, ignoring the local hostname and the --hostname-override option. For specifics about how the kubelet determines the hostname, see the kubelet options reference.
>
> To enable the Node authorizer, start the apiserver with --authorization-mode=Node.

#### Steps

Ran the following (as `root` on the jumpbox)

```bash
cd /root/kubernetes-the-hard-way/certs
for host in node-0 node-1; do
  # define cluster
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=${host}.kubeconfig

  # define the node credentials
  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  # Set up the node user context
  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  # Set the current-context in the kubeconfig file
  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
done
```

which successfully produces this output:

```text
Cluster "kubernetes-the-hard-way" set.
User "system:node:node-0" set.
Context "default" created.
Switched to context "default".
Cluster "kubernetes-the-hard-way" set.
User "system:node:node-1" set.
Context "default" created.
Switched to context "default".
```

and these files:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way/certs# ls *.kubeconfig
node-0.kubeconfig  node-1.kubeconfig
```

### Kubeproxy kubeconfig file

#### Background 

From the [docs](https://kubernetes.io/docs/concepts/overview/components/#kube-proxy)

> kube-proxy is a network proxy that runs on each node in your cluster, implementing part of the Kubernetes Service concept.
>
> kube-proxy maintains network rules on nodes. These network rules allow network communication to your Pods from network sessions inside or outside of your cluster.
>
> kube-proxy uses the operating system packet filtering layer if there is one and it's available. Otherwise, kube-proxy forwards the traffic itself.

#### Steps

Just used the command from **The kubelet Kubernetes Configuration File** in the docs unchanged

### kube-controller-manager kubeconfig file

#### Background

from the [docs](https://kubernetes.io/docs/concepts/overview/components/#kube-controller-manager)

> kube-controller-manager : Control plane component that runs controller processes.
>
> Logically, each controller is a separate process, but to reduce complexity, they are all compiled into a single binary and run in a single process.
> 
> There are many different types of controllers. Some examples of them are:
>
> - Node controller: Responsible for noticing and responding when nodes go down.
> - Job controller: Watches for Job objects that represent one-off tasks, then creates Pods to run those tasks to completion.
> - EndpointSlice controller: Populates EndpointSlice objects (to provide a link between Services and Pods).
> - ServiceAccount controller: Create default ServiceAccounts for new namespaces.
> 
> The above is not an exhaustive list.

#### Steps

Just used the command from **The kube-controller-manager Kubernetes Configuration File** in the docs unchanged

### kube-scheduler kubeconfig file

#### Background

from the [docs](https://kubernetes.io/docs/concepts/overview/components/#kube-scheduler)

> Control plane component that watches for newly created Pods with no assigned node, and selects a node for them to run on.
>
> Factors taken into account for scheduling decisions include: individual and collective resource requirements, hardware/software/policy constraints, affinity and anti-affinity specifications, data locality, inter-workload interference, and deadlines.

#### Steps

Just used the command from **The kube-scheduler Kubernetes Configuration File** in the docs unchanged

### admin user kubeconfig file

Just ran command provided in **The admin Kubernetes Configuration File** in the docs unchanged

### Distributing the kubeconfig files

#### Nodes

The nodes need the `kubelet` and `kube-proxy` kubeconfig files:

```bash
for host in node-0 node-1; do
  ssh root@$host "mkdir /var/lib/{kube-proxy,kubelet}"
  
  scp kube-proxy.kubeconfig \
    root@$host:/var/lib/kube-proxy/kubeconfig \
  
  scp ${host}.kubeconfig \
    root@$host:/var/lib/kubelet/kubeconfig
done
```

which gives this output:

```text
mkdir: cannot create directory ‘/var/lib/kubelet’: File exists
kube-proxy.kubeconfig
node-0.kubeconfig
mkdir: cannot create directory ‘/var/lib/kubelet’: File exists
kube-proxy.kubeconfig
node-1.kubeconfig
```

Note: the File exists errors are ok as we created the directories when distributing the certificates

#### Controller instance

The controller / server instance needs the `kube-controller-manager` and `kube-scheduler` kubeconfig files (plus the `admin` user):

```bash
scp admin.kubeconfig \
  kube-controller-manager.kubeconfig \
  kube-scheduler.kubeconfig \
  root@server:~/
```

## Generating the Data Encryption Config and Key

As per the instructions in [Data Encryption Keys](docs/06-data-encryption-keys.md)


From the [docs](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)

> All of the APIs in Kubernetes that let you write persistent API resource data support at-rest encryption. For example, you can enable at-rest 
> encryption for Secrets. This at-rest encryption is additional to any system-level encryption for the etcd cluster or for the filesystem(s) on 
> hosts where you are running the kube-apiserver.

First we generate an encryption key:

```bash
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

Note: The configs directory was missing the file specified in the instructions! This documentation [encryption config](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#understanding-the-encryption-at-rest-configuration) and this [issue](https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/768) helped me find it should look like this:

```yaml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
```

with this context saved to `configs/encryption-config.yaml ` we can run the suggested commands:

```bash
# substitute in the encryption key
envsubst < configs/encryption-config.yaml > encryption-config.yaml

# copy to the controller instance
scp encryption-config.yaml root@server:~/
```

## Bootstrapping the etcd Cluster

As per the instructions in [Bootstrapping etcd](docs/07-bootstrapping-etcd.md)

### Pre-requisites

- Copy over the systemd unit and executable for etcd to the controller instance:

```bash
scp downloads/etcd-v3.4.27-linux-arm64.tar.gz units/etcd.service root@server:~/
```

- Connect to the controller instance: `ssh root@server` for the rest of the setup

### Bootstrapping etcd

- Extract etcd and etcdctl as per the docs **Install the etcd Binaries**

- Check the binaries are there:

```bash
root@server:~# ls /usr/local/bin/
etcd  etcdctl
```

- Configure etcd:

```bash
mkdir -p /etc/etcd /var/lib/etcd
chmod 700 /var/lib/etcd
cp ca.crt kube-api-server.key kube-api-server.crt /etc/etcd/
mv etcd.service /etc/systemd/system/
```

_ start etcd

```bash
{
  systemctl daemon-reload
  systemctl enable etcd
  systemctl start etcd
}
```

- verify all is well:

```bash
root@server:~# etcdctl member list
6702b0a34e2cfd39, started, controller, http://127.0.0.1:2380, http://127.0.0.1:2379, false
```

## Bootstrapping the Kubernetes Control Plane

As per the instructions in [Bootstrapping Kubernetes Controllers](docs/08-bootstrapping-kubernetes-controllers.md)

With etcd running we now install the control plan components again on the `server` instance. We need the following components will be 
installed the controller machine: Kubernetes API Server, Scheduler, and Controller Manager.

### Copy over the binaries to server

Firstly we copy over the required binaries, systemd units and yamls for:

- [Kubernetes API Server](https://kubernetes.io/docs/concepts/overview/components/#kube-apiserver)
- [Kubernetes Scheduler](https://kubernetes.io/docs/concepts/overview/components/#kube-scheduler)
- [Kubernetes Controller Manager](https://kubernetes.io/docs/concepts/overview/components/#kube-controller-manager)

from the jumpbox to the server:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# scp \
  downloads/kube-apiserver \
  downloads/kube-controller-manager \
  downloads/kube-scheduler \
  downloads/kubectl \
  units/kube-apiserver.service \
  units/kube-controller-manager.service \
  units/kube-scheduler.service \
  configs/kube-scheduler.yaml \
  configs/kube-apiserver-to-kubelet.yaml \
  root@server:~/
```

we can then move back to the server for the remaining steps with `ssh root@server`

### Set up the Kubernetes Control Plane

- install the binaries for `kube-apiserver`, `kube-controller-manager` and `kube-scheduler`:

```bash
mkdir -p /etc/kubernetes/config
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
```

- Configure the Kubernetes API Server by placing the relevant keys, certificates and our encryption config:

```bash
mkdir -p /var/lib/kubernetes/
mv ca.crt ca.key kube-api-server.key kube-api-server.crt \
   service-accounts.key service-accounts.crt encryption-config.yaml \
   /var/lib/kubernetes/
mv kube-apiserver.service /etc/systemd/system/kube-apiserver.service
```

- Configure the Kubernetes Controller Manager:

```bash
mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
mv kube-controller-manager.service /etc/systemd/system/
```

- Configure the Kubernetes Scheduler:

```bash
mv kube-scheduler.kubeconfig /var/lib/kubernetes/
mv kube-scheduler.yaml /etc/kubernetes/config/
mv kube-scheduler.service /etc/systemd/system/
```

- Start the Controller Services

```bash
root@server:~# {
  systemctl daemon-reload

  systemctl enable kube-apiserver \
    kube-controller-manager kube-scheduler

  systemctl start kube-apiserver \
    kube-controller-manager kube-scheduler
}
Created symlink /etc/systemd/system/multi-user.target.wants/kube-apiserver.service → /etc/systemd/system/kube-apiserver.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service → /etc/systemd/system/kube-controller-manager.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-scheduler.service → /etc/systemd/system/kube-scheduler.service.
```

- Check it is working:

```bash
root@server:~# kubectl cluster-info \
  --kubeconfig admin.kubeconfig
Kubernetes control plane is running at https://127.0.0.1:6443
```

### RBAC for Kubelet Authorization

Next configure RBAC permissions to allow the Kubernetes API Server to access the Kubelet API on each worker node. 

Access to the Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

Here we set the Kubelet `--authorization-mode` flag to `Webhook`. Webhook mode uses the SubjectAccessReview API to determine authorization.
See [Controlling Access to the Kubernetes API](https://kubernetes.io/docs/concepts/security/controlling-access/) and
[Webhook Mode](https://kubernetes.io/docs/reference/access-authn-authz/webhook/) for more details

First we create the `system:kube-apiserver-to-kubelet` [ClusterRole](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole)
with permissions to access the Kubelet API and perform most common tasks associated with managing pods

The role yaml is defined [here](./configs/kube-apiserver-to-kubelet.yaml) but the key thing is it grants all verbs on:

```yaml
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
```

we apply it with:

```bash
kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig admin.kubeconfig
```

and validate from the jumpbox `certs` directory with:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way/certs# curl -k --cacert ca.crt https://server.kubernetes.local:6443/version
{
  "major": "1",
  "minor": "28",
  "gitVersion": "v1.28.3",
  "gitCommit": "a8a1abc25cad87333840cd7d54be2efaf31a3177",
  "gitTreeState": "clean",
  "buildDate": "2023-10-18T11:33:18Z",
  "goVersion": "go1.20.10",
  "compiler": "gc",
  "platform": "linux/arm64"
}
```


## Bootstrapping the Kubernetes Worker Nodes

As per the instructions in [Bootstrapping Kubernetes Workers](docs/09-bootstrapping-kubernetes-workers.md)

### Pre-requisites

- Copy over the Kubernetes configuration, binaries and systemd unit to each node replacing the subnet CIDR with the `machines.txt` value:

```bash
for host in node-0 node-1; do
  SUBNET=$(grep $host machines.txt | cut -d " " -f 4)
  sed "s|SUBNET|$SUBNET|g" configs/10-bridge.conf > 10-bridge.conf  
  sed "s|SUBNET|$SUBNET|g" configs/kubelet-config.yaml > kubelet-config.yaml  
  scp 10-bridge.conf kubelet-config.yaml root@$host:~/
done

for host in node-0 node-1; do
  scp \
    downloads/runc.arm64 \
    downloads/crictl-v1.28.0-linux-arm.tar.gz \
    downloads/cni-plugins-linux-arm64-v1.3.0.tgz \
    downloads/containerd-1.7.8-linux-arm64.tar.gz \
    downloads/kubectl \
    downloads/kubelet \
    downloads/kube-proxy \
    configs/99-loopback.conf \
    configs/containerd-config.toml \
    configs/kubelet-config.yaml \
    configs/kube-proxy-config.yaml \
    units/containerd.service \
    units/kubelet.service \
    units/kube-proxy.service \
    root@$host:~/
done
```

### Setup individual nodes

The remaining setup needs to occur on the nodes so we can start with `ssh root@node-0`:

- install OS dependencies:

```bash
apt-get update && apt-get -y install socat conntrack ipset
```

- By default, the kubelet will fail to start if [swap](https://help.ubuntu.com/community/SwapFaq) is enabled. We can 
see if swap is enabled by looking for non empty output from `swapon --show` if it is enabled we can disable it with `swapoff -a`.
`swapon --show` was empty for me so no action required

- Create the install directories:

```bash
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
```

- Install the binaries:

```bash
{
  mkdir -p containerd
  tar -xvf crictl-v1.28.0-linux-arm.tar.gz
  tar -xvf containerd-1.7.8-linux-arm64.tar.gz -C containerd
  tar -xvf cni-plugins-linux-arm64-v1.3.0.tgz -C /opt/cni/bin/
  mv runc.arm64 runc
  chmod +x crictl kubectl kube-proxy kubelet runc 
  mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
  mv containerd/bin/* /bin/
}
```

- Configure CNI Networking by adding the `bridge` network configuration file:

```bash
mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
```

- Install the `containerd` configuration files:

```bash
{
  mkdir -p /etc/containerd/
  mv containerd-config.toml /etc/containerd/config.toml
  mv containerd.service /etc/systemd/system/
}
```

- Configure the Kubelet by creating the `kubelet-config.yaml` configuration file:

```bash
{
  mv kubelet-config.yaml /var/lib/kubelet/
  mv kubelet.service /etc/systemd/system/
}
```

- Configure the Kubernetes Proxy

```bash
{
  mv kube-proxy-config.yaml /var/lib/kube-proxy/
  mv kube-proxy.service /etc/systemd/system/
}
```

- Start the Worker Services

```bash
{
  systemctl daemon-reload
  systemctl enable containerd kubelet kube-proxy
  systemctl start containerd kubelet kube-proxy
}
```

- Validate everything is working (note we need to run from server as it has permissions required)

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# ssh root@server \
  "kubectl get nodes \
  --kubeconfig admin.kubeconfig"
NAME     STATUS   ROLES    AGE   VERSION
node-0   Ready    <none>   25s   v1.28.3
node-1   Ready    <none>   28s   v1.28.3
```

## Configuring kubectl for Remote Access

As per the instructions in [Configuring kubectl](docs/10-configuring-kubectl.md)

Here we generate a kubeconfig file for the `kubectl` command line utility based on the `admin` user credentials.

### The Admin Kubernetes Configuration File

Each kubeconfig requires a Kubernetes API Server to connect to. You should be able to ping `server.kubernetes.local` based on the `/etc/hosts` DNS entry from a previous lap. Generate a kubeconfig file suitable for authenticating as the `admin` user:

```bash
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.crt \
    --client-key=admin.key

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}
```

Note: this is pretty much a duplicate of the step **The admin Kubernetes Configuration File** in [docs/05-kubernetes-configuration-files.md](./docs/05-kubernetes-configuration-files.md#) but note here we write the result to `~/.kube/config` which is the default location for the `kubectl` commandline tool.


we can validate all is well with:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way/certs# kubectl version
Client Version: v1.28.3
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Server Version: v1.28.3
root@vm-k8s-hard-way:~/kubernetes-the-hard-way/certs# kubectl get nodes
NAME     STATUS   ROLES    AGE   VERSION
node-0   Ready    <none>   14m   v1.28.3
node-1   Ready    <none>   14m   v1.28.3
```

## Pod Network Routes

As per the instructions in [Pod Network Routes](docs/11-pod-network-routes.md)

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network [routes](https://cloud.google.com/compute/docs/vpc/routes).

- extract key details from `machines.txt`:

```bash
{
  SERVER_IP=$(grep server machines.txt | cut -d " " -f 1)
  NODE_0_IP=$(grep node-0 machines.txt | cut -d " " -f 1)
  NODE_0_SUBNET=$(grep node-0 machines.txt | cut -d " " -f 4)
  NODE_1_IP=$(grep node-1 machines.txt | cut -d " " -f 1)
  NODE_1_SUBNET=$(grep node-1 machines.txt | cut -d " " -f 4)
}
```

- validate this worked fine by printing them:

```bash
{
  echo "SERVER_IP=$SERVER_IP"
  echo "NODE_0_IP=$NODE_0_IP"
  echo "NODE_0_SUBNET=$NODE_0_SUBNET"
  echo "NODE_1_IP=$NODE_1_IP"
  echo "NODE_1_SUBNET=$NODE_1_SUBNET"
}
SERVER_IP=10.99.1.4
NODE_0_IP=10.99.1.5
NODE_0_SUBNET=10.200.0.0/24
NODE_1_IP=10.99.1.6
NODE_1_SUBNET=10.200.1.0/24
```

- Add the routes to the IP tables of the VMs:

```bash
ssh root@server <<EOF
  ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
  ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
EOF

ssh root@node-0 <<EOF
  ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
EOF

ssh root@node-1 <<EOF
  ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
EOF
```

- Validate the controller/server VM:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# ssh root@server ip route
default via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.4 metric 100
10.99.1.0/24 dev eth0 proto kernel scope link src 10.99.1.4 metric 100
10.99.1.1 dev eth0 proto dhcp scope link src 10.99.1.4 metric 100
10.200.0.0/24 via 10.99.1.5 dev eth0
10.200.1.0/24 via 10.99.1.6 dev eth0
168.63.129.16 via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.4 metric 100
169.254.169.254 via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.4 metric 100
```

Note the key entries are there i.e.:

```text
10.200.0.0/24 via 10.99.1.5 dev eth0
10.200.1.0/24 via 10.99.1.6 dev eth0
```

- Validate node-0

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# ssh root@node-0 ip route
default via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.5 metric 100
10.99.1.0/24 dev eth0 proto kernel scope link src 10.99.1.5 metric 100
10.99.1.1 dev eth0 proto dhcp scope link src 10.99.1.5 metric 100
10.200.1.0/24 via 10.99.1.6 dev eth0
168.63.129.16 via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.5 metric 100
169.254.169.254 via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.5 metric 100
```

Here the key entries are:

```text
default via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.5 metric 100
10.200.1.0/24 via 10.99.1.6 dev eth0
10.99.1.0/24 dev eth0 proto kernel scope link src 10.99.1.5 metric 100
```

- Validate node-1

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# ssh root@node-1 ip route
default via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.6 metric 100
10.99.1.0/24 dev eth0 proto kernel scope link src 10.99.1.6 metric 100
10.99.1.1 dev eth0 proto dhcp scope link src 10.99.1.6 metric 100
10.200.0.0/24 via 10.99.1.5 dev eth0
168.63.129.16 via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.6 metric 100
169.254.169.254 via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.6 metric 100
```

and here the key entries are:

```text
default via 10.99.1.1 dev eth0 proto dhcp src 10.99.1.6 metric 100
10.200.0.0/24 via 10.99.1.5 dev eth0
10.99.1.0/24 dev eth0 proto kernel scope link src 10.99.1.6 metric 100
```

## Smoke Test

As per the instructions in [Smoke Test](docs/12-smoke-test.md)

### Test ability to encrypt secrets at rest

- Create a test secret:

```bash
kubectl create secret generic kubernetes-the-hard-way --from-literal="mykey=mydata"
```

- Print a hexdump of the `kubernetes-the-hard-way` secret stored in etcd:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# ssh root@server \
    'etcdctl get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C'
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
00000040  3a 76 31 3a 6b 65 79 31  3a e5 6e 8e 63 96 c7 a5  |:v1:key1:.n.c...|
00000050  54 36 31 bd 82 78 74 fd  0d 8b b5 3e dd ee 3f 9b  |T61..xt....>..?.|
00000060  98 4f aa 27 74 74 78 53  83 11 83 58 aa 43 ce f6  |.O.'ttxS...X.C..|
00000070  47 e4 a3 8e 27 5c 59 4f  3b fa f0 b9 0e 63 3b f0  |G...'\YO;....c;.|
00000080  e7 fa 4a 6a 7c c9 07 dd  99 a6 e3 75 58 87 19 31  |..Jj|......uX..1|
00000090  94 1b 71 e5 52 5e 19 a6  18 16 08 ab 34 23 ab c8  |..q.R^......4#..|
000000a0  c3 44 c2 29 50 44 79 62  89 81 1b e4 c7 26 a9 63  |.D.)PDyb.....&.c|
000000b0  65 c8 c4 20 eb 16 86 a0  9b 93 fd a3 5d fd a1 db  |e.. ........]...|
000000c0  c8 c3 80 b3 56 cc 8a 06  76 a9 d1 d6 36 4e e5 c3  |....V...v...6N..|
000000d0  82 04 8c 43 29 94 f6 3e  b8 38 d4 1e 6d 87 38 b5  |...C)..>.8..m.8.|
000000e0  cd f0 22 c4 c1 48 33 86  e9 8d 78 8e 99 dd 14 0c  |.."..H3...x.....|
000000f0  aa 98 6b d4 9d b8 ca 80  bc 00 b4 44 cb e3 39 53  |..k........D..9S|
00000100  2d 6b 5c 32 5d c5 12 eb  cb 3f 3b 93 6a ed bc b8  |-k\2]....?;.j...|
00000110  d1 21 df 9b ea 1e 4d cd  78 a4 ef a6 38 0c 3d b9  |.!....M.x...8.=.|
00000120  e6 8e e9 ae 74 4c eb 5c  de 38 09 4d 43 36 25 16  |....tL.\.8.MC6%.|
00000130  1c 3a 6b c6 ff 5b 7f 56  b5 95 f5 40 86 e5 8c 5b  |.:k..[.V...@...[|
00000140  c9 10 4d 97 33 a3 0b ee  a5 3c 18 af c7 63 98 a0  |..M.3....<...c..|
00000150  30 5e 75 33 13 9a 6c bf  cf 0a                    |0^u3..l...|
0000015a
```

The etcd key should be prefixed with `k8s:enc:aescbc:v1:key1`, which indicates the `aescbc` provider was used to encrypt the data with the `key1` encryption key.

**RESULT** PASS

### Ability to create and manage Deployments

In this section we verify the ability to create and manage [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) by 
deploying nginx:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# kubectl create deployment nginx --image=nginx:latest
kubectl get pods -l app=nginx
deployment.apps/nginx created
NAME                     READY   STATUS    RESTARTS   AGE
nginx-56fcf95486-4b7jz   0/1     Pending   0          0s
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# kubectl get pods -l app=nginx
NAME                     READY   STATUS              RESTARTS   AGE
nginx-56fcf95486-4b7jz   0/1     ContainerCreating   0          6s
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# kubectl get pods -l app=nginx
NAME                     READY   STATUS    RESTARTS   AGE
nginx-56fcf95486-4b7jz   1/1     Running   0          8s
```

**RESULT** PASS

### Access applications remotely using port forwarding

In this section we verify the ability to access applications remotely using [port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).

```bash
# Retrieve the full name of the `nginx` pod:
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
# Port forward from local port 8080 to nginx pod port 80 (put in bg)
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# kubectl port-forward $POD_NAME 8080:80 &
[1] 5695
# hit local port 8080 and validate it forwards to nginx
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
curl --head http://127.0.0.1:8080
Handling connection for 8080
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Fri, 17 May 2024 13:41:36 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 16 Apr 2024 14:29:59 GMT
Connection: keep-alive
ETag: "661e8b67-267"
Accept-Ranges: bytes
```

**RESULT** PASS

### Check container logs

```bash
kubectl logs $POD_NAME
```

validate that the pod logs are displayed, took the 200 response from our curl request:

```text
27.0.0.1 - - [17/May/2024:13:41:36 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.88.1" "-"
```

**RESULT** PASS

### Exec into a container

```bash
kubectl exec -ti $POD_NAME -- nginx -v
```

result:

```text 
nginx version: nginx/1.25.5
```

**RESULT** PASS

### Create and use a Service

```bash 
kubectl expose deployment nginx --port 80 --type NodePort
NODE_PORT=$(kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
curl -I http://node-0:${NODE_PORT}
```

with the result it just hanged but then I tried:

```bash
curl -I http://node-1:${NODE_PORT}
```

and got the expected response:

```bash
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Fri, 17 May 2024 13:49:34 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 16 Apr 2024 14:29:59 GMT
Connection: keep-alive
ETag: "661e8b67-267"
Accept-Ranges: bytes
```

Looking into this I can see that the pod is running on node-1:

```bash
root@vm-k8s-hard-way:~/kubernetes-the-hard-way# kubectl get pod -l app=nginx -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE   READINESS GATES
nginx-56fcf95486-4b7jz   1/1     Running   0          14m   10.200.1.2   node-1   <none>           <none>
```

There are some issues like [this one](https://github.com/kubernetes/kubernetes/issues/58908) that suggest while the `NodePort` should be 
accessible on all nodes in the cluster a Cloud firewall can cause issues as can some network plugins...

**RESULT** FAIL

I decided to give it one last chanceby stopping all the nodes then starting them all and seeing if that helps but it did not...

In a final roll of the dice I added the 10.200.0.0/16 address space to the VNET to see if that helped - it should not really as that is the pod address space
but it is a last attempt so did that and then ran the connection troubleshoot in Azure which gave:

```text
Results					
    Test(s) ran: 	Connectivity; NSG diagnostic; Next hop; Port scanner				
    Source: 	vm-k8s-hard-way				
    Destination: 	node-0				
                        
Diagnostic tests		

Test	                        Status	    Details			
Connectivity test	                        Unreachable	Probes sent: 30; probes failed: 30			
Outbound NSG diagnostic	        Allow	    Outbound communication to destination is allowed			
Inbound NSG diagnostic	        Allow	    Inbound communication to destination is allowed			
Next hop (from source)	        Success	    Next hop type: Virtual Network; Route table: System Route			
Destination port accessible	    Timeout				
                    
Hop details	

Name	            Status	    IP address	    Next hop	    Round Trip Time	Errors
vm-k8s-hard-way	    Healthy	    10.99.0.4	    10.99.1.5		
node-0	            Healthy	    10.99.1.5			
```

So it does look like a cloud issue rather than anything wrong with the cluster nodes and so as such we will leave it for now... 


## Cleanup

As per the instructions in [Cleanup](docs/13-cleanup.md)

```bash
az group delete -n rg-k8s-hard-way --no-wait
```