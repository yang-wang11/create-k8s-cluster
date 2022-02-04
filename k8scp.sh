#!/bin/bash
#/* **************** LFD259:2021-12-09 s_02/k8scp.sh **************** */
#/*
# * The code herein is: Copyright the Linux Foundation, 2022
# *
# * This Copyright is retained for the purpose of protecting free
# * redistribution of source.
# *
# *     URL:    https://training.linuxfoundation.org
# *     email:  info@linuxfoundation.org
# *
# * This code is distributed under Version 2 of the GNU General Public
# * License, which you should have received with the source.
# *
# */
#Version 1.22.1
sudo swapoff -a

# remove docker first if it installed
sudo apt-get remove docker docker-engine docker.io containerd runc

# Bring node to current versions and install an editor and other software
sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y vim nano libseccomp2

# Prepare for cri-o
sudo modprobe overlay
sudo modprobe br_netfilter
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf

sudo sysctl --system

# Add an alias for the local system to /etc/hosts
sudo sh -c "echo '$(hostname -i) cp' >> /etc/hosts"

# Set the versions to use
export OS=xUbuntu_18.04

export VERSION=1.22

#Add repos and keys   
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" | sudo tee -a /etc/apt/sources.list.d/cri-0.list

curl -L http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | sudo apt-key add -

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | sudo tee -a /etc/apt/sources.list.d/libcontainers.list

sudo apt-get update

# Install cri-o
sudo apt-get install -y cri-o cri-o-runc podman buildah

sleep 3

# Fix a bug, may not always be needed
sudo sed -i 's/,metacopy=on//g' /etc/containers/storage.conf


sleep 3

sudo systemctl daemon-reload

sudo systemctl enable crio

sudo systemctl start crio
# In case you need to check status:     systemctl status crio

# test cri-o
curl -v --unix-socket /var/run/crio/crio.sock http://localhost/info

crictl info


# Add Kubernetes repo and software 
sudo sh -c "echo 'deb http://mirrors.ustc.edu.cn/kubernetes/apt kubernetes-xenial main' >> /etc/apt/sources.list.d/kubernetes.list"

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt-get update

sudo apt-get install -y kubeadm=1.23.3-00 kubelet=1.23.3-00 kubectl=1.23.3-00


# Now install the cp using the kubeadm.yaml file from tarball
sudo kubeadm init --config=./kubeadm.yaml --control-plane-endpoint master:6443 --upload-certs -v=5 

sleep 2

echo "Running the steps explained at the end of the init output for you"

mkdir -p $HOME/.kube

sleep 2

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sleep 2

sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Apply Calico network plugin from ProjectCalico.org"
echo "If you see an error they may have updated the yaml file"
echo "Use a browser, navigate to the site and find the updated file"

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo

# Add alias for podman to docker for root and non-root user
echo "alias sudo="sudo "" | tee -a $HOME/.bashrc
echo "alias docker=podman" | tee -a $HOME/.bashrc

# Add Helm to make our life easier
wget https://get.helm.sh/helm-v3.7.0-linux-amd64.tar.gz
tar -xf helm-v3.7.0-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/

echo
sleep 3
echo "You should see this node in the output below"
echo "It can take up to a mintue for node to show Ready status"
echo
kubectl get node
echo
echo
echo "Script finished. Move to the next step"



# troubleshooting

## For the container runtime CRI-O

### be careful with initializing the cri-o service
### https://github.com/cri-o/cri-o/blob/main/tutorials/kubeadm.md

## if use the third part docker repo, it should be change following setting
root@master:~# cat /etc/crio/crio.conf
registries = [
  "registry.aliyuncs.com/google_containers"
]

root@master:~# cat /etc/containers/registries.conf
unqualified-search-registries = ["docker.io", "quay.io"]

[[registry]]
prefix = "k8s.gcr.io"
insecure = false
blocked = false
location = "k8s.gcr.io"

[[registry.mirror]]
location = "registry.aliyuncs.com/google_containers"

## chech the status of crio and kubelet
journalctl -u crio -f
crictl --runtime-endpoint unix:///var/run/crio/crio.sock ps -a 
crictl images

systemctl daemon-reload
systemctl restart kubelet
journalctl -u kubelet -S "1 min ago" | more
journalctl -u kubelet -f | more

## running logic
after the command `kubeadm init`, we should check the status of apiserver and etcd.
the kubelet will wait until apiserver is ready then try to register itself to apiserver. if the process is a success, we can see this machine from `kubectl get nodes`。


## sign the certs for kubelet if you are using a self-signed cert(not necessary)
## ca-config.json
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "8760h"
      }
    }
  }
}

## kubelet-csr.json
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "master",
    "slaver",
    "master*",
    "slaver*",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "US",
    "ST": "NY",
    "L": "City",
    "O": "Org",
    "OU": "Unit"
  }]
}

cfssl gencert -ca=/etc/kubernetes/pki/ca.crt -ca-key=/etc/kubernetes/pki/ca.key --config=ca-config.json -profile=kubernetes kubelet-csr.json | cfssljson -bare kubelet