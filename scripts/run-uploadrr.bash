#!/bin/bash

kubectl run upload-assistant \
    --rm -it \
    --image="ghcr.io/audionut/upload-assistant:latest" \
    --namespace=media \
    --timeout=5m \
    --overrides='{"spec":{"securityContext":{"runAsUser":1000,"runAsNonRoot":true,"readOnlyRootFilesystem":true},"containers":[{"name":"upload-assistant","image":"ghcr.io/audionut/upload-assistant:latest","imagePullPolicy":"Always","securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"volumeMounts":[{"name":"media","mountPath":"/media/Downloads","subPath":"Downloads"},{"name":"tmp","mountPath":"/tmp"},{"name":"config","mountPath":"/Upload-Assistant/data/config.py","subPath":"config.py"}],"stdin":true,"tty":true,"command":["/bin/bash"]}],"volumes":[{"name":"media","persistentVolumeClaim":{"claimName":"media"}},{"name":"tmp","emptyDir":{}},{"name":"config","persistentVolumeClaim":{"claimName":"uploadrr-config"}}]}}' \
    -- 
