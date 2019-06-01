#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

echo ">>> Generating the certificates for the deployment"
echo "(0) Generate the Certificate Authority certificate"
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

./cfssl gencert -initca ca-csr.json | ./cfssljson -bare ca

echo "(1) Generate the Admin Client certificate"
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:masters",
      "OU": "lxdk8s",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | ./cfssljson -bare admin

echo "(2) Generate the Kubelet Client certificates"
for instance in lxdk8s-w0 lxdk8s-w1 lxdk8s-w2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:nodes",
      "OU": "lxdk8s",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

EXTERNAL_IP=$(lxc info ${instance} | grep eth0 | head -1 | awk '{print $3}')

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | ./cfssljson -bare ${instance}
done

echo "(3) Generate the Controller Manager Client certificate"
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:kube-controller-manager",
      "OU": "lxdk8s",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | ./cfssljson -bare kube-controller-manager

echo "(4) Generate the Kube Proxy Client certificate"
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:node-proxier",
      "OU": "lxdk8s",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | ./cfssljson -bare kube-proxy

echo "(5) Generate the Scheduler Client certificate"
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:kube-scheduler",
      "OU": "lxdk8s",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | ./cfssljson -bare kube-scheduler

echo "(6) Generate the Kubernetes API Server certificate"
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "Kubernetes",
      "OU": "lxdk8s",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${M0_IP},${M1_IP},${M2_IP},${LXDK8S_PUBLIC_ADDR},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | ./cfssljson -bare kubernetes

echo "(7) Generate the Service Account key pair"
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "Kubernetes",
      "OU": "lxdk8s",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | ./cfssljson -bare service-account
