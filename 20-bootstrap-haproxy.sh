#!/bin/bash
# Copyright (c) 2019 Ivano Coltellacci. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.
set -eu

source ./config/lxdk8s.config

mkdir -p ./setup; cd ./setup

echo ">>> Bootstraping the LXDK8S Load Balancer"
echo "(0) Update OS and install the haproxy of lxdk8s-lb"
if [ ${APT_PROXY} != "noproxy" ] ; then
cat > ubuntu-apt-proxy.conf <<EOF
Acquire::http::Proxy  "${APT_PROXY}";
Acquire::https::Proxy "${APT_PROXY}";
EOF

lxc file push ubuntu-apt-proxy.conf lxdk8s-lb/etc/apt/apt.conf.d/proxy.conf
fi

lxc exec lxdk8s-lb -- apt update
lxc exec lxdk8s-lb -- apt -y upgrade
lxc exec lxdk8s-lb -- apt -y install haproxy
lxc exec lxdk8s-lb -- apt -y autoremove

echo "(1) Configure the haproxy of lxdk8s-lb"
cat > lxdk8s-lb.cfg <<EOF
global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# Default ciphers to use on SSL-enabled listening sockets.
	ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS
	ssl-default-bind-options no-sslv3

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

frontend lxdk8s
    bind ${LXDK8S_PUBLIC_ADDR}:6443
    mode tcp
    default_backend lxdk8s

backend lxdk8s
    balance roundrobin
    mode tcp
    option tcplog
    option tcp-check
    server lxdk8s-m0 ${M0_IP}:6443 check
    server lxdk8s-m1 ${M1_IP}:6443 check
    server lxdk8s-m2 ${M2_IP}:6443 check

listen stats 
    bind  ${LXDK8S_PUBLIC_ADDR}:1936
    stats enable
    stats uri /
EOF

lxc file push lxdk8s-lb.cfg lxdk8s-lb/etc/haproxy/haproxy.cfg

echo "(2) Restart the haproxy service of lxdk8s-lb"
lxc exec lxdk8s-lb -- systemctl restart haproxy

echo "(-) Verify the haproxy service of lxdk8s-lb"
lxc exec lxdk8s-lb -- netstat -nltp | grep haproxy
