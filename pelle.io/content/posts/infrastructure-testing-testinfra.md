---
title: "Infrastructure Testing with Testinfra"
date: 2024-03-25T19:00:00
draft: true
---

An often overlooked and admittedly cumbersome topic when developing infrastructure as code (IaC) is the testing of the resources that were created from said infrastructure code. 

Even a simple setup like a VM that is spun up in some cloud to serve HTTP requests, already confronts us with some hurdles to solve.
A pragmatic approach for testing such a setup could be to ensure, that after the deployment of the VM the HTTP port answers with a success HTTP code (2xx).

Although this would prove that the deployment was successful, there could be a misconfiguration that does not cause an error which is observable from the outside, but could still put out deployment at risk.
This could for example be a set of wrong permissions for a folder introducing a security risk, or a configuration value for the service that could cause harm in some special cases like for example some debug setting that is only meant for local debugging. 

With the inherent complexity of more advanced stacks like Kubernetes, the problem only gets harder because the single component that we might want to test could be even harder to reach than the content of a simple VM.

A library that can help us with that is [testinfra](https://testinfra.readthedocs.io/en/latest/) which is a plugin for the Python testing framework [pytest](https://pytest.org/) and enables us to run Python tests in and on infrastructure components.

This post will show you how to use [testinfra](https://testinfra.readthedocs.io/en/latest/) to make your infrastructure deployments more predictable and shorten the feedback cycle for infrastructure code, and cover three common test scenarios (Docker images, Kubernetes Helm Deployments, Cloud VMs) and its pitfalls. 

> As always the full code is available online here [github.com/pellepelster/kitchen-sink/infrastructure-testing-testinfra](https://github.com/pellepelster/kitchen-sink/tree/master/infrastructure-testing-testinfra). The folder contains a `do` file to start all tasks needed to follow the example in this post.

# Bootstrapping

As usual when working with Python code the first step is to bootstrap a Python environment dedicated to our project,
first create the file **requirements.txt**

<!-- insertFile[requirements.txt] -->
```Bash
pytest-testinfra==10.1.0
requests==2.31.0
kubernetes==29.0.0
```
<!-- /insertFile -->

containing all needed Python dependencies, and then init the [Python venv](https://docs.python.org/3/library/venv.html) with 

<!-- insertSnippet[bootstrap-venv] -->
```Bash
python3 -m venv "${DIR}/venv/"
"${DIR}/venv/bin/pip" install -r "${DIR}/requirements.txt"
```
<!-- /insertSnippet -->

For the example project you can bootstrap everything with

```Bash
cd infrastructure-testing-testinfra
./do bootstrap
```

That's it, we now have a Python environment with testinfra in it, and are ready to write our first test. 

# Docker

As a first step to learn how testinfra is supposed to work, we will use a Docker image as our test target. In a real-world scenario this could be used to ensure that certain tools are installed in a docker image, or that permissions are correctly set.

We will use the following `Dockerfile` as our test target

<!-- insertFile[Dockerfile] -->
```Bash
FROM alpine:3.19.1

RUN apk --no-cache add caddy

RUN addgroup \
    --gid "10000" \
    "www" \
&&  adduser \
    --disabled-password \
    --gecos "" \
    --home "/www/public_html" \
    --ingroup www \
    --uid 10000 \
    "www"

RUN mkdir -p /www/public_html
ADD index.html /www/public_html/
RUN chown www:www /www/public_html
ADD Caddyfile /www/Caddyfile
USER www
CMD ["caddy", "run", "--config", "/www/Caddyfile"]

```
<!-- /insertFile -->

To test the image we need to build it first, so run

```Bash
./do docker-build
```

We can see the author of this `Dockerfile` spent some effort in getting the permissions for the HTTP server right, and also went the extra mile to make sure the `www` user in the container does not clash with any user ids on the host system, lets make sure it stays this way by adding a test for it.

Since testinfra is a pytest plugin everything is executed in the scope of pytest. The special feature of testinfra is, that it passes a `host` object into the test methods that can be used to make assertions on the target, in our case the Docker image

<!-- insertSnippet[test_caddy_runs_as_non_root_user] -->
```Bash
def test_caddy_runs_as_non_root_user(host):
    caddy = host.process.get(comm="caddy")
    assert caddy.user == 'www'
```
<!-- /insertSnippet -->

The example above tries to the get the process with the name `caddy` and asserts it is running with the correct user id (`wwww`). For more available modules on the host object see the [modules](https://testinfra.readthedocs.io/en/latest/modules.html) part of the documentation. 

Testinfra comes with a wide range of [connection backends](https://testinfra.readthedocs.io/en/latest/backends.html), that can be used to talk to different infrastructure types. In our case we want to test a locally running Docker container, using the [docker connection](https://testinfra.readthedocs.io/en/latest/backends.html#docker) backend.

Common to all backends is, that we have to provide a connection string, telling testinfra how to connect to the backend, in the Docker case this looks like this

````Bash
py.test --hosts='docker://[user@]container_id_or_name'
````

So, now all that's left to run the test, is to start the docker container, and provide the name of the started container to testinfra, so it can connect to the container and run the assertions.

<!-- insertSnippet[task_docker_test] -->
```Bash
docker run --detach --name "${DOCKER_IMAGE_NAME}" "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
"${DIR}/venv/bin/py.test" --verbose --capture=tee-sys --hosts="docker://${DOCKER_IMAGE_NAME}" "${DIR}/test/test_docker.py"
```
<!-- /insertSnippet -->

Note that because testinfra is a pytest plugin it can directly be started via the `py.test` binary from our previously created Python environment. You can run

```Bash
./do docker-test
```

to start the tests on your local machine.

```Bash
============================================================================= test session starts =============================================================================
platform linux -- Python 3.10.12, pytest-8.1.1, pluggy-1.4.0 -- /home/pelle/git/kitchen-sink/infrastructure-testing-testinfra/venv/bin/python3
cachedir: .pytest_cache
rootdir: /home/pelle/git/kitchen-sink/infrastructure-testing-testinfra
plugins: testinfra-10.1.0
collected 4 items                                                                                                                                                             

test/test_docker.py::test_caddy_runs_as_non_root_user[docker://testinfra] PASSED                                                                                        [ 25%]
test/test_docker.py::test_caddy_listening_on_8080[docker://testinfra] PASSED                                                                                            [ 50%]
test/test_docker.py::test_www_user[docker://testinfra] PASSED                                                                                                           [ 75%]
test/test_docker.py::test_www_public_html[docker://testinfra] PASSED                                                                                                    [100%]

============================================================================== 4 passed in 1.42s ==============================================================================
```

As we can see all tests from [test_docker.py](https://github.com/pellepelster/kitchen-sink/blob/master/infrastructure-testing-testinfra/test/test_docker.py) were successfully executed, and we can now be sure that our docker container is fit for deployment in the next step.

# Kubernetes

## Prerequisites

For the next step we want to deploy the docker image to a Kubernetes cluster using a self written Helm chart that lives in [k8s/testinfra](https://github.com/pellepelster/kitchen-sink/tree/master/infrastructure-testing-testinfra/k8s/testinfra).
We will be using [minikube](https://minikube.sigs.k8s.io) to spin up a local Kubernetes cluster for testing, please refer to [this guide](https://minikube.sigs.k8s.io/docs/start/) for information on how to install minikube.

Once installed you can run

```Bash
./do k8s-start
```

To start the minikube cluster and import the already built docker image.

## Testing

Like in the previous docker example, we need to provide a connection string to pytest to specify how to connect to Kubernetes and which pod to test. The systax to do so looks like this

```Bash
py.test --hosts="kubectl://${POD}?namespace=${NAMESPACE}"
```

for more details on the connection string and its options see the [kubectl backend](https://testinfra.readthedocs.io/en/latest/backends.html#kubectl) documentation.

Once the helm chart is deployed via

<!-- insertSnippet[task_k8s_deploy] -->
```Bash
helm upgrade --install --namespace ${TEST_NAMESPACE} --create-namespace testinfra ${DIR}/k8s/testinfra
```
<!-- /insertSnippet -->

or using the task

```Bash
./do k8s-deploy
```

we can use `kubectl` to retrieve the information needed for the connection string

<!-- insertSnippet[task_k8s_test] -->
```Bash
export TEST_POD="$(kubectl get pods --namespace ${TEST_NAMESPACE} --output jsonpath="{.items[0].metadata.name}")"
echo "selected pod '${TEST_POD}' for test execution"
"${DIR}/venv/bin/py.test" --verbose --capture=tee-sys --hosts="kubectl://${TEST_POD}?namespace=${TEST_NAMESPACE}" "${DIR}/test/test_k8s.py"
```
<!-- /insertSnippet -->

Once the test is started with the correct kubectl connection string, everything feels and behaves like in the docker example, and we can use all testinfra modules to make assertions on the pods. In our arbitrary example we assert that the helm chart does set the `DEBUG` flag to `false`

<!-- insertSnippet[test_k8s_environment_variables] -->
```Bash
def test_k8s_environment_variables(host):
    environment = host.environment()
    assert environment['DEBUG'] == "false"
```
<!-- /insertSnippet -->


You can run all tests as usual using a `do` task

```Bash
./do k8s-test
```

## Kubernetes Resources

Unfortunately testinfra lacks a module to assert Kubernetes resources like pod metadata. Lets for example assume we want to assert that the pod has the label `log-service-name` set which might be used by some logging system that ingests data from Kubernetes.

Although Python has a [Kubernetes API](https://github.com/kubernetes-client/python) like when using `kubectl` to get pod information we need a pod name and namespace. To avoid funneling this into the tests from the `do` file we can use a little trick to determine this information from within the pod. 

<!-- insertSnippet[test_k8s_environment_variables_hostname_namespace] -->
```Bash
hostname = host.environment()['HOSTNAME']
namespace = host.run('cat /run/secrets/kubernetes.io/serviceaccount/namespace').stdout
```
<!-- /insertSnippet -->

then, using the Kubernetes API we can retrieve the information we need and write our assertions as usual 

<!-- insertSnippet[test_k8s_environment_variables_assert_labels] -->
```Bash
config.load_kube_config()
v1 = client.CoreV1Api()
pod = v1.read_namespaced_pod(name=hostname, namespace=namespace)
assert pod.metadata.labels['log-service-name'] == 'infrastructure-testing-testinfra'
```
<!-- /insertSnippet -->


# Virtual Machines (Hetzner)

## Prerequisites

TODO

For the final part of this post we will have a look on how to test a full VM. Focus in this part is less the how to write test (we now know how to do this), but more the wiring needed to seamlessly connect testinfra to a cloud VM.
Tesinfra provides the [ssh backend](https://testinfra.readthedocs.io/en/latest/backends.html#ssh) for this purpose and expects a connection string like this

```Bash
py.test --ssh-config=${ssh_config} --hosts='ssh://${ssh_server}'
```

when connection to a VM via SSH we need to solve two problems

* interactive logins using username and password is not a good fit for automated tests
* since this is a test, the VM will likely be re-provisioned several times, and we don't want to verify the host identity each time, or even worse: blindly connect to any host without checking its identity

the answer to both problems is: certificates!

We are using the Terraform module at [infrastructure-testing-testinfra/hetzner](https://github.com/pellepelster/kitchen-sink/tree/master/infrastructure-testing-testinfra/hetzner) to provision all resources related to the VM. Using Terraform we can also generate an SSH key that we provide when provisioning the server

<!-- insertSnippet[infrastructure-testing-testinfra_ssh_client_identity] -->
```Bash
resource "tls_private_key" "ssh_client_identity" {
  algorithm = "RSA"
}

resource "hcloud_ssh_key" "ssh_key" {
  name       = "infrastructure-testing-testinfra"
  public_key = tls_private_key.ssh_client_identity.public_key_openssh
}
```
<!-- /insertSnippet -->

which allows us to login into the server using the private part of the key. Writing it to the local filesystem allows us (and testinfra) to use it

<!-- insertSnippet[infrastructure-testing-testinfra_local_file_ssh_client_identity] -->
```Bash
resource "local_file" "ssh_client_identity" {
  content         = tls_private_key.ssh_client_identity.private_key_openssh
  filename        = "${path.module}/ssh/ssh_client_identity"
  file_permission = "0600"
}
```
<!-- /insertSnippet -->

Now to avoid the host identity check we generate another key, that we use as SSH host identity

<!-- insertSnippet[infrastructure-testing-testinfra_ssh_host_identity] -->
```Bash
resource "tls_private_key" "ssh_host_identity" {
  algorithm = "RSA"
}
```
<!-- /insertSnippet -->

and then insert the generated host identify into the OpenSSH server, using the cloud init script

<!-- insertSnippet[infrastructure-testing-testinfra_userdata-ssh] -->
```Bash
function sshd_config {
cat <<-EOF
HostKey /etc/ssh/ssh_host_identity_key

LoginGraceTime 2m
PermitRootLogin yes

PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no

ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no

AcceptEnv LANG LC_*
EOF
}

function sshd_setup() {
  local ssh_host_identity_key_base64="${1:-}"
  rm -rf /etc/ssh/ssh_host_*_key.pub

  touch /etc/ssh/ssh_host_identity_key
  chmod 600 /etc/ssh/ssh_host_identity_key
  echo "${ssh_host_identity_key_base64}" | base64 -d > /etc/ssh/ssh_host_identity_key

  sshd_config > /etc/ssh/sshd_config
  service ssh restart
}
```
<!-- /insertSnippet -->

using the public key part of the host identify key, we can then move forward and generate a known hosts file for our test VM

<!-- insertSnippet[infrastructure-testing-testinfra_template_file_known_hosts] -->
```Bash
data "template_file" "known_hosts" {
  template = file("${path.module}/templates/known_hosts.template")

  vars = {
    ip_address            = hcloud_server.server.ipv4_address
    ssh_host_identity_pub = tls_private_key.ssh_host_identity.public_key_openssh
  }
}
```
<!-- /insertSnippet -->

Finally, we tie everything together with an `ssh_config` that we generate with Terraform using the following template

<!-- insertFile[ssh_config.template] -->
```Bash
Host infrastructure-testing-testinfra
    Hostname ${ip_address}
    UserKnownHostsFile ${known_hosts_file}
    IdentityFile ${client_identity_file}
    IdentitiesOnly yes

```
<!-- /insertFile -->

This defines a config for the host `infrastructure-testing-testinfra` with the current `${ip_address}` of the virtual machine. The `${client_identity_file}` we used to provision the host which will let us log in without a password and the `${known_hosts_file}` containing the public key for the host identity making sure we trust the right host because the public key in the file matches the private key used as SSH host identity.


now we have everything we need to provide testinfra with a full connection string that allows it to automatically connect via SSH using the generated config file

<!-- insertSnippet[infrastructure-testing-testinfra_task_hetzner_deploy] -->
```Bash
  (
    cd "${DIR}/hetzner"
    terraform init -upgrade
    terraform apply -auto-approve
  )

  while [[ "$(ssh -F "${DIR}/hetzner/ssh/ssh_config" root@infrastructure-testing-testinfra whoami)" != "root" ]]; do
    echo "waiting for ssh"
    sleep 2
  done
```
<!-- /insertSnippet -->

The while-wait-loop ensures that the SSH server, is ready to accept connections using the pre-generated keys.

Now we are nearly ready to run our testinfra tests like we did in Docker or Kubernetes, the only thing we need to keep in mind, is that if we want to test anything that is a result of the user-data execution we need to wait until cloud-init is finished executing the user data part. 

We can achieve this by adding a global wait to the pytest module, that will wit for the cloud-init result file, ny only continue if it exists and does not contain any errors.

<!-- insertSnippet[infrastructure-testing-wait-cloud-init] -->
```Bash

def wait_until(predicate, timeout, period=2, *args, **kwargs):
    end = time.time() + timeout
    while time.time() < end:
        if predicate(*args, **kwargs):
            return True
        time.sleep(period)
    return False


def host_is_initialized(host):
    result_file = host.file("/run/cloud-init/result.json")
    return result_file.exists


@pytest.fixture(scope="module", autouse=True)
def wait_for_host_is_initialized(host):
    wait_until(lambda: host_is_initialized(host), 60)
    result = json.loads(host.file("/run/cloud-init/result.json").content)
    assert len(result['v1']['errors']) == 0, f"cloud init finished with errors '{result['v1']['errors']}'"


def test_hetzner_caddy_runs_as_non_root_user(host):
    caddy = host.process.get(comm="caddy")
    assert caddy.user == 'caddy'


```
<!-- /insertSnippet -->

