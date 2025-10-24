#!/bin/bash

kubectl run upload-assistant \
    --rm -it \
    --image="ghcr.io/audionut/upload-assistant:latest" \
    --namespace=media \
    --timeout=5m \
    --overrides='{"spec":{"securityContext":{"runAsUser":1000,"runAsNonRoot":true,"readOnlyRootFilesystem":true},"containers":[{"name":"upload-assistant","image":"ghcr.io/audionut/upload-assistant:latest","imagePullPolicy":"Always","securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"volumeMounts":[{"name":"media","mountPath":"/media/Downloads/qbittorrent","subPath":"Downloads/qbittorrent"},{"name":"media-ext","mountPath":"/media-ext/Downloads/qbittorrent","subPath":"Downloads/qbittorrent"},{"name":"tmp","mountPath":"/tmp"},{"name":"config","mountPath":"/Upload-Assistant/data/config.py","subPath":"config.py"},{"name":"config","mountPath":"/Upload-Assistant/data/cookies","subPath":"cookies"}],"stdin":true,"tty":true,"command":["/bin/bash"]}],"volumes":[{"name":"media","persistentVolumeClaim":{"claimName":"media"}},{"name":"media-ext","persistentVolumeClaim":{"claimName":"media-ext"}},{"name":"tmp","emptyDir":{}},{"name":"config","persistentVolumeClaim":{"claimName":"uploadrr-config"}}]}}' \
    --
