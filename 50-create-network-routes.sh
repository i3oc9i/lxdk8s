#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

cat > lxdk8s.net <<EOF
#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.

ip route add ${POD_CIDR_NET["lxdk8s-w0"]} via ${W0_IP} 
ip route add ${POD_CIDR_NET["lxdk8s-w1"]} via ${W1_IP} 
ip route add ${POD_CIDR_NET["lxdk8s-w2"]} via ${W2_IP} 
EOF

chmod +x ./lxdk8s.net
cp ./lxdk8s.net ../bin/lxdk8s.net

