#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

echo ">>> Installing Cloudflare PKI and Kubernetes client tools"
echo "(0) Download cfssl cfssljson"
wget -q --show-progress --https-only --continue \
  https://pkg.cfssl.org/${CFSSL_VER}/cfssl_linux-amd64 \
  https://pkg.cfssl.org/${CFSSL_VER}/cfssljson_linux-amd64

chmod +x cfssl_linux-amd64 cfssljson_linux-amd64

rm -f cfssl; ln -s cfssl_linux-amd64 cfssl
rm -f cfssljson; ln -s cfssljson_linux-amd64 cfssljson

echo "(1) Download kubectl"
wget -q --show-progress --https-only --continue \
  https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kubectl

chmod +x kubectl
cp ./kubectl ../bin/lxdk8s.kubectl

echo "(-) Verify version of client tools"
./cfssl version
./kubectl version --short --client

