# Homecluster

Talos Kubernetes Cluster@Home with Applications managed by ArgoCD

## Structure
- `argocd/` contains argocd managed applications
- `talos/` contains Talos OS configurations

## Setup

To deploy a cluster, secrets must be generated first with `just gensecrets`. This has to be done only once.
Then run `just genconfig`, `just applyconfig` and if it's the first node `just bootstrap`. Talos should now be running.

For the initial argocd setup run `just install-argocd`. This installs argocd onto the cluster, all apps are then managed through argocd (including argocd itself).
