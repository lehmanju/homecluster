[working-directory: 'talos']
@genconfig:
  #!/usr/bin/env bash
  set -euxo pipefail
  #chart="$(helm template cilium cilium/cilium --version 1.16.5 -f ../kubernetes/apps/infrastructure/cilium/values.yaml -n kube-system | sed 's/^/        /')"
  #printf "cluster:\n  inlineManifests:\n    - name: cilium\n      contents: |\n%s" "$chart" > cilium.yaml
  helm template cilium cilium/cilium --version 1.16.5 -f ../kubernetes/apps/infrastructure/cilium/values.yaml -n kube-system > cilium.yaml
  talhelper genconfig

[working-directory: 'talos']
@applyconfig:
  talosctl apply-config -n 192.168.1.123 --file controlplane.yaml --insecure

[working-directory: 'talos']  
@apply:
  talosctl apply-config -n 192.168.1.123 -e 192.168.1.123 --file controlplane.yaml --talosconfig=./talosconfig
  python3 serve_cilium.py

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
  talosctl -n homecluster -e homecluster --talosconfig=./talosconfig dashboard

[working-directory: 'talos']
@reset:
  talosctl -n homecluster -e homecluster --talosconfig=./talosconfig reset --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --reboot

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