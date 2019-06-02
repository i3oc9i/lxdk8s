#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

[ "$(basename ${PWD})" = "addon" ] && cd ..
source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

echo ">>> Deploy the CoreDNS addon version ${COREDNS_VER}"
cat ../addon/yaml/coredns-${COREDNS_VER}.yaml | lxc exec lxdk8s-m0 -- kubectl --kubeconfig admin.kubeconfig apply -f -

echo "(-) CoreDNS-Test"
echo "--- At each watch screen wait for the Pod state RUNNING before to continue."
read -n 1 -p "--- press ENTER to star th test ..."
watch lxc exec lxdk8s-m0 -- kubectl --kubeconfig admin.kubeconfig get pods -l k8s-app=kube-dns -n kube-system

lxc exec lxdk8s-m0 -- kubectl --kubeconfig admin.kubeconfig run coredns-test --image busybox --command -- sleep 3600
watch lxc exec lxdk8s-m0 -- kubectl --kubeconfig admin.kubeconfig get pods -l run=coredns-test

POD_NAME=$(lxc exec lxdk8s-m0 -- kubectl --kubeconfig admin.kubeconfig get pods -l run=coredns-test -o jsonpath="{.items[0].metadata.name}")
lxc exec lxdk8s-m0 -- kubectl --kubeconfig admin.kubeconfig exec -ti ${POD_NAME} -- nslookup kubernetes || true
lxc exec lxdk8s-m0 -- kubectl --kubeconfig admin.kubeconfig delete deployment coredns-test
