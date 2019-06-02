#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.

echo ">>> Cleaning Up LXDK8S Deployment"
echo "(0) Remove lxdk8s.kubectl and lxdk8s.net in ./bin"
rm -f ./bin/lxdk8s.kubectl
rm -f ./bin/lxdk8s.net

echo "(1) Remove all generated and downloaded files frome ./setup directory"
rm -rf ./setup/*.{yaml,cfg,conf,csr,pem,json,kubeconfig,service}
#rm -rf ./setup

echo "(2) Stop all the LXDK8S machines"
lxc stop lxdk8s-lb 2> /dev/null
lxc stop lxdk8s-m0 lxdk8s-m1 lxdk8s-m2 2> /dev/null
lxc stop lxdk8s-w0 lxdk8s-w1 lxdk8s-w2 2> /dev/null

echo "(3) Delete all the LXDK8S machines"
lxc delete lxdk8s-lb 2> /dev/null
lxc delete lxdk8s-m0 lxdk8s-m1 lxdk8s-m2 2> /dev/null
lxc delete lxdk8s-w0 lxdk8s-w1 lxdk8s-w2 2> /dev/null

echo "(4) Remove LXDK8S profile and storage"
lxc profile delete lxdk8s 2> /dev/null
lxc storage delete lxdk8s-dir 2> /dev/null

echo "(5) Verify LXC"
echo "--- LXD current machines..."
lxc list
echo "--- LXD current profiles..."
lxc profile list
echo "--- LXD current storage..."
lxc storage list
