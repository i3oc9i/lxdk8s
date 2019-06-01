#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
echo ">>> Cleaning Up LXDK8S Deployment"
echo "(0) Remove lxdk8s.kubectl in ./bin"
rm -f ./bin/lxdk8s.kubectl

echo "(1) Remove all generated and downloaded files frome ./setup directory"
rm -rf ./setup/*.{yaml,cfg,conf,csr,pem,json,kubeconfig,service}
#rm -rf ./setup

echo "(2) Stop all the LXDK8S machines"
lxc stop lxdk8s-lb
lxc stop lxdk8s-m0 lxdk8s-m1 lxdk8s-m2
lxc stop lxdk8s-w0 lxdk8s-w1 lxdk8s-w2

echo "(3) Delete all the LXDK8S machines"
lxc delete lxdk8s-lb
lxc delete lxdk8s-m0 lxdk8s-m1 lxdk8s-m2
lxc delete lxdk8s-w0 lxdk8s-w1 lxdk8s-w2

echo "(4) Remove LXDK8S profile"
lxc profile delete lxdk8s

echo "(5) Verify LXC"
echo "--- LXD current machines..."
lxc list
echo "--- LXD cuurent profiles..."
lxc profile list
