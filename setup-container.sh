#!/bin/bash
# Description: This script used to install containerd  
# Maintainer: Benny Zhou<benny_zhou2004@hotmail.com  E59D5D30499A535F>
# More on kubernetes CRI, please refer https://kubernetes.io/docs/setup/production-environment/container-runtime
# More on containerd, please refer https://github.com/containerd/containerd

# Set MYOS variable
MYOS=$(hostnamectl | awk '/Operating/ { print $3 }')
OSVERSION=$(hostnamectl | awk '/Operating/ { print $4 }')
# Specify containerd version 
CONTAINERDVERSION=1.7.1
RUNCVERSION=1.1.7
if [ -z $CONTAINERDVERSION ]; then
	echo "ENT-ERR: No Param Found: Please specify one version containerd!!!"
	exit 1
fi
# Setup os architecture: arm64 (also known as aarch64), amd64(also known as x86_64)
[ $(arch) = aarch64 ] && PLATFORM=arm64
[ $(arch) = x86_64 ] && PLATFORM=amd64

if [ $MYOS = "Ubuntu" ]
then
	########### Forward IPv4 and make iptables see bridge traffic  ###########
	### setting up container runtime prereq
	cat <<- EOF | sudo tee /etc/modules-load.d/containerd.conf
	overlay
	br_netfilter
	EOF
	sudo modprobe overlay
	sudo modprobe br_netfilter
	# Setup required sysctl params, these persist across reboots.
	cat <<- EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
	net.bridge.bridge-nf-call-iptables  = 1
	net.ipv4.ip_forward                 = 1
	net.bridge.bridge-nf-call-ip6tables = 1
	EOF
	# Apply sysctl params without reboot
	sudo sysctl --system

	########### Install containerd ###########
	# Install containerd
	#sudo apt-get update && sudo apt-get install -y containerd
	# hopefully temporary bugfix as the containerd version provided in Ubu repo is tool old
	# added Jan 26th 2023
	# this needs to be updated when a recent enough containerd version will be in Ubuntu repos
	#sudo systemctl stop containerd
	# cleanup old files from previous attempt if existing
	#[ -d bin ] && rm -rf bin

	# Download containerd release with the command
	wget -c https://github.com/containerd/containerd/releases/download/v${CONTAINERDVERSION}/containerd-${CONTAINERDVERSION}-linux-${PLATFORM}.tar.gz 
	# Download the containerd checksum file, and validate containerd release against checksum file
	#wget -c https://github.com/containerd/containerd/releases/download/v${CONTAINERDVERSION}/containerd-${CONTAINERDVERSION}-linux-${PLATFORM}.tar.gz.sha256sum
	#echo $(cat containerd-${CONTAINERDVERSION}-linux-${PLATFORM}.tar.gz.sha256sum) containerd-${CONTAINERDVERSION}-linux-${PLATFORM}.tar.gz | sha256sum --check
	#[ ! $? eq 0 ] && echo ENT-ERR: containerd FAIlED: sha256sum: WARNING: 1 computed checksum did not match!!!; exit 1
	sudo tar Cxvf /usr/local/ containerd-${CONTAINERDVERSION}-linux-${PLATFORM}.tar.gz
	#sudo rm -rf containerd-${CONTAINERDVERSION}-linux-${PLATFORM}.tar.gz containerd-${CONTAINERDVERSION}-linux-${PLATFORM}.tar.gz.sha256sum
	# Configure containerd
	sudo mkdir -p /etc/containerd
	cat <<- TOML | sudo tee /etc/containerd/config.toml
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      discard_unpacked_layers = true
      snapshotter = "overlayfs"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
	TOML

	# Restart containerd
	mkdir -p /usr/local/lib/systemd/system
	curl -fsSLo /usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
	sudo systemctl daemon-reload && sudo systemctl enable --now containerd

	########### Install runc ###########
        wget https://github.com/opencontainers/runc/releases/download/v${RUNCVERSION}/runc.arm64	
	sudo install -m 755 runc.arm64 /usr/local/sbin/runc
	which runc
	[ $? eq 0 ] && echo ENT-INF: runc succeeds.
fi

