#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

echo ">>> Generating the Kubernetes config files for the deployment"
echo "(0) Generate the kubelet Kubernetes configuration File"
for instance in lxdk8s-w0 lxdk8s-w1 lxdk8s-w2; do
  ./kubectl config set-cluster lxdk8s \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${LXDK8S_PUBLIC_ADDR}:6443 \
    --kubeconfig=${instance}.kubeconfig

  ./kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  ./kubectl config set-context default \
    --cluster=lxdk8s \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  ./kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

echo "(1) Generate the kube-proxy Kubernetes configuration file"
./kubectl config set-cluster lxdk8s \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${LXDK8S_PUBLIC_ADDR}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

./kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

./kubectl config set-context default \
  --cluster=lxdk8s \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

./kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

echo "(2) Generate the kube-controller-manager Kubernetes configuration file"
./kubectl config set-cluster lxdk8s \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

./kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

./kubectl config set-context default \
  --cluster=lxdk8s \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

./kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

echo "(3) Generate the kube-scheduler Kubernetes configuration file"
./kubectl config set-cluster lxdk8s \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

./kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.pem \
  --client-key=kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

./kubectl config set-context default \
  --cluster=lxdk8s \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

./kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

echo "(4) Generate the admin Kubernetes configuration file for cluster"
./kubectl config set-cluster lxdk8s \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

./kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

./kubectl config set-context default \
  --cluster=lxdk8s \
  --user=admin \
  --kubeconfig=admin.kubeconfig

./kubectl config use-context default --kubeconfig=admin.kubeconfig

echo "(5) Generate the admin Kubernetes configuration file for local machine"
./kubectl config set-cluster lxdk8s \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${LXDK8S_PUBLIC_ADDR}:6443 \
  --kubeconfig=lxdk8s.kubeconfig

./kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=lxdk8s.kubeconfig

./kubectl config set-context default \
  --cluster=lxdk8s \
  --user=admin \
  --kubeconfig=lxdk8s.kubeconfig

./kubectl config use-context default --kubeconfig=lxdk8s.kubeconfig
