#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

LXD_BRIDGE=$(lxc profile show default | grep parent | awk  '{print $2 }')

lxc storage create lxdk8s-dir dir 

echo ">>> Bootstrapping the Kubernetes LXD machines"
echo "(0) Create the LXDK8S Profile for Kubernetes machines"
cat > lxdk8s-profile.yaml <<EOF
config:
  limits.cpu: "2"
  limits.memory: 2GB
  limits.memory.swap: "false"
  linux.kernel_modules: ip_tables,ip6_tables,netlink_diag,nf_nat,overlay
  raw.lxc: |
    lxc.apparmor.profile=unconfined
    lxc.cap.drop= 
    lxc.cgroup.devices.allow=a
    lxc.mount.auto=proc:rw sys:rw
  security.privileged: "true"
  security.nesting: "true"
description: LXDK8S profile
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: ${LXD_BRIDGE}
    type: nic
  root:
    path: /
    pool: lxdk8s-dir
    type: disk
name: lxdk8s
used_by: []
EOF

lxc profile create lxdk8s 
lxc profile edit lxdk8s < lxdk8s-profile.yaml

if [ ${LXD_PROXY} != "noproxy" ] ; then
  echo "(-) Config the LXD Proxy to download images"
  lxc config set core.proxy_http ${LXD_PROXY}
  lxc config set core.proxy_https ${LXD_PROXY}
  lxc config set core.proxy_ignore_hosts image-server.local
fi

echo "(1) Create the Kubernetes Controller machines"
lxc launch ubuntu:${UBUNTU_VER} lxdk8s-m0 --profile lxdk8s
lxc launch ubuntu:${UBUNTU_VER} lxdk8s-m1 --profile lxdk8s
lxc launch ubuntu:${UBUNTU_VER} lxdk8s-m2 --profile lxdk8s

echo "(2) Create the Kubernetes Workers machines"
lxc launch ubuntu:${UBUNTU_VER} lxdk8s-w0 --profile lxdk8s
lxc launch ubuntu:${UBUNTU_VER} lxdk8s-w1 --profile lxdk8s
lxc launch ubuntu:${UBUNTU_VER} lxdk8s-w2 --profile lxdk8s

echo "(3) Create the Kubernetes Load Balancer"
lxc launch ubuntu:${UBUNTU_VER} lxdk8s-lb

echo "(-) Verify the LXDK8S machines"
sleep 15
lxc list -c ns4 | grep "lxdk8s-"
