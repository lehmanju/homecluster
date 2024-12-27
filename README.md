# Homecluster

Talos Kubernetes Cluster@Home with Applications managed by ArgoCD

## Structure
- `kubernetes/` contains argocd managed applications
- `talos/` contains Talos OS configurations

## Setup

To deploy a cluster, secrets must be generated first with `just gensecrets`. This has to be done only once.
Then run `just genconfig`, `just applyconfig` and if it's the first node `just bootstrap`. Talos should now be running.

For the initial argocd setup run `just install-argocd`. This installs argocd onto the cluster. Afterwards run `just install-clusterapp` to install all apps with "App of Apps" pattern.

ArgoCDs initial password can be obtained with `argocd admin initial-password -n argocd`, webinterface access is provided by running `just forward-argocd` and then opening `http://localhost:8080` in a webbrowser.

