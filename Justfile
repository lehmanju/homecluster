[working-directory: 'talos']
@genconfig:
  talosctl gen config --force --with-secrets secrets.yaml --config-patch-control-plane @nodepatch.yaml homecluster https://192.168.1.123:6443

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
  kubectl apply -k apps/argocd

forward-argocd:
  kubectl port-forward svc/argocd-server -n argocd 8080:443