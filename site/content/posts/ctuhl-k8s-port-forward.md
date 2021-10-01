---
title: "Kubernetes port forward"
date: 2021-09-291T20:00:00+01:00
draft: false
---

Occasionally when developing and deploying services to Kubernetes you may encounter a situation where you need to access an API that your service relies on from your local machine. Depending on your network setup or internal company policies you may realize: "S**t, that API is only accessible from within the Kubernetes cluster". 

![situation](/img/k8s-port-forward-0.png)

This post shows how to deal with such a situation using a Kubernetes port forward and a special Docker container.  

<!--more-->

Kubernetes already contains a mechanism for [port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/), that lets us forward a port on our local machine to the port of a running service inside Kubernetes. So assuming we are running some service in Kubernetes that depends on an external API.

![Simple Port Forward](/img/k8s-port-forward-1.png)

By running:

{{< highlight bash "" >}}
kubectl port-forward some-service 8080
{{< / highlight >}}

We can point a local port to that deployed service, and subsequently are able to reach this service via localhost:

{{< highlight bash "" >}}
curl http://localhost:8080
[...]
{{< / highlight >}}

This first step brings us from our local machine into the Kubernetes cluster. For the next step to get us from a running container to the external service, we are going to use socat. [Socat](https://linux.die.net/man/1/socat) does something similar to `kubectl port-forward`, it can forward a local TCP port to any host and port it can reach.


For example running:

{{< highlight bash "" >}}
socat TCP4-LISTEN:8080 TCP4:httpbin.org:80
{{< / highlight >}}

will forward the local port 8080 to `httpbin.org:80` which then afterwards can be reached via:

{{< highlight bash "" >}}
curl http://localhost:8080/get
{{< / highlight >}}

![socat](/img/k8s-port-forward-2.png)

So if we run combine these two components and run `socat` as a service inside Kubernetes we can reach this external service that would normally only be reachable from Kubernetes.

Luckily with [marcnuri/port-forward](https://hub.docker.com/r/marcnuri/port-forward) there already exists a pre-packed docker image, containing socat, where the configuration of the port forward can be controlled by environment variables. 


Running

{{< highlight bash "" >}}
kubectl run --env REMOTE_HOST=httpbin.org --env REMOTE_PORT=80 --env LOCAL_PORT=8080 --port 8080 --image marcnuri/port-forward my-pretty-port-forwarder
{{< / highlight >}}

deploy this service listening on 8080 and forwarding all traffic that arrives at 8080 to httpbin.org port 80. If we combine this with a Kubernetes port forward:

{{< highlight bash "" >}}
kubectl port-forward my-pretty-port-forwarder 8080
{{< / highlight >}}

we then are able to reach this service routed through kubernetes with

{{< highlight bash "" >}}
curl http://localhost:8080/get
{{< / highlight >}}

![all together](/img/k8s-port-forward-3.png)


Doing this manually is fine for a single port forward, but you may run into trouble managing multiple forwards, because you need to start the service, then start the forward and finally, very important clean up again to not let any port forwarders dangling around.  Also with multiple port you may get local port clashes. 

I wrote a small wrapper in bash that:

 * automatically detects a local available tcp port
 * starts a `socat` service forwarding to a specific host and port combination
 * automatically chooses an appropriate pod name to avoid name clashed
 * starts a local port forward routing all request via the socat service to this host and port
 * cleans up the pod if the command exits or is aborted

{{< highlight bash "" >}}
./k8s-port-forward -h httpbin.org -p 80
================================================================================
forwarding tcp://localhost:35446 to tcp://httpbin.org:80
================================================================================

================================================================================
starting port forwarding pod 'port-forward-pelle-httpbinorg-80'
pod/port-forward-pelle-httpbinorg-80 created
================================================================================

================================================================================
waiting for port forwarding pod 'port-forward-pelle-httpbinorg-80' to be ready
pod/port-forward-pelle-httpbinorg-80 condition met
================================================================================

================================================================================
starting local port forward on port localhost:35446 to pod 'port-forward-pelle-httpbinorg-80:80'
Forwarding from 127.0.0.1:35446 -> 80
Forwarding from [::1]:35446 -> 80
^C

================================================================================
deleting port forwarding pod 'port-forward-pelle-httpbinorg-80
pod "port-forward-pelle-httpbinorg-80" deleted
================================================================================
{{< / highlight >}}

The command is available via my [CTHUL](https://github.com/pellepelster/ctuhl) project [here](https://github.com/pellepelster/ctuhl/blob/master/bin/k8s-port-forward) (Commons Tools Utilities Helper and Libraries )