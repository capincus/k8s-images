#! /bin/bash
set -eu

k8s_version="${1}"

cat > /etc/rc.local <<EOF
#!/bin/sh -e
# Ref: https://kevingoos.medium.com/kubernetes-inside-proxmox-lxc-cce5c9927942
# Kubeadm 1.15 needs /dev/kmsg to be there, but it’s not in lxc, but we can just use /dev/console instead
# see: https://github.com/kubernetes-sigs/kind/issues/662
if [ ! -e /dev/kmsg ]; then
  ln -s /dev/console /dev/kmsg
fi
# https://medium.com/@kvaps/run-kubernetes-in-lxc-container-f04aa94b6c9c
mount --make-rshared /
EOF
chmod 755 /etc/rc.local

/etc/rc.local
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg yq
# install containerd
curl -Lo /tmp/containerd.tar.gz https://github.com/containerd/containerd/releases/download/v2.0.1/containerd-2.0.1-linux-amd64.tar.gz
tar Cxzvf /usr/local /tmp/containerd.tar.gz
curl -L https://raw.githubusercontent.com/containerd/containerd/v2.0.1/containerd.service > /etc/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd
rm -f /tmp/containerd.tar.gz
# install runc
curl -Lo /usr/local/sbin/runc https://github.com/opencontainers/runc/releases/download/v1.2.3/runc.amd64
chmod 755 /usr/local/sbin/runc
rm -f /tmp/containerd.tar.gz
# install CNI plugins
mkdir -p /opt/cni/bin
curl -Lo /tmp/cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v1.6.1/cni-plugins-linux-amd64-v1.6.1.tgz
tar Cxzvf /opt/cni/bin /tmp/cni-plugins.tgz
VERSION="v1.30.0" # check latest version in /releases page
curl -Lo /tmp/crictl.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-${VERSION}-linux-amd64.tar.gz
sudo tar zxvf /tmp/crictl.tar.gz -C /usr/local/bin
rm -f /tmp/crictl.tar.gz
# install kubeadm, kubelet, kubectl
echo "$k8s_version" > /run/cluster-api/k8s-version
cat /run/cluster-api/k8s-version | yq -r 'match("v([0-9]+).([0-9]+).([0-9]+)") | .captures | "v" + .[0].string + "." + .[1].string' > /run/cluster-api/k8s-major-minor-version
curl -fsSL https://pkgs.k8s.io/core:/stable:/$(cat /run/cluster-api/k8s-major-minor-version)/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$(cat /run/cluster-api/k8s-major-minor-version)/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
