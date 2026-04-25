[working-directory: 'talos']
@genconfig:
  mkdir -p ./clusterconfig
  sops -d ./talsecret.sops.yaml > ./clusterconfig/.secrets.yaml
  talosctl gen config homecluster https://cluster.lan:6443 --with-secrets ./clusterconfig/.secrets.yaml --config-patch-control-plane "@./minipc.config.yaml" --output-types controlplane,talosconfig --output-dir ./clusterconfig --force
  rm -f ./clusterconfig/.secrets.yaml
  talosctl --talosconfig ./clusterconfig/talosconfig config endpoint 192.168.1.22
  talosctl --talosconfig ./clusterconfig/talosconfig config node 192.168.1.22
  mv ./clusterconfig/controlplane.yaml ./clusterconfig/homecluster-minipc.yaml

[working-directory: 'talos/clusterconfig']
@apply-initial: genconfig
  talosctl apply-config -n 192.168.1.22 --file homecluster-minipc.yaml --insecure
  # todo different nodes

[working-directory: 'talos/clusterconfig']  
@apply-update: genconfig
  talosctl apply-config -n 192.168.1.22 --file homecluster-minipc.yaml --talosconfig=./talosconfig
  # todo different nodes

@bootstrap:
  talosctl bootstrap -n 192.168.1.22 --talosconfig=./talos/clusterconfig/talosconfig
  # wait until control plane is ready
  #helmfile apply -f kubernetes/init/helmfile.yaml
  #kubectl apply -f kubernetes/cluster.yaml

@debug:
  kubectl debug -n kube-system -it --image busybox node/raspberrypi-black --profile=sysadmin

[working-directory: 'talos/clusterconfig']
@dashboard:
  talosctl -n 192.168.1.22 --talosconfig=./talosconfig dashboard

[working-directory: 'talos/clusterconfig']
@reset:
  talosctl -n 192.168.1.21 --talosconfig=./talosconfig reset --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --reboot

[working-directory: 'talos/clusterconfig']
@do +AARGS:
  talosctl -n 192.168.1.22 --talosconfig=./talosconfig {{ AARGS }}

forward-argocd:
  kubectl port-forward svc/argocd-server -n argocd 13000:80

forward-longhorn:
  kubectl port-forward svc/longhorn-frontend -n longhorn-system 13001:80
