#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

echo "(-) Download the Kubernetes etcd binary"
wget -q --show-progress --https-only --continue \
  "https://github.com/coreos/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz"

tar -xzf etcd-${ETCD_VER}-linux-amd64.tar.gz

for instance in lxdk8s-m0 lxdk8s-m1 lxdk8s-m2; do

echo ">>> Bootstrapping the Kubernetes etcd of ${instance}"

echo "(0) Upgrade and Install the OS dependencies of ${instance}"
if [ ${APT_PROXY} != "noproxy" ] ; then
cat > ubuntu-apt-proxy.conf <<EOF
Acquire::http::Proxy  "${APT_PROXY}";
Acquire::https::Proxy "${APT_PROXY}";
EOF

lxc file push ubuntu-apt-proxy.conf ${instance}/etc/apt/apt.conf.d/proxy.conf
fi

lxc exec ${instance} -- apt -y update
lxc exec ${instance} -- apt -y upgrade
lxc exec ${instance} -- apt -y autoremove

echo "(1) Install the Kubernetes etcd Binaries of ${instance}"
lxc file push etcd-${ETCD_VER}-linux-amd64/etcd* ${instance}/usr/local/bin/

echo "(2) Configure the Kubernetes etcd of ${instance}"
lxc exec ${instance} -- mkdir -p /etc/etcd /var/lib/etcd
lxc file push ca.pem kubernetes-key.pem kubernetes.pem ${instance}/etc/etcd/

INTERNAL_IP=$(lxc info ${instance} | grep eth0 | head -1 | awk '{print $3}')

ETCD_NAME=${instance}

cat > ${instance}-etcd.service <<EOF 
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster lxdk8s-m0=https://${M0_IP}:2380,lxdk8s-m1=https://${M1_IP}:2380,lxdk8s-m2=https://${M2_IP}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

lxc file push ${instance}-etcd.service ${instance}/etc/systemd/system/etcd.service

echo "(3) Starting the Kubernetes etcd server of ${instance}"
lxc exec ${instance} -- systemctl daemon-reload
lxc exec ${instance} -- systemctl enable etcd
lxc exec ${instance} -- systemctl start etcd

done

echo "(-) Verify the Kubernetes etcd deployment"
echo "(-) Connect to any controller and execute the following command"
echo " >  lxc exec lxdk8s-m0 -- bash"
echo " >  ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem"

