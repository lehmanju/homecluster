[working-directory: 'talos']
@genconfig:
  #!/usr/bin/env bash
  set -euxo pipefail
  helm dependency build ../kubernetes/apps/infrastructure/cilium
  chart="$(helm template cilium ../kubernetes/apps/infrastructure/cilium -n kube-system | sed 's/^/        /')"
  printf "cluster:\n  inlineManifests:\n    - name: cilium\n      contents: |\n%s" "$chart" > cilium.yaml
  talosctl gen config --force --with-secrets secrets.yaml --config-patch @raspberry.yaml --config-patch @network.yaml --config-patch @cilium.yaml homecluster https://192.168.1.123:6443

[working-directory: 'talos']
@applyconfig:
  talosctl apply-config -n 192.168.1.123 --file controlplane.yaml --insecure

[working-directory: 'talos']  
@apply:
  talosctl apply-config -n 192.168.1.123 -e 192.168.1.123 --file controlplane.yaml --talosconfig=./talosconfig

[working-directory: 'talos']
@gensecrets:
  talosctl gen secrets -o secrets.yaml

[working-directory: 'talos']
@bootstrap:
  talosctl bootstrap --nodes 192.168.1.123 --endpoints 192.168.1.123 --talosconfig=./talosconfig

debug:
  kubectl debug -n kube-system -it --image ubuntu node/homecluster --profile=sysadmin

[working-directory: 'talos']
@dashboard:
  talosctl -n 192.168.1.123 -e 192.168.1.123 --talosconfig=./talosconfig dashboard

[working-directory: 'talos']
@do +AARGS:
  talosctl -n 192.168.1.123 -e 192.168.1.123 --talosconfig=./talosconfig {{ AARGS }}

[working-directory: 'kubernetes']
install-argocd:
  kubectl create namespace argocd
  kubectl kustomize --enable-helm apps/argocd | kubectl apply -f -

[working-directory: 'kubernetes']
install-clusterapp:
  kubectl apply -f cluster.yaml

forward-argocd:
  kubectl port-forward svc/argocd-server -n argocd 8080:80