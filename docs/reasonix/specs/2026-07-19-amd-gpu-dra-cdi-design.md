# AMD GPU DRA/CDI Migration

**Date:** 2026-07-19
**Status:** Approved design
**Reference:** bjw-s-labs/home-ops@77eba53 (Intel DRA/CDI migration pattern)

## Overview

Migrate from the old ROCm `k8s-device-plugin` (extended resource `amd.com/gpu`) to the standalone AMD DRA Driver (`ROCm/k8s-gpu-dra-driver`) using Kubernetes Dynamic Resource Allocation (DRA) with Container Device Interface (CDI).

This mirrors the pattern used in the Intel GPU migration (bjw-s-labs/home-ops commit 77eba53), adapted for AMD hardware and the ArgoCD GitOps workflow.

## Current State

- **Cluster:** Talos Linux + ArgoCD, single node (`minipc`)
- **GPU:** AMD APU (Phoenix/Hawk Point/Strix) — in-kernel `amdgpu` driver sufficient, no ROCm DKMS needed
- **GPU driver:** ROCm k8s-device-plugin v0.21.0 from `https://rocm.github.io/k8s-device-plugin/`
  - Deployed via ArgoCD at `kubernetes/apps/infrastructure/privileged/amd-gpu/`
  - Values: `labbeler.enabled: true`
- **GPU workloads:**
  - `jellyfin` — `resources.limits.amd.com/gpu: "1"`
  - `dispatcharr` — `resources.limits.amd.com/gpu: "1"`
- **Talos:** No CDI-specific containerd config, no DRA feature gates
- **Kubernetes:** DRA requires 1.32+ — Talos config needs `DynamicResourceAllocation` + `ResourceHealthStatus` feature gates

## Design

### Components

| Component | Action | Details |
|-----------|--------|---------|
| `amd-gpu/` app | DELETE | Old ROCm device plugin |
| `amd-gpu-dra-driver/` app | ADD | Standalone AMD DRA driver + shared ResourceClaimTemplate |
| Talos config | UPDATE | Add CDI dirs + kubelet DRA feature gates |
| Jellyfin values | UPDATE | Replace `amd.com/gpu` with DRA claims |
| Dispatcharr values | UPDATE | Same pattern |

### Architecture

```
kubernetes/apps/infrastructure/privileged/
├── amd-gpu/                         ← DELETE
└── amd-gpu-dra-driver/              ← ADD
    ├── argocd-app-config.yaml       → Helm chart: rocm/k8s-gpu-dra-driver v1.0.0
    ├── kustomization.yaml           → lists resourceclaimtemplate.yaml
    └── resourceclaimtemplate.yaml   ← one shared RCT named "amd-gpu"
```

### 1. DRA Driver ArgoCD App

Helm chart parameters:
- **Repo:** `https://rocm.github.io/k8s-gpu-dra-driver`
- **Chart:** `k8s-gpu-dra-driver`
- **Version:** `1.0.0` (or latest)
- **Values:** default (creates `DeviceClass` `gpu.amd.com` automatically)

The DRA driver deploys a DaemonSet (kubelet plugin) that:
- Discovers AMD GPUs via the in-kernel `amdgpu` driver
- Publishes `ResourceSlice` objects for each GPU
- Handles DRA allocation claims

### 2. Shared ResourceClaimTemplate

One single RCT named `amd-gpu` is deployed alongside the DRA driver via Kustomize (same pattern as cilium's extra manifests).

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: amd-gpu
spec:
  spec:
    devices:
      requests:
        - name: gpu
          deviceClassName: gpu.amd.com
          exactly: 1
```

Both Jellyfin and Dispatcharr reference this same RCT by name.

### 3. Talos Config Changes (`talos/minipc.config.yaml`)

```yaml
machine:
  files:
    - op: create
      path: /etc/cri/conf.d/20-customization.part
      content: |-
        [plugins."io.containerd.cri.v1.runtime"]
          cdi_spec_dirs = ["/var/run/cdi"]
  kubelet:
    extraConfig:
      featureGates:
        DynamicResourceAllocation: true
        ResourceHealthStatus: true
```

- `cdi_spec_dirs` enables containerd CDI support (the DRA driver writes CDI specs to `/var/run/cdi`)
- `DynamicResourceAllocation` enables the k8s DRA API
- `ResourceHealthStatus` enables resource health monitoring

### 4. Workload Changes

**Jellyfin** (`values.yaml`):
```yaml
# Remove:
#   resources:
#     limits:
#       amd.com/gpu: "1"

# Add under the controller:
controllers:
  jellyfin:
    pod:
      resourceClaims:
        - name: gpu
          resourceClaimTemplateName: amd-gpu
    containers:
      app:
        resources:
          claims:
            - name: gpu
```

**Dispatcharr** (`values.yaml`):
```yaml
controllers:
  dispatcharr:
    pod:
      resourceClaims:
        - name: gpu
          resourceClaimTemplateName: amd-gpu
    containers:
      app:
        resources:
          claims:
            - name: gpu
```

### 5. ArgoCD Dependencies

Both workload ArgoCD apps get a `dependsOn` for `amd-gpu-dra-driver` to ensure the DRA driver is deployed before workloads start.

### Migration Order

1. Update Talos config (requires node reboot) — enables CDI + DRA
2. Deploy `amd-gpu-dra-driver` app (creates DeviceClass + RCT)
3. Update Jellyfin values.yaml (switch to DRA claims)
4. Update Dispatcharr values.yaml (switch to DRA claims)
5. Delete old `amd-gpu` app (remove device plugin)
6. Verify: `kubectl get resourceslices`, check pod logs

## Rollback Plan

- Keep the old `amd-gpu/` app YAMLs in git history
- To revert: re-enable old device plugin, revert workload values, revert Talos config
- DRA and device plugin cannot coexist on the same node — migration should be done per-node

## References

- [bjw-s-labs/home-ops Intel DRA/CDI commit](https://github.com/bjw-s-labs/home-ops/commit/77eba53371055334cbaeb9953e4149206839dfd9)
- [ROCm/k8s-gpu-dra-driver](https://github.com/ROCm/k8s-gpu-dra-driver)
- [AMD GPU Operator DRA docs](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/dra/dra-driver.html)
- [Kubernetes DRA docs](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)
