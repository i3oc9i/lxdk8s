#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

echo "(-) Download the Kubernetes Control Plane binaries"
wget -q --show-progress --https-only --continue \
  "https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kubectl"

chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl

for instance in lxdk8s-m0 lxdk8s-m1 lxdk8s-m2; do

echo ">>> Bootstraping the Kubernetes Control Plane of ${instance}"
echo "(0) Install the Kubernetes Control Plane Binaries of ${instance}"
lxc file push kube-apiserver kube-controller-manager kube-scheduler kubectl ${instance}/usr/local/bin/

echo "(1) Install the Kubernetes Control Plane Secrets of ${instance}"
lxc exec ${instance} -- mkdir -p /var/lib/kubernetes/
lxc file push ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml ${instance}/var/lib/kubernetes/

INTERNAL_IP=$(lxc info ${instance} | grep eth0 | head -1 | awk '{print $3}')

echo "(2) Configure the Kubernetes API Server of ${instance}"
cat > ${instance}-kube-apiserver.service <<EOF 
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota,PersistentVolumeLabel \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://${M0_IP}:2379,https://${M1_IP}:2379,https://${M2_IP}:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

lxc file push ${instance}-kube-apiserver.service ${instance}/etc/systemd/system/kube-apiserver.service

echo "(3) Configure the Kubernetes Controller Manager of ${instance}"
lxc file push kube-controller-manager.kubeconfig ${instance}/var/lib/kubernetes/

cat > ${instance}-kube-controller-manager.service <<EOF 
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

lxc file push ${instance}-kube-controller-manager.service ${instance}/etc/systemd/system/kube-controller-manager.service

echo "(4) Configure the Kubernetes Scheduler of ${instance}"
lxc file push kube-scheduler.kubeconfig ${instance}/var/lib/kubernetes/

cat > ${instance}-kube-scheduler.yaml <<EOF 
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

lxc exec ${instance} -- mkdir -p /etc/kubernetes/config/
lxc file push ${instance}-kube-scheduler.yaml ${instance}/etc/kubernetes/config/kube-scheduler.yaml

cat > ${instance}-kube-scheduler.service <<EOF 
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

lxc file push ${instance}-kube-scheduler.service ${instance}/etc/systemd/system/kube-scheduler.service

echo "(5) Starting the Kubernetes Control Plane services  of ${instance}"
lxc exec ${instance} -- systemctl daemon-reload
lxc exec ${instance} -- systemctl enable kube-apiserver kube-controller-manager kube-scheduler
lxc exec ${instance} -- systemctl start kube-apiserver kube-controller-manager kube-scheduler

echo "(6) Install the admin.kubeconfig of ${instance}"
lxc file push admin.kubeconfig ${instance}/root/

done

echo "(-) Verify the Kubernetes Version"
sleep 15
curl --cacert ca.pem --noproxy ${LXDK8S_PUBLIC_ADDR} https://${LXDK8S_PUBLIC_ADDR}:6443/version

echo "(-) Verify the Kubernetes Control Plane deployment"
lxc exec lxdk8s-m0 -- kubectl get componentstatuses --kubeconfig admin.kubeconfig

