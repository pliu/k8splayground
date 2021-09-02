# Pod Behaviour
Understanding the behaviour of Pods and the containers that comprise them and the interaction between their behaviours is important for ensuring workloads behave the way they're expected to, especially at critical points such as container failure or controlled termination. Below, we document various container and Pod behaviours and provide resources and instructions for investigating them for yourself.

Unfortunately, we have not documented all combinations of the various configurations and their behaviour. Instead, we encourage you to explore these edge cases further on your own, as is done in the other modules of K8sPlayground.

## The test application
The primary tool we will use for testing behaviour is containers/app.py. It is a simple Python app that sleeps forever but has listeners for all signals except SIGKILL, which can't be intercepted. When a signal is received, it will print the signal received and, depending on the signal, may exit.

By default, the app will exit immediately with a zero exit code when receiving SIGTERM (as sent by a default kill command). However, the app can take three flags:

- --sigint: instead of exiting on SIGTERM, the app will exit on SIGINT (Ctrl+C)
- --timed: instead of exiting immediately, the app will exit after 60s, printing the time each second for the first 30s and then a final time after 30 more seconds
- --error: instead of exiting with a zero exit code, the app will exit with a non-zero exit code

When the application is first started, it will print its settings ('SIGINT' if set to exit upon receiving SIGINT or 'SIGTERM' if set to exit upon receiving SIGTERM, 'Timed exit' if set to wait before exiting or 'Immediate exit' if set to exit immediately, and 'Zero exit code' if set to exit with exit code 0 and 'Non-zero exit code' if set to exit with exit code 1).

In addition to this application, we have provided a number of example Dockerfiles that package the app in various ways. Run `make behaviour_build` to build all of these example images (their Dockerfiles can be found at containers/Dockerfile_\<image name>). The images

We also provide numerous example Pod manifests to demonstrate the interaction between Docker containers and Kubernetes Pods.

## Dockerfile CMD vs. ENTRYPOINT
We will first investigate the difference between CMD and ENTRYPOINT Docker instructions using the cmd and entrypoint-cmd images.

The cmd image uses CMD to run `python app.py` inside the container. When we run this container using `docker run --name test cmd:0.0.1`, it runs as expected (prints 'SIGTERM', 'Immediate exit', and 'Zero exit code'). If you Ctrl+C, 'Received 2' should be printed, indicating that 2 is the identity of SIGINT, but the container doesn't stop because this run of app.py is set to exit on SIGTERM. Now stop and remove the container (`docker stop test` and `docker rm test`). After the stop command, 'Received 15' should be printed, indicating that `docker stop` sends signal 15 (SIGTERM) to the container.

Continuing, run `docker run --name test cmd:0.0.1 echo test`. It prints 'test' and then exits - it didn't run app.py at all! This is because when running `docker run` with a command, the command (`echo test` in this case) overrides the Dockerfile-specified CMD. Since the container is already stopped, just remove it using `docker rm test`.

The entrypoint-cmd image has ENTRYPOINT set to `python` and CMD set to `app.py` inside the container. When we run this container using `docker run --name test entrypoint-cmd:0.0.1`, it runs the same as the cmd image without commands. However, if we run `docker run --name test entrypoint-cmd:0.0.1 --version`, it just prints the Python version and exits. This is because, just as in the previous case, when running `docker run` with a command, the command-line command (`--version` in this case) overrides the Dockerfile-specified CMD and if both ENTRYPOINT and CMD are specified, the command that is run is ENTRYPOINT followed by CMD, passed in as arguments (in this case, since ENTRYPOINT is `python` and CMD was overriden by `--version`, the overall command that is run is `python --version`). Since the container is already stopped, just remove it using `docker rm test`.

In these and subsequent examples using Docker containers, you can use `docker ps -a` to list all containers, running or stopped, to observe their status and verify that it matches their expected status (a container that is running will have a Status of 'Up \<duration>' while a stopped container will have a Status of 'Exited (\<exit code>) \<duration> ago').

## exec vs. shell form
Next we will investigate the difference between shell and exec forms of ENTRYPOINT using the entrypoint-exec and entrypoint-shell images. The same principle applies to CMD as well, but we will only demonstrate this using ENTRYPOINT here.

The entrypoint-exec image uses `ENTRYPOINT ["python", "app.py"]`. When we run this container using `docker run --name test entrypoint-exec:0.0.1`, it runs the same as expected (prints 'SIGTERM', 'Immediate exit', and 'Zero exit code'). If you Ctrl+C, 'Received 2' should be printed without stopping the container and when you `docker stop test`, 'Received 15' should be printed before the container stops. Remove the stopped container using `docker rm test`.

The entrypoint-shell images uses `ENTRYPOINT python app.py`. When we run this container using `docker run --name test entrypoint-shell:0.0.1`, it runs the same as entrypoint-exec image. However, unlike in the entrypoint-exec case, if you Ctrl+C or `docker stop test` there is no 'Received 2' or 'Received 15' and `docker stop` hangs for about 10s before stopping. This is because when ENTRYPOINT is called with `ENTRYPOINT python app.py` it is executed in shell form instead of in exec form as is the case when it is called with a list like in `ENTRYPOINT ["python", "app.py"]`. In exec form, the stop signal sent when attempting to stop the container is sent directly to the application started by the container whereas in shell form, the stop signal is sent to the shell that launched the application instead. Since the container is now stopped, just remove it using `docker rm test`.

Interestingly, exec and shell forms also have implications for argument passing. Recall that when we used the entrypoint-cmd image, it combined the ENTRYPOINT (`["python"]`) and CMD (`["app.py"]`) in exec form to run `python app.py`. When we pass arguments to an image run that uses exec form (`docker run --name test entrypoint-cmd:0.0.1 --version` or `docker run --name test entrypoint-exec:0.0.1 --timed`), they are passed in like the CMD field of the image's Dockefile (if the CMD field is set in the Dockerfile, it is overridden). When shell form is used, the CMD field, whether set in the Dockerfile or passed in as arguments, is ignored. We can observe this using the entrypoint-shell image whose ENTRYPOINT is `python app.py` and whose CMD is `["--timed"]`. Running `docker run --name test entrypoint-shell:0.0.1` or `docker run --name test entrypoint-shell:0.0.1 --timed`does not print 'Timed exit' as would be the case if the image was run in exec form.

#### Bonus
More specifically, the stop signal sent when attempting to stop the container is sent to pid 1 within the container. When this process terminates, the container is considered to have stopped. In exec form, the process at pid 1 in the container execs the desired command and so the application is running at pid 1 and so receives the stop signal, but, in shell form, pid 1 is actually a shell (/bin/sh) from which the application is started (you can verify this by opening a shell into the container with `docker exec -it test /bin/sh` and listing the processes with `ps aux`). Therefore, the stop signal is received by the shell and not the application. This is why in the examples from the previous section where we modified the container to run `echo test` or `python --version`, the containers stopped immediately after.

If you're familiar with processes (e.g., fork, orphaning), you might rightfully be wondering "What happens to any processes started by pid 1?". You can find a discussion of the issue [here](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/).

The reason that the entrypoint-shell container still stops after hanging for about 10s is because `docker stop` has a grace period (10s by default and can be set with the `-t <time in seconds>` flag when calling `docker stop`) between sending the stop signal and waiting for the container to stop gracefully and sending SIGKILL and forcibly terminating the container.

It should be noted that we use ubuntu:18.04 as the base image for entrypoint-exec and entrypoint-shell and not python:2.7-alpine as with the other images. This is because when python:2.7-alpine is used, the resulting images do not exhibit the expected shell form behaviour (even when the Dockerfile's ENTRYPOINT is specified in shell form, `python app.py` is run with pid 1). An interesting exercise would be to determine why this is the case.

## Default container STOPSIGNAL
As we saw in previous sections, the default STOPSIGNAL sent to pid 1 when calling `docker stop` is SIGTERM. However, you can set an image's default STOPSIGNAL. The stopsignal image does just this with `STOPSIGNAL SIGINT`, setting its default STOPSIGNAL to SIGINT. Run this container using `docker run --name test stopsignal:0.0.1`. When you try to stop it using `docker stop test`, 'Received 2' should be printed instead of 'Received 15', indicating that it received SIGINT instead of SIGTERM. As in the previous section, `docker stop` will hang for 10s (the default grace period; the application does not terminate as it is configured to terminate on SIGTERM and not SIGINT) before being SIGKILLed and stopped. Remove the stopped container with `docker rm test`.

#### Bonus
Start the stopsignal container again with `docker run --name test stopsignal:0.0.1`. This time, stop it with `docker stop -t 3600 test`. As mentioned in the previous section, this will set a 1h grace period before SIGKILLing pid 1 and stopping the container. Since the application is configured to terminate on SIGTERM but the image is configured to send SIGINT, this is expected to hang for 1h before stopping. To stop the container prematurely, run `docker inspect -f '{{.State.Pid}}' test` to find the host-level pid of the root-owned process running as pid 1 in the container (the one running app.py). Kill the process using `sudo kill <pid>`. Since you are sending the signal to the process directly, it receives the exact signal you specify - bypassing the default STOPSIGNAL (in this case, calling `kill` without any flags sends a SIGTERM which terminates the process and stops the container). Remove the stopped container with `docker rm test`.

The above demonstrates the hierarchical nature of pid namespaces: from a given pid namespace, you can observe and act on any processes running in that namespace as well as any processes running in child pid namespaces. Another example of this is to use `ps aux | grep app.py` instead of `docker inspect` to find the host-level pid of the container process running app.py (assuming you only have one container running app.py, there should only be one such root-owned process). In this case, the process running app.py doesn't have to be running as pid 1 within the container (you can use the entrypoint-shell image from the previous section, which runs /bin/sh at pid 1 inside the container, to test this).

## Pod termination
In this and the following sections, we will see how containers interact with the Kubernetes machinery. This will require Kubernetes so ensure that the kind cluster is running. Run `kind load docker-image small-entrypoint-exec:0.0.1 --name k8splayground` to load the small-entrypoint-exec:0.0.1 image to the kind "hosts" - this is identical to entrypoint-exec except it uses python:2.7-alpine as as the base image (using alpine as the base image significantly reduces the resulting image's size) and is the image all of our Pod manifests will use unless indicated otherwise.

We begin by investigating Pod termination using manifests/pod-default.yaml. Apply the manifest to start the Pod with `kubectl apply -f pod-default.yaml`. Unlike in the previous sections with Docker where the logs were automatically printed, to print the logs from the container, run `kubectl logs default --follow` (this works because there is only one container in the Pod, the recommended pattern; however, you can have multiple containers per Pod, in which case you will need to specify the name of the container whose logs you'd like). When you delete the Pod with `kubectl delete pod default`, the logs should show 'Received 15' before the connection is broken due to the container being stopped as part of Pod deletion.

Run `kind load docker-image stopsignal:0.0.1 --name k8splayground` to load the stopsignal:0.0.1 image to the kind "hosts". Run `kubectl apply -f pod-stopsignal.yaml` to start a Pod with a container running the stopsignal image. Tail the logs with `kubectl logs stopsignal --follow` and then delete the Pod with `kubectl delete pod stopsignal`. Just like in the previous section, 'Received 2' should be printed instead of 'Received 15', and the `kubectl delete pod` command will hang before the container is stopped. Just like in the previous section, this is because the application initially received SIGINT instead of SIGTERM, doesn't terminate because it is configured to terminate on SIGTERM, and is finally killed with SIGKILL after the default grace period (the default grace period for `kubectl delete pod`, unlike with `docker stop`, is 30s).

The above examples show that deleting Pods behaves similarly to calling `docker stop` on the underlying containers comprising the Pod. In both of the above cases, as well as subsequent examples using Pods, you can use `kubectl get pods` to list all Pods in the default namespace (where the test Pods are created) to observe their status and verify that it matches their expected status (a Pod that is running will have Status 'Running', one that is in its termination grace period will have Status 'Terminating', and, unlike in the Docker case, one that has been terminated will not be displayed).

#### Bonus
Once we have called `kubectl delete pod` on a Pod, can we decide that we no longer want to terminate the Pod during its grace period? Run `kubectl apply -f pod-stopsignal.yaml` to bring up the test Pod. Run `docker exec -it k8splayground-worker /bin/bash` to open a shell into the kind "host" (the Pod must be running on this worker since the other worker has a taint that this Pod does not tolerate and thus cannot be scheuled there). Inside the shell into k8splayground-worker, first run `ps aux | grep containerd-shim` - each one of these processes is a container running on the kind "host".

Next, from your local shell, run `kubectl delete pod stopsignal --grace-period=300`. Similar to `docker stop`, `kubectl delete pod` supports a `--grace-period=<time in seconds>` flag to modify the grace period. The default grace period applied to a Pod can also be set in a Pod's manifest with the `terminationGracePeriod` attribute. In this case, this Pod would be expected to terminate after 5m. Within the next 4m, inside the shell into k8splayground-worker, run `chmod -x /usr/bin/kubelet` to make the kubelet non-executable to prevent it from restarting after it is killed and then kill it after finding its pid using `ps aux | grep kubelet`. After 6m have passed, we would expect the container to have been stopped had we not terminated the kubelet process (you should verify this). Running `ps aux | grep containerd-shim` inside the shell into k8splayground-worker, though, the number of running containers should be the same as when we first checked, indicating that the container did not stop despite the grace period elapsing. Unlike in other examples, we cannot rely on viewing the container's logs in this example because `kubectl logs` requires the kubelet that is managing the relevant Pod to be running.

Now, restart the kubelet on the kind "host" by running `chmod +x /usr/bin/kubelet` inside the shell into k8splayground-worker. Restarting the kubelet does not immediately trigger sending the missed SIGKILL to stop the container, but does so eventually (you can verify this with `ps aux | grep containerd-shim` as above). To stop the container, in your local shell, run `kubectl delete pod stopsignal --force --grace-period=0`.

A detailed view of the Pod termination flow can be found [here](https://kubernetes.io/docs/concepts/workloads/pods/pod/#termination-of-pods) and explains much of the behaviour observed in this section.

## Dockerfile CMD and ENTRYPOINT vs. Pod container spec
In the previous sections, we saw how Dockerfile's CMD and ENTRYPOINT interact with each other and with `docker run`. In this section, we'll see how they interact with the container spec of a Kubernetes Pod.

First, we will use manifests/pod-args.yaml - a copy of manifests/pod-default.yaml except it sets the container's args field as `["--timed"]`. Applying this manifest with `kubectl apply -f pod-args.yaml` and then checking its logs with `kubectl logs args --follow` should show that in place of 'Immediate exit', it outputs 'Timed exit', indicating that `python app.py --timed` was called despite the image specifying `ENTRYPOINT ["python", "app.py"]`. This is because the container's args override the image's CMD and are thus passed as arguments to the ENTRYPOINT (similar to `docker run` in a previous section). Delete the Pod using `kubectl delete pod args` (this will hang for 1m because the --timed flag causes the process to wait 1m before terminating).

Next, we will use manifests/pod-command.yaml - a copy of manifests/pod-default except it sets the container's command field as `["echo", "test"]`. Applying this manifest with `kubectl apply -f pod-command.yaml` and then checking the logs with `kubectl logs command` should show that it output 'test' and not 'SIGTERM', 'Immediate exit', and 'Zero exit code' as is expected of app.py. Unlike with `docker run`, which can override an image's CMD, the container's command field overrides the image's ENTRYPOINT.

Finally, the difference between exec and shell forms mentioned above applies here as well. Run `kind load docker-image small-entrypoint-shell:0.0.1 --name k8splayground` to load the small-entrypoint-shell:0.0.1 image (whose ENTRYPOINT, `python app.py`, is in shell form) to the kind "hosts". Run `kubectl apply -f pod-shell-args.yaml` to bring up the test Pod. Unlike manifests/pod-args.yaml (whose image's ENTRYPOINT, `["python", "app.py"]`, is in exec form), manifests/pod-shell-args.yaml outputs 'Immediate exit' (`kubectl logs shell-args --follow`) instead of 'Timed exit' despite its args field being set to `["--timed"]` just as manifests/pod-args.yaml's. This demonstrates that, similar to the `docker run` case above, arguments passed to a shell form image are ignored.

## Process exit code and Pod container restart policy
You may remember that in the first section when we modified the container to run `echo test` with `docker run`, the container exited after running the command. What about the container from the last section that was started as part of the Pod? If you run `kubectl get pods` you should see that the Pod's Status is 'Completed' and Ready at 0/1, indicating there are 0 containers running. This is because the process at pid 1 in the container exited with the non-error exit code 0 and the Pod's restartPolicy is OnFailure (as its name suggests, this Pod will only restart containers that exit with a non-zero exit code). Run `kubectl delete pod command` to clean up this Pod.

To test this further, we use manifests/pod-onfailure.yaml, which uses the container's args field to run `python app.py --error` causing the process to exit with a non-zero exit code when terminating. Run `kubectl apply -f pod-onfailure.yaml` and then, taking advantage of the behaviour of hierarchical pid namespaces (the Pod's container pid namespace is running insider the kind "host" container pid namespace which is in the root pid namespace), run `ps aux | grep app.py` to find the pid of the root-owned process running `python app.py --error`. Now kill that process with `sudo kill <pid>` and check `kubectl get pods`. Unlike the previous example, despite the container having been terminated (you can check that the container received SIGTERM by accessing the logs of the previous container using `kubectl logs onfailure --previous` instead of `kubectl logs onfailure`, which would access the logs of the current container), Status should be 'Running', Ready is 1/1, indicating that the 1 expected container is running, and Restarts is 1. This is because the process terminated with a non-zero exit code (you can also check this with `kubectl describe pod onfailure`), indicating failure and the restartPolicy is set to OnFailure. Delete the Pod with `kubectl delete pod onfailure`.

Using restart policies (Always, OnFalure, or Never), therefore, is a great way to control the self-recovery properties of your containers.

## Commands
```
Start container:
docker run --name <container name> <image name>:<image version> <commands, if any>

List containers (both running and stopped):
docker ps -a

Stop container:
docker stop -t <grace period in seconds> <container name>

Remove container (must already be stopped):
docker rm <container name>

Get a shell into a Docker "host":
docker exec -it <container name [`docker ps` to find it]> <shell [e.g., /bin/bash, /bin/sh]>

Create Kubernetes resource from a manifest in the default namespace:
kubectl apply -f <path to manifest>

Tail the logs of a Pod in the default namespace:
kubectl logs <Pod name> --follow

List Pods in the default namespace:
kubectl get pods

Delete a Pod in the default namespace:
kubectl delete pod <Pod name> --grace-period=<grace period in seconds>

Build all test images:
make behaviour_build
```
