---
title: "Infrastructure Testing with Testinfra"
date: 2024-03-25T19:00:00
draft: true
---

An often overlooked and admittedly cumbersome topic is the testing of infrastructure resources and components. 

Even a simple setup like a VM that is spun up in some cloud to serve HTTP requests, already confronts us with some hurdles to solve.
A pragmatic approach for testing such a setup could be to ensure after the deployment that the HTTP port of the created VMs answers with a success HTTP code (2xx).

Although this proves that the deployment was successful, there could be misconfigurations that do not cause an error which is  observable from the outside, but could still put out deployment at risk.
This could for example be a set of wrong permissions for a folder introducing a security risk, or a configuration value for the service that could cause harm in some special cases like for example some debug setting that is only meant for local debugging. 

With the inherent complexity of more advanced stacks like Kubernetes, the problem only gets harder because the single component that we might want to test could be even harder to reach than the content of a simple VM.

A library that can help us with that is [testinfra](https://testinfra.readthedocs.io/en/latest/) which is a plugin for the Python testing framework [pytest](https://pytest.org/) and enables us to run Python tests in and on infrastructure components.

This post will show you how to use [testinfra](https://testinfra.readthedocs.io/en/latest/) to make your infrastructure deployments more predictable and shorten the feedback cycle for infrastructure code development. 

> As always the full code is available online here [github.com/pellepelster/kitchen-sink/infrastructure-testing-testinfra](https://github.com/pellepelster/kitchen-sink/tree/master/infrastructure-testing-testinfra). The folder contains a `do` file to start all tasks needed to follow the example in this post.

# Bootstrapping

As usual when working with Python code the first step is to bootstrap a Python environment dedicated to our project,
first create the file **requirements.txt**

<!-- insertFile[requirements.txt] -->
```Bash
pytest-testinfra==10.1.0
requests==2.31.0
```
<!-- /insertFile -->

containing all needed Python dependencies, and then init the Python Venv with 

<!-- insertSnippet[bootstrap-venv] -->
```Bash
if [[ ! -d "${DIR}/venv/" ]]; then
  python3 -m venv "${DIR}/venv/"
  "${DIR}/venv/bin/pip" install -r "${DIR}/requirements.txt"
fi
```
<!-- /insertSnippet -->

For the example project you can bootstryp everything with

```Bash
cd infrastructure-testing-testinfra
./do bootstrap
```

That's it, we now have a Python environment with testinfra in it, and are ready to write our first test. 

# Docker

As a first step to learn how testinfra work, we will use a docker image as our test target. In a real-world scenario this could be used to ensure that certain tools are installed in a docker image, or that permissions are correctly set.

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

To build the docker image, run

```Bash
./do docker-build
```

We can see the author of this `Dockerfile` spent some effort in getting the permissions for the HTTP server right, and also went the extra mile to make sure the `www` user in the container does not clash with any user ids on the host system, lets make sure this stays this way by adding a test for it.

Since testinfra is a pytest plugin everything is executed in the scope of a pytest. The special feature of testinfra is, that it passes a `host` object into the test methods that can be used to do assertion on the target, in out case the docker image

<!-- insertSnippet[test_caddy_runs_as_non_root_user] -->
```Bash
def test_caddy_runs_as_non_root_user(host):
    caddy = host.process.get(comm="caddy")
    assert caddy.user == 'www'
```
<!-- /insertSnippet -->

The example above tries to the get the process with the name `caddy` and asserts it is running with the correct user id (`wwww`).

Testinfra comes with a wide range of [connection backends](https://testinfra.readthedocs.io/en/latest/backends.html), that can be used to talk to different infrastructure types. In our case we want to test a locally running docker container, using the [docker](https://testinfra.readthedocs.io/en/latest/backends.html#docker) backend.

Common to all backends is, that we have to provide a connection string, telling testinfra how to connect to the backend, in the Docker case this looks like this

````Bash
py.test --hosts='docker://[user@]container_id_or_name'
````

So, now all that's left to run the test, is to start the docker container, and provide the resulting container id to testinfra, so it can connect to the container and run the assertions.

<!-- insertSnippet[task_docker_test] -->
```Bash
docker run --detach --name "${DOCKER_IMAGE_NAME}" "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
"${DIR}/venv/bin/py.test" --verbose --capture=tee-sys --hosts="docker://${DOCKER_IMAGE_NAME}" "${DIR}/test/test_docker.py"
```
<!-- /insertSnippet -->

Note that because testinfra is a pytest plugin it can directly be started via the `py.test` binary from our previous created Python environment. You can run

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

As we can see all tests from [TODO](TODO) were successfully executed, and we can now be sure that our docker container is fir for deployment in the next step.

# Kubernetes

# Hetzner