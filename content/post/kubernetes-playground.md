---
title: "Kubernetes on (almost) bare metal"
description: "Deploying a Kubernetes master and booting the CoreOs worker from PXE"
date: "2016-08-19"
categories:
  - "ansible"
  - "kubernetes"
  - "coreos"
---

This is an older post that has been in the queue for several months. Kubernetes has released several new versions with new features in the meantime, so please keep this in mind when reading this post.

The post will give a rough overview of what Kubernetes is and take a direct dive into setting up a working Kubernetes cluster (don't worry I prepared a little something for you, it is barely more then typing `vagrant up` into a console) so lets start:

I have to admit, that the title of this post is a little bit misleading in that hindsight that we are not using actual bare metal, but Vagrant provisioned boxes, which in this case should be close enough. The general idea of this setup is an Ansible provisioned central host housing all services needed for seeding the Kubernetes cluster meaning providing boot over PXE for the cluster nodes as well as setup and configuration of the Kubernetes workers.

## What is Kubernetes? ##

But before we dive into the dark realms of a real Kubernetes cluster, lets have a short look what Kubernetes (which I will from here on just call K8S to give my fingers some rest) is and what we actually can use it for. 

K8S in one sentence is 

> "A system for managing containerized applications across a cluster of nodes." 

It automates all the operations you typically would need in a clustered environment such as deployment, scheduling and scaling across nodes. K8S orchestrates your containers (well not really containers but pods, but we get to that later) and lets you:

* automate the deployment and replication of your applications
* horizontal scale applications on the fly
* do rolling updates for new versions of your application
* provide resilience against container/node failures

Additionally it comes with tons of useful features that make the work with distributed applications in containers easier:

* distribution of secrets
* basic health checking
* naming and discovery services
* load balancing,
* monitoring/log access and ingestion,

As already mentioned K8S does not handle single containers, but groups of containers called pods. For example to run a blog you would group the webserver, a database and maybe a cache like Redis (if your blog is really popular) together in a pod. These pod provide a higher level of abstraction to work with and also enable resource sharing between the services needed to form an application.

## Architecture Overview ##

Sounds promising right? So lets start with the master host. As I already mentioned, the master host will also act as DCHP, TFTP, HTTP Proxy and web server to support the PXE boot process for the cluster nodes. For this purpose we resort to Ubuntu as our operating system of choice because it provides all needed packages out of the box. 

The actual cluster nodes are much simpler and do not need a fully flexed Linux distribution as they basically only need Docker to run the different components of a Kubernetes node. 

For this purpose we will use CoreOS as its designed is optimized for clustering and containerization. The OS layer is quite thin and leaves out nearly everything that is not needed for running the Docker containers. I doesn't even provide a package manager as it expects all applications running on it to be executed in a container which allows for isolation, portability and external management of these applications and therefore perfectly matches our requirements for the K8S cluster worker nodes.

In our setup we treat the cluster worker nodes as immutable and ephemeral. In fact the local disk is initialized on each boot and mounted under `/var/lib/docker` only to provide space for the Docker container images that are needed during the workers lifetime. The rest of the CoreOS installation runs from memory.
For the applications that need some kind of local storage we would need to attach networked storage which is out of scope for our current setup.

Provisioning of the K8S master host is implemented in Ansible. The K8S workers nodes boot their OS via [iPXE](http://ipxe.org/) from the master host and automatically register themselves in the K8S cluster. The necessary provisioning and configuration for the workers is done using CoreOSs integrated [CloudConfig](https://coreos.com/os/docs/latest/cloud-config.html) which allows us to declaratively customize the CoreOS configuration, specifically network configuration, user accounts, and most important systemd units. The configuration is generated on the fly on the master.

### DHCP/PXE/... ####

The master host is equipped with two network interfaces, the first one is the default natted Virtualbox interface providing access to the internet and the master host itself. The second interface (`enp0s8`) is used for a VirtualBox internal network called `kubernetes1`. All hosts that later are attached and spun up on this network will receive an ip address in the range `192.168.0.1` - `192.168.0.100` from the DHCP server (dnsmasq) and the instruction to [chainload the iPXE](http://ipxe.org/howto/chainloading) firmware (`undionly.kpxe`) from dnsmasqs provided tftp server. As soon as the iPXE firmware loads it again requests an ip address from the DHCP server which is instructed to tag all request coming from an iPXE firmware (`dhcp-userclass=set:ipxe,iPXE`) and points all tagges iPXE clients to the IPXE config script on the master host (`http://kubernetes.local/boot.ipxe`).
See `/etc/dnsmasq.conf` for more information about the DCHP and boot configuration for the K8S workers.

### flanneld ###

For our overlay network we choose [Flannel](https://github.com/coreos/flannel) from the ever growing [list](http://kubernetes.io/docs/admin/networking/) of networking solutions for K8S. Flannel provides us with a software defined network (SDN) that enables seamless communication between the containers on the different hosts. Userspace solutions like flannel may under circumstances introduce latency and throughput problems as and should be critically evaluated against layer 3 solutions like for example [Callico](https://www.projectcalico.org/) but is will definitely be enough for our test setup.
Like K8S itself Flannel stores its configuration in Etcd, so to configure Flannel we just have to point it to our Etcd endpoint (see the `flanneld` config file at `/run/flannel/options.env`) and then add the network configuration for Flannel to Etcd using an simple HTTP Post containing the configuration in JSON:

```
$ curl -X PUT -d "value={ "Network": "10.2.0.0/16 ", "Backend":{ "Type": "vxlan"} }" http://localhost:2379/v2/keys/coreos.com/network/config
```

### Docker network primer ####

Before we go into the details of the K8S setup we have to take a short detour into the depths of Docker networking to understand why we even have to take the burden of setting up a software defined network overlay.

Dockers native approach to networking is creating a virtual bridge called `docker0` on the docker host and then to allocate one of the well known private subnets defined in RFC1918 to it. Each docker container that is subsequently started on the host gets a virtual ethernet device that is attached to this bridge and appears as the usual `eth0` in the containers namespace with an ip address from the `docker0` interfaces address range. This means that docker containers can only communicate to containers attached to the same bridge and thus only to containers on the same physical host.
To provide inter-host communication for Docker containers, you have to create port mappings on the host machines ip address and proxy/forward them to other hosts containers. This leads to a lot of coordination issues and obviously does not scale well. Also you would need to tell each application running in the container a special port number for communication with other containers instead of just using the well known ports you would usually use.

To avoid all those problems K8S mandates a set of rules for the networking infrastructure used in a K8S cluster:

 * All containers can communicate with all other containers without NAT
 * All nodes can communicate with all containers (and vice-versa) without NAT
 * the ip address that a container sees itself as is the same address that others see it as

In order to comply with these rules we need some kind of overlay network as the docker native networking model violates every single of these rules. The reward for the extra work is the ability to move applications from VMs to containers easily as the Kubernetes networking is very similar to what you usually get in a VM based environment.
If your service ran in a VM with an ip address and was talking to other Vms with an ip address it can communicate the same way in Kubernetes with having to hassle with the port numbers like it would be necessary when using plain Docker.

K8S does not assign containers directly to hosts, but (as we already discussed) uses logical groups of containers called Pods, thus ip addresses are assigned on a per-pod-basis. This implies that all containers inside a pod have to coordinate their port usage (just as several processes inside a VM would have to do). 

## Master Server Components ##

The master server provides some extra services and serves as the management endpoint for administrators. In a high availability environment these services should of course be distributed across several nodes behind a load balancer to provide resilience against failures ([Building High-Availability Clusters](http://kubernetes.io/docs/admin/high-availability/)).

### Etcd ###

[Etcd](https://github.com/coreos/etcd) serves as central, distributed configuration store for the cluster and provides a simple HTTP/JSON API that can be used by all K8S components. In a real production environment this should not only be hosted on a separate machine as etcd may see a high load depending on the size of the cluster, but should also itself be clustered because it stores the current configuration and run state of the K8S cluster. For more information on how to make etcd high available see [Etcd clustering guide](https://github.com/coreos/etcd/blob/master/Documentation/op-guide/clustering.md).

### API Server ###

The API server is the central component that lets the users of the cluster work with Kubernetes units and services. It also ensures the the current cluster state and the etcd store are in sync and provides an API for the clusters state which all other components use to coordinate their work. The API itself implements a REST interface making it easy to integrate it into different tools and environments and is also used by the Kubernetes client `kubectl` itself.

### Controller Manager Server ###

The controller manager service is responsible for handling the replication processes inside the cluster. It watches etcd and reacts to changes like scaling and application up or down depending on the desired state that is requested for that application. It uses the API server to execute these actions.

### Scheduler Server ###

The scheduler actually assigns workloads to specific nodes in the cluster. It reads applications definitions, analyzes the current infrastructure and then chooses suitable nodes to deploy the applications. It is also responsible for keeping track of resource utilization on each node.

## Node Components ##

A node can be a virtual or physical machine running K8S services, where the pods can be deployed.

### Kubelet Service ###

The kubelet daemon reacts to changes in the master API server, starts/stops the containers accordingly and monitors their health.

### Proxy Service ###

In order to deal with individual host subnetting and to make services available to external parties, a proxy service is run on each worker. This process forwards requests to the correct containers, can do primitive load balancing, and is generally responsible for making sure the networking environment is predictable and accessible, but isolated.


## Lets start ##

Enough talking, lets gets our hands dirty. First of all we fire up Vagrant and provision out master host:

```
$ vagrant up
```

As already mentioned the `Kubelet Service` is responsible for the container management on the nodes. This is also true for the host and we will use a provided wrapper script to run the kublet service that then monitors a manifest directory for manifest files describing the containers to start (in our case the needed master host components like controller manager server or the scheduler). Note that the wrapper script does not use Docker for container management but [rkt](https://coreos.com/rkt/).
After the kubelet service is successfully started we can log in into our newly created master host and have a look at whats going on (note that even if the Vagrant provision run is done, the whole K8S provisioning is still running, downloading containers and so on, so give it some time to finish its job):

```
$ vagrant ssh

$ docker ps
CONTAINER ID        IMAGE                                      COMMAND                  CREATED             STATUS              PORTS               NAMES
ef08e267beb3        quay.io/coreos/hyperkube:v1.3.4_coreos.0   "/hyperkube proxy --m"   About an hour ago   Up About an hour                        k8s_kube-proxy.117367ac_kube-proxy-192.168.0.254_kube-system_e1499f12e9a7b2983219c9a4f8712840_9f650164
4010d92b8166        quay.io/coreos/hyperkube:v1.3.4_coreos.0   "/hyperkube controlle"   About an hour ago   Up About an hour                        k8s_kube-controller-manager.cad516ee_kube-controller-manager-192.168.0.254_kube-system_b69451f8a0a2cce0dd26360f14d811ce_4f4f053c
2b1db372b47a        quay.io/coreos/hyperkube:v1.3.4_coreos.0   "/hyperkube apiserver"   About an hour ago   Up About an hour                        k8s_kube-apiserver.94cd5172_kube-apiserver-192.168.0.254_kube-system_a0571e12e766483ef20b9c91535e34be_b11b6222
50b86e73c5fa        quay.io/coreos/hyperkube:v1.3.4_coreos.0   "/hyperkube scheduler"   About an hour ago   Up About an hour                        k8s_kube-scheduler.eb9498df_kube-scheduler-192.168.0.254_kube-system_dee9281643c2c606190685490a4c7de2_e3e2d841
6324f36ee00c        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 About an hour ago   Up About an hour                        k8s_POD.d8dbe16c_kube-proxy-192.168.0.254_kube-system_e1499f12e9a7b2983219c9a4f8712840_457c480d
cfbcad88fde3        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 About an hour ago   Up About an hour                        k8s_POD.d8dbe16c_kube-controller-manager-192.168.0.254_kube-system_b69451f8a0a2cce0dd26360f14d811ce_e166cec7
d1ab081da956        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 About an hour ago   Up About an hour                        k8s_POD.d8dbe16c_kube-apiserver-192.168.0.254_kube-system_a0571e12e766483ef20b9c91535e34be_16e69690
14a77810ff3b        gcr.io/google_containers/pause-amd64:3.0   "/pause"                 About an hour ago   Up About an hour                        k8s_POD.d8dbe16c_kube-scheduler-192.168.0.254_kube-system_dee9281643c2c606190685490a4c7de2_54870700

```

We can see that all previously described components for an K8S master host are up an running (for an explanation of these spurious "pause" container instances see this [Kubernetes 101 – Networking](http://www.dasblinkenlichten.com/kubernetes-101-networking/))

Everything seems to be fine, lets try to talk to our cluster:

```
$ kubectl cluster-info
Kubernetes master is running at https://192.168.0.254 

$ kubectl get nodes
NAME            LABELS                                                                                           STATUS                     AGE
192.168.0.254   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=192.168.0.254   Ready,SchedulingDisabled   1h
```

Cluster seems to be running with one node (our master) where the scheduling is disabled to prevent accidental deployments to the master host.

To do something useful we need at least one node doing the actual work. Lets take a look at the Virtualbox configuration of the second network adapter for the master host:

![Master Host Virtualbox Network Config](/img/posts/master_virtualbox_networkconfig.png)

Here we see the already mentioned internal network adapter attached to the virtual network **kubernetes1**. To create a new node for the cluster just create a new machine in Virtualbox and attach the network adapter to this network like shown below:

![Node Virtualbox Network Config](/img/posts/node_virtualbox_networkconfig.png)

Lets fire up the machine and wait some time until K8S initializes on the host. The machine will try to boot via network and retrieve the CoreOs image from our master host:

![Worker Node Booting](/img/posts/worker_node_booting.png)
![Worker Node Booted](/img/posts/worker_node_booted.png)


When the boot is finished and all K8S services are up, we see an additional node happily waiting to accept new pods on the master host:

```
$ kubectl get nodes
NAME            LABELS                                                                                           STATUS                     AGE
192.168.0.254   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=192.168.0.254   Ready,SchedulingDisabled   6m
localhost       beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=localhost       Ready                      1m
```


So we are ready to start and to deploy our first application. Let begin with the deployment of a simple nginx webserver just to see how this is done. Create a file containing the following manifest which defines a service exposing the default HTTP port 80 and an additional replication controller that is instructed to keep exactly one replica of the **nginx** image available. 


```
apiVersion: v1
kind: Service
metadata:
  name: nginx-example
  labels:
    app: nginx
spec:
  type: NodePort
  ports:
  - port: 80
    protocol: TCP
    name: http
  selector:
    app: nginx
---
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-example
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          timeoutSeconds: 1
```

Initiate the creation of the service and replication controller by:

```
$ kubectl create -f ./nginx-example.yaml
```

and again wait some time until the newly created pod changes its status to **Running** 

```
$ kubectl get pods
NAME                  READY     STATUS    RESTARTS   AGE
example-nginx-jymxw   1/1       Running   0          4m
```

the list of services now also show the service we defined earlier in the manifest:

```
$ kubectl get service
NAME           CLUSTER_IP   EXTERNAL_IP   PORT(S)   SELECTOR    AGE
nginx-example  10.3.0.228   nodes         80/TCP    app=nginx   4m
```

Next thing obviously would be to make this webserver externaly availble (meaning outside the cluster) but for the sake of simplicity we try to access the webserver directly on the node to see if it worked. So we have to obtain the information where and under which port the nginx pod is running:

```
$ kubectl get service nginxsvc -o json | grep nodePort
                "nodePort": 31587

$ kubectl get nodes -o json | grep address
                "address": "192.168.0.254"

```

Finally we can use curl to see the default nginx index site in all its glory:

```
$ curl http://192.168.0.254:31587
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
[...]
```

Congratulations you just deployed your first application (or service depending how you define it) to a K8S cluster. 

### Where to go from here ###

From the many things that were left out for the brevity of the post, one of the most important topics worth digging into is K8S labels concept which is essential to run a K8S cluster. Also an understanding of replication controllers and services (in terms of K8S services) would be essential before experimenting with more advanced deployments. 
