# LXDK8S - Kubernetes on LXD 
LXDK8S is a work inspired and adapted after the labs `Kubernetes The Hard Way` of [Kelsey Hightower](https://github.com/kelseyhightower/kubernetes-the-hard-way) .

As the the original labs, the purpose of this work is to provide a playground to learn Kubernetes. Instead to use the Google Cloud Platform, LXDK8S runs on top of the UBUNTU/LXD infrastucture of your local machine.

All the orginal **Kubernetes The Hard Way** labs have been adapted to fit with the LXC commands and the limitations of a local machine. For speed up the installation process, the labs have been fully automatized using BASH scripts. Indeed, the organization of these scripts follows the sequence of the orginal labs of **Kelsey Hightower**, so please refer to his [documenation](https://github.com/kelseyhightower/kubernetes-the-hard-way/tree/master/docs) for understanding.

LXDK8S is updated to deliver a Kubernetes v1.14.2 playground.

## Cluster Details
```
                                 lxdk8s-lb
                           +------------------+
                           |  Load Balancer   | (HAProxy)
                           +------------------+

      lxdk8s-m0                  lxdk8s-m1                  lxdk8s-m2
+------------------+       +------------------+       +------------------+
|     Master-0     |       |     Master-1     |       |     Master-2     | (API-Server)
+------------------+       +------------------+       +------------------+ (Control-Manager)
|       Etcd       |       |       Etcd       |       |       Etcd       | (Scheduler)
+------------------+       +------------------+       +------------------+


      lxdk8s-w0                  lxdk8s-w1                  lxdk8s-w2
+------------------+       +------------------+       +------------------+
|     Worker-0     |       |     Worker-1     |       |     Worker-2     | (Kube-Proxy)
+------------------+       +------------------+       +------------------+ (KubeLet)
|  10.200.0.0/24   |       |  10.200.1.0/24   |       |  10.200.2.0/24   | (CNI) (CRI)
+------------------+       +------------------+       +------------------+ (Containerd)
|       Pods       |       |       Pods       |       |       Pods       | (RunC) (gVisor)
+------------------+       +------------------+       +------------------+ 
```
## Prerequisites
LXDK8S has been successfully installed on a local machine running UBUNTU 18.04 and LXD 3.13

You need a machine with at least 16 GB of RAM, and 8 CPUs.

Other combination of LINUX distributions and of LXD versions can probably work but it is not garantited

> Note: The LXD images used for the machines of the LXDK8S cluster are based on the UBUNTU 18.04 image.

#### 1. Install LXD 
On UBUNTU 18.04 machine installs LXD using the APT method
```
$ sudo apt update && apt upgrade
$ sudo apt install lxd
```

or, using the SNAP method.
```
$ sudo snap install lxd
```

Verify the LXD version is 3.13 or higher.
```
$ lxc version
```

#### 2. Init LXD
Before to start, you have to initialize the LXD infrastucture. 

To complete the LXD initialisation, the following command requires to set several parameters.
You can safely accept the default values.
```
$ sudo lxd init
```

## Installation
#### 1. Clone the repositorty
```
$ git clone https://github.com/i3oc9i/lxdk8s.git ~/lxdk8s

$ cd ~/lxdk8s
```

#### 2. Bootstrap the cluster
To create the LXDK8S cluster you can execute each task separately, or  
```
$ ./00-bootstrap-lxd.sh
$ ./01-get-client-tools.sh
$ ./10-generate-certs.sh
$ ./11-generate-kubeconfigs.sh
$ ./12-generate-encryption-keys.sh
$ ./20-bootstrap-haproxy.sh
$ ./30-bootstrap-etcd.sh
$ ./31-bootstrap-control-plane.sh
$ ./32-configure-rbac-kubelet-authorization.sh
$ ./40-bootstrap-workers.sh
$ ./50-create-network-routes.sh
```
use the `lxdk8s.bootstrap.sh` command. 
```
$ ./lxdk8s.bootstrap.sh
```
#### 3. Create the network routes
Use the `lxdk8s.net` command to create the network routes to let the pods to comunicate across the workers.
```
$ sudo ./bin/lxdk8s.net
```

#### 4. Save the lxdk8s.kubeconfig
During the bootstrap process the `lxdk8s.kubeconfig` configuration file is generated in the `./setup` directory. 

You can copy it in your `.kube` directory, or
```
$ mkdir -p ~/.kube
$ cp ./setup/lxdk8s.kubeconfig ~/.kube/config
```
set the `KUBECONFIG` environment variable into your `~/.bashrc` file.
```
export KUBECONFIG="~/lxdk8s/setup/lxdk8s.kubeconfig"
```

#### 5. Verify the cluster
Verify the components of the cluster.
```
$ ./bin/lxdk8s.kubectl --kubeconfig ./setup/lxdk8s.kubeconfig  get componentstatuses

NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-2               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}   
etcd-1               Healthy   {"health":"true"}
```

Verify the status of the nodes.
```
$ ./bin/lxdk8s.kubectl --kubeconfig ./setup/lxdk8s.kubeconfig  get node -o wide

NAME        STATUS   ROLES    AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
lxdk8s-w0   Ready    <none>   77m   v1.14.2   10.234.143.181   <none>        Ubuntu 18.04.2 LTS   4.15.0-50-generic   containerd://1.2.6
lxdk8s-w1   Ready    <none>   76m   v1.14.2   10.234.143.26    <none>        Ubuntu 18.04.2 LTS   4.15.0-50-generic   containerd://1.2.6
lxdk8s-w2   Ready    <none>   75m   v1.14.2   10.234.143.86    <none>        Ubuntu 18.04.2 LTS   4.15.0-50-generic   containerd://1.2.6
```

Retrive the API URL address of the cluster
```
$ ./bin/lxdk8s.kubectl --kubeconfig ./setup/lxdk8s.kubeconfig  cluster-info  

Kubernetes master is running at https://10.234.143.198:6443

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## Install Addons

#### CoreDNS
Use the following command to deploy CoreDNS.
```
$ ./addon/deploy-coredns.sh
```

## Using LXDK8S
After the bootstrap process is terminated the `./bin` directory will contains the follwing commands to control the cluster.  

```
lxdk8s.start
lxdk8s.status
lxdk8s.stop
lxdk8s.net
lxdk8s.kubectl
```
Add this directory at your `PATH`, or copy its content into the `/usr/local/bin`, or `~/.local/bin` directory.

#### 1. lxdk8s.start
To start the LXDK8S cluster.
```
$ ./bin/lxdk8s.start
```
#### 2. lxdk8s.stop
To stop the LXDK8S cluster.
```
$ ./bin/lxdk8s.stop
```
#### 3. lxdk8s.status
To retrive the status of the LXDK8S cluster.
```
$ ./bin/lxdk8s.status
>>> LXDK8S machines
| lxdk8s-lb | RUNNING | 10.234.143.198 (eth0) |
| lxdk8s-m0 | RUNNING | 10.234.143.49 (eth0)  |
| lxdk8s-m1 | RUNNING | 10.234.143.190 (eth0) |
| lxdk8s-m2 | RUNNING | 10.234.143.135 (eth0) |
| lxdk8s-w0 | RUNNING | 10.234.143.181 (eth0) |
| lxdk8s-w1 | RUNNING | 10.234.143.26 (eth0)  |
| lxdk8s-w2 | RUNNING | 10.234.143.86 (eth0)  |

>>> Load balancer status
tcp        0      0 10.234.143.198:6443     0.0.0.0:*               LISTEN      263/haproxy         
tcp        0      0 10.234.143.198:1936     0.0.0.0:*               LISTEN      263/haproxy         
>>> Kubernetes Control Plane status
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-2               Healthy   {"health":"true"}   
etcd-1               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}   
>>> Kubernetes Nodes status
NAME        STATUS   ROLES    AGE   VERSION
lxdk8s-w0   Ready    <none>   88m   v1.14.2
lxdk8s-w1   Ready    <none>   87m   v1.14.2
lxdk8s-w2   Ready    <none>   86m   v1.14.2
```

#### 4. lxdk8s.net
To creates the network routes to let the pod to comunicate across the workers.
```
$ sudo ./bin/lxdk8s.net
$ ip route

default via 192.168.1.1 dev enp0s31f6 proto dhcp metric 100 
10.200.0.0/24 via 10.234.143.181 dev lxdbr0 
10.200.1.0/24 via 10.234.143.26 dev lxdbr0 
10.200.2.0/24 via 10.234.143.86 dev lxdbr0 
10.234.143.0/24 dev lxdbr0 proto kernel scope link src 10.234.143.1
... 
```

#### 6. lxdk8s.kubectl
To control the cluster.
```
$ ./bin/lxdk8s.kubectl --kubeconfig ./setup/lxdk8s.kubeconfig get all --all-namespaces

NAMESPACE   NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
default     service/kubernetes   ClusterIP   10.32.0.1    <none>        443/TCP   116m
```

## Clean UP
To delete all the LXDK8S machines and remove all file generated in the `./setup` directory.
```
$ ./99-cleanup.sh
```
