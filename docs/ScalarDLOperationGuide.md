# Scalar DL Operation Guide

This document explains operation for Scalar DL that can be made to restore default state

## How to upgrade Scalar DL

### Steps

When you want to apply the changes of `scalardl-custom-values.yaml` or `schema-loading-custom-values.yaml`, please update them in your local repository `SCALAR_K8S_HOME` and execute the following command.

```console
$ ansible-playbook -i ${SCALAR_K8S_CONFIG_DIR}/inventory.ini playbooks/playbook-deploy-scalardl.yml
```

More information will be available at each release.

## How to force restart a Scalar DL pods

Force restart might be required when you want to redistribute pods to available nodes evenly.


### Steps

Get the list of pods that can be rolled out.

```console
$ kubectl get deployments.apps
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
prod-scalardl-envoy    3/3     3            3           5h11m
prod-scalardl-ledger   3/3     3            3           5h11m
```

for example with `prod-scalardl-envoy`

```console
$ kubectl patch deployment prod-scalardl-envoy -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
deployment.apps/prod-scalardl-envoy patched
```

Check with `kubectl get deployments.apps`

```console
$ kubectl get deployments.apps
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
prod-scalardl-envoy    3/3     1            2           5h12m
prod-scalardl-ledger   3/3     3            3           5h12m
```

or with `rollout` sub command

```console
kubectl rollout status deployment prod-scalardl-envoy
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 2 of 3 updated replicas are available...
Waiting for deployment "prod-scalardl-envoy" rollout to finish: 2 of 3 updated replicas are available...
deployment "prod-scalardl-envoy" successfully rolled out
```

Note that you will receive a slack notification if it is activated during the pod rollout.

```
[FIRING:1] EnvoyClusterDegraded - warning
Alert: Envoy cluster is running in a degraded mode - warning
 Description: Envoy cluster is running in a degraded mode, some of the Envoy pods are not healthy.
 Details:
  • alertname: EnvoyClusterDegraded
  • app: Envoy
```

```
[RESOLVED] EnvoyClusterDegraded - warning
Alert: Envoy cluster is running in a degraded mode - warning
 Description: Envoy cluster is running in a degraded mode, some of the Envoy pods are not healthy.
 Details:
  • alertname: EnvoyClusterDegraded
  • app: Envoy
```
