#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd setup

echo "(-) Download the Kubernetes Worker Node binaries"
# hack the file name schema change in the CNI versions
wget -q --show-progress --https-only --continue \
  https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}.linux-amd64.tar.gz \
  https://github.com/containernetworking/plugins/releases/download/${CNI_VER}/cni-plugins-linux-amd64-${CNI_VER}.tgz \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_VER}/crictl-${CRI_VER}-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/${RUNC_VER}/runc.amd64 \
  https://storage.googleapis.com/gvisor/releases/nightly/${GVISOR_VER}/runsc \
  https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kubelet \
  https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kubectl 

chmod +x runc.amd64 runsc kube-proxy kubelet kubectl 
rm -f runc; ln -s runc.amd64 runc

for instance in lxdk8s-w0 lxdk8s-w1 lxdk8s-w2; do

echo ">>> Bootstraping the Kubernetes ${instance}"
echo "(0) Upgrade and install the OS dependencies of ${instance}"
if [ ${APT_PROXY} != "noproxy" ] ; then
cat > ubuntu-apt-proxy.conf <<EOF
Acquire::http::Proxy  "${APT_PROXY}";
Acquire::https::Proxy "${APT_PROXY}";
EOF

lxc file push ubuntu-apt-proxy.conf ${instance}/etc/apt/apt.conf.d/proxy.conf
fi

lxc exec ${instance} -- apt -y update
lxc exec ${instance} -- apt -y upgrade
lxc exec ${instance} -- apt -y install socat conntrack ipset
lxc exec ${instance} -- apt -y autoremove

echo "(1) Install the node binaries of ${instance}"
lxc exec ${instance} --  mkdir -p /etc/cni/net.d \
                                  /opt/cni/bin \
                                  /etc/containerd \
                                  /var/lib/kubelet \
                                  /var/lib/kube-proxy \
                                  /var/lib/kubernetes \
                                  /var/run/kubernetes

lxc file push  runc runsc kube-proxy kubelet kubectl ${instance}/usr/local/bin/

cat containerd-${CONTAINERD_VER}.linux-amd64.tar.gz | lxc exec ${instance} -- tar xzf - -C /
cat cni-plugins-linux-amd64-${CNI_VER}.tgz  | lxc exec ${instance} -- tar xzf - -C /opt/cni/bin/
cat crictl-${CRI_VER}-linux-amd64.tar.gz | lxc exec ${instance} -- tar xzf - -C /usr/local/bin/

echo "(2) Configure CNI Networking of ${instance}"
POD_CIDR=${POD_CIDR_NET[${instance}]}

cat > ${instance}-bridge.conf <<EOF
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

lxc file push ${instance}-bridge.conf ${instance}/etc/cni/net.d/10-bridge.conf

cat > ${instance}-loopback.conf <<EOF 
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF

lxc file push ${instance}-loopback.conf ${instance}/etc/cni/net.d/99-loopback.conf

echo "(3) Configure Containerd of ${instance}"
cat > ${instance}-containerd-config.toml <<EOF
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
    [plugins.cri.containerd.gvisor]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
EOF

lxc file push ${instance}-containerd-config.toml  ${instance}/etc/containerd/config.toml

cat > ${instance}-containerd.service <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
#ExecStartPre=/sbin/modprobe overlay -- LXD does not support overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
Environment="HTTP_PROXY=${CONTAINERD_PROXY}"

[Install]
WantedBy=multi-user.target
EOF

lxc file push ${instance}-containerd.service ${instance}/etc/systemd/system/containerd.service

echo "(4) Configure Kubelet of ${instance}"
lxc file push ${instance}-key.pem ${instance}.pem ${instance}/var/lib/kubelet/
lxc file push ${instance}.kubeconfig ${instance}/var/lib/kubelet/kubeconfig
lxc file push ca.pem ${instance}/var/lib/kubernetes/

cat > ${instance}-kubelet-config.yaml <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${instance}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${instance}-key.pem"
failSwapOn: false
EOF

lxc file push ${instance}-kubelet-config.yaml ${instance}/var/lib/kubelet/kubelet-config.yaml

cat > ${instance}-kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

#add option '--fail-swap-on=false' because LXD swap setting depend on host setting
[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --fail-swap-on=false \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

lxc file push ${instance}-kubelet.service ${instance}/etc/systemd/system/kubelet.service

echo "(5) Configure the Kubernetes Proxy of ${instance}"
lxc file push kube-proxy.kubeconfig ${instance}/var/lib/kube-proxy/kubeconfig

cat > ${instance}-kube-proxy-config.yaml <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

lxc file push ${instance}-kube-proxy-config.yaml ${instance}/var/lib/kube-proxy/kube-proxy-config.yaml

cat > ${instance}-kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

lxc file push ${instance}-kube-proxy.service ${instance}/etc/systemd/system/kube-proxy.service

echo "(6) Start the Worker Services of ${instance}"
lxc exec ${instance} -- systemctl daemon-reload
lxc exec ${instance} -- systemctl enable containerd kubelet kube-proxy
lxc exec ${instance} -- systemctl start containerd kubelet kube-proxy

echo "(7) Install the admin.kubeconfig of ${instance}"
lxc file push admin.kubeconfig ${instance}/root/

done

echo "(-) Verify the worker deployment"
sleep 15
lxc exec lxdk8s-m0 -- kubectl get nodes --kubeconfig admin.kubeconfig



