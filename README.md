# Homecluster

Talos Kubernetes Cluster@Home with Applications managed by ArgoCD

## Layout
- `kubernetes/bootstrap` Argo-CD applications
- `kubernetes/apps` application configuration
- `kubernetes/init` initial cluster setup (applied once)
- `talos/` TalOS configurations (using `talhelper`)
- `network/` OpenWRT router configuration 

## Setup

To deploy a cluster, secrets must be generated first with `just apply-initial`. This has to be done only once.
Then run  `just bootstrap` if it's the first node. Talos should now be running. After successful kubelet startup, run `helmfile apply -f kubernetes/init/helmfile.yaml` and `kubectl apply -f kubernetes/cluster.yaml`. Argo-CD should sync all apps and the cluster is up and running.

ArgoCDs initial password can be obtained with `argocd admin initial-password -n argocd`, webinterface access is provided by running `just forward-argocd` and then opening `http://localhost:13000` in a webbrowser.

## Secrets

Secrets are encrypted using SOPS. There are two different SOPS keys, one for my local machine, one for the cluster. 

The local key is used to encrypt secrets in `talos/`, `network/` and `kubernetes/init`. These secrets are not required inside the cluster.

The cluster key is used for `kubernetes/apps` secrets. Its private key is encrypted as `kubernetes/init/age-secret.sops.yaml` using my local key. This is the only occurence of that private key, I don't have it accessible anywhere else. This should prevent me from accidentally decrypting secrets. Instead, it's better to recreate/encrypt new secrets if they change.