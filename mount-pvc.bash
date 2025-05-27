#!/usr/bin/env bash

#set -o xtrace
set -m

# args: namespace pvc
namespace="$1"
pvc="$2"
# Check if the namespace and PVC name are provided
if [ -z "$namespace" ] || [ -z "$pvc" ]; then
  echo "Usage: $0 <namespace> <pvc>"
  exit 1
fi

kubectl -n "$namespace" run pvc-mounter-"$pvc" --image alpine --restart=Never --overrides "
{
  \"spec\": {
    \"containers\":[
      {
        \"name\": \"pvc-mounter-$pvc\",
        \"image\": \"alpine\",
        \"volumeMounts\": [
          {\"name\": \"pvc-volume\",\"mountPath\": \"/root/data\"}
        ],
        \"command\": [\"/bin/sh\"],
        \"args\": [
          \"-c\",
          \"echo root:root | chpasswd &&\
          apk add --no-cache openssh &&\
          ssh-keygen -A &&\
          /usr/sbin/sshd -o PermitRootLogin=yes -D\"
        ],
        \"readinessProbe\": {
          \"tcpSocket\": {\"port\": 22},
          \"initialDelaySeconds\": 10,
          \"periodSeconds\": 5
        }          
      }
    ],
    \"volumes\": [
      {\"name\": \"pvc-volume\",\"persistentVolumeClaim\": {\"claimName\": \"$pvc\"}}
    ]
  }
}"

# Wait for the pod to be ready
kubectl -n "$namespace" wait --for=condition=ready pod/pvc-mounter-"$pvc" --timeout=60s
# Start port forwarding
kubectl -n "$namespace" port-forward pod/pvc-mounter-"$pvc" 2222:22 &
# Wait for the port forwarding to be ready
sleep 2
# Mount the PVC using SFTP
/usr/bin/gio mount sftp://root@localhost:2222 <<< "root"

fg %1

# On EXIT cleanup
function cleanup {
  # Kill the port-forward process
  pkill -f "kubectl -n $namespace port-forward pod/pvc-mounter-$pvc"
  # Delete the pod
  kubectl -n "$namespace" delete pod pvc-mounter-"$pvc"
}
trap cleanup EXIT