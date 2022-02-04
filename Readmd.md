this repository provides the following method to create a k8s cluster, these methods are leveraged by `kubeadm`.
* docker as CRI with configuration file (k8sSecond-docker.sh, k8sSecond-docker.sh, kubeadm-docker.yaml)
* cri-o as CRI  with configuration file  (k8scp.sh, k8sSecond.sh, kubeadm.yaml)
* docker as CRI  (PreviousDocker-k8sMaster.sh, PreviousDocker-k8sSecond.sh)

all these script were copied from LFD259.