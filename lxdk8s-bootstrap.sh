#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

./00-bootstrap-lxd.sh
./01-get-client-tools.sh
./10-gen-certs.sh
./11-gen-configs.sh
./12-gen-encryption.sh
./20-bootstrap-haproxy.sh
./30-bootstrap-etcd.sh
./31-bootstrap-control-plane.sh
./32-setup-rbac-kubelet.sh
./40-bootstrap-workers.sh
./50-create-network-routes.sh

