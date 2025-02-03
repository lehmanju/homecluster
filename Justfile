[working-directory: 'talos']
@genconfig:
  helm template cilium cilium/cilium --version 1.16.6 -f ../kubernetes/apps/infrastructure/cilium/values.yaml -n kube-system > clusterconfig/cilium.yaml
  talhelper genconfig

[working-directory: 'talos/clusterconfig']
@applyconfig:
  talosctl apply-config -n 192.168.1.123 --file homecluster-raspberrypi-black.yaml --insecure

[working-directory: 'talos/clusterconfig']  
@apply:
  talosctl apply-config -n 192.168.1.123 -e 192.168.1.123 --file homecluster-raspberrypi-black.yaml --talosconfig=./talosconfig

[working-directory: 'talos']
@gensecrets:
  talosctl gen secrets -o secrets.yaml

[working-directory: 'talos/clusterconfig']
@bootstrap:
  talosctl bootstrap -n 192.168.1.21 -e 192.168.1.21 --talosconfig=./talosconfig
  kubectl apply -f cilium.yaml

debug:
  kubectl debug -n kube-system -it --image busybox node/raspberrypi-black --profile=sysadmin

[working-directory: 'talos/clusterconfig']
@dashboard:
  talosctl -n 192.168.1.21 -e 192.168.1.21 --talosconfig=./talosconfig dashboard

[working-directory: 'talos/clusterconfig']
@reset:
  talosctl -n 192.168.1.123 -e 192.168.1.123 --talosconfig=./talosconfig reset --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --reboot

[working-directory: 'talos/clusterconfig']
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