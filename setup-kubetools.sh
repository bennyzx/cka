#!/bin/bash
# Description: This script supports Ubuntu 22.04.2 LTS, used to install kubeadm, kubelet, and kubectl
# Maintainer: Benny Zhou<benny_zhou2004@hotmail.com  E59D5D30499A535F>
# More about kubeadm installation instructions, please refer
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# Run this script with sudo
if ! [ $USER = root ]
then
	echo ENT-ERR: run this script with sudo
	exit 1
fi

# Setup MYOS variable
MYOS=$(hostnamectl | awk '/Operating/ { print $3 }')
OSVERSION=$(hostnamectl | awk '/Operating/ { print $4 }')

# Setup os architecture: arm64 (also known as aarch64), amd64(also known as x86_64)
[ $(arch) = aarch64 ] && PLATFORM=arm64
[ $(arch) = x86_64 ] && PLATFORM=amd64

# Specify cri-tools version 
CRICTLVERSION=$1
if [ -z $CRICTLVERSION ]; then
        echo "ENT-ERR: No Param Found: Please specify one version cri-tools!!!"
        exit 1
fi

if [ $MYOS = "Ubuntu" ]
then
	############### Install kubeadm, kubelet, and kubectl
	echo RUNNING UBUNTU CONFIG
	cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
	br_netfilter
EOF
	
	sudo apt-get update && sudo apt-get install -y apt-transport-https curl
	sudo curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -
	cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
	deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
EOF
	sudo apt-get update
	sudo apt-get install -y kubelet kubeadm kubectl
	sudo apt-mark hold kubelet kubeadm kubectl
	swapoff -a	
	sed -i 's/\/swap/#\/swap/' /etc/fstab

	############### Install cri-tools
        # Download cri-tools release with the command
        wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTLVERSION}/crictl-${CRICTLVERSION}-linux-${PLATFORM}.tar.gz 
        # Download the cri-tools checksum file, and validate cri-tools release against checksum file
	wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTLVERSION}/crictl-${CRICTLVERSION}-linux-${PLATFORM}.tar.gz.sha256sum 
        [ $(echo $(cat crictl-${CRICTLVERSION}-linux-${PLATFORM}.tar.gz.sha256sum) | sha256sum --check | awk '{print $2}') != 'OK' ] && \
                (echo "ENT-WARN: crictl FAIlED: sha256sum: WARNING: 1 computed checksum did not match!!!"; exit 1)
        tar xvf crictl-${CRICTLVERSION}-linux-${PLATFORM}.tar.gz
        sudo mv bin/* /usr/bin/	
fi

# Set iptables bridging
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

sudo crictl config --set \
    runtime-endpoint=unix:///var/run/containerd/containerd.sock
echo 'after initializing the control node, follow instructions and use kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml to install the calico plugin (control node only). On the worker nodes, use sudo kubeadm join ... to join'
