# AMD GPU DRA/CDI Migration Implementation Plan

> **For agentic workers:** implement this plan task-by-task — dispatch a fresh subagent per task with the native `task` tool (recommended for quality), or use the superpowers-executing-plans skill to work through it inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate from the old ROCm k8s-device-plugin (extended resource `amd.com/gpu`) to the standalone AMD DRA Driver (`ROCm/k8s-gpu-dra-driver`) using Kubernetes Dynamic Resource Allocation (DRA) with CDI.

**Architecture:** Replace the device plugin ArgoCD app with a new `amd-gpu-dra-driver` app that deploys the standalone DRA driver Helm chart plus one shared `ResourceClaimTemplate` named `amd-gpu` via Kustomize. Update Talos config for CDI/DRA support. Update Jellyfin and Dispatcharr workloads to use DRA `resourceClaims` instead of extended resource limits.

**Tech Stack:** ArgoCD (GitOps), Talos Linux, Helm (bjw-s common library chart), ROCm/k8s-gpu-dra-driver, Kubernetes DRA

**Spec:** `docs/reasonix/specs/2026-07-19-amd-gpu-dra-cdi-design.md`

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| MODIFY | `talos/minipc.config.yaml` | Add containerd CDI config + kubelet DRA feature gates |
| CREATE | `kubernetes/apps/infrastructure/privileged/amd-gpu-dra-driver/argocd-app-config.yaml` | ArgoCD app pointing to DRA driver Helm chart |
| CREATE | `kubernetes/apps/infrastructure/privileged/amd-gpu-dra-driver/kustomization.yaml` | Kustomize listing the RCT YAML |
| CREATE | `kubernetes/apps/infrastructure/privileged/amd-gpu-dra-driver/resourceclaimtemplate.yaml` | Shared ResourceClaimTemplate `amd-gpu` for `gpu.amd.com` device class |
| MODIFY | `kubernetes/apps/selfhosted/media/jellyfin/argocd-app-config.yaml` | Add `dependsOn` for `amd-gpu-dra-driver` |
| MODIFY | `kubernetes/apps/selfhosted/media/jellyfin/values.yaml` | Replace `amd.com/gpu` with DRA resourceClaims |
| MODIFY | `kubernetes/apps/selfhosted/media/dispatcharr/argocd-app-config.yaml` | Add `dependsOn` for `amd-gpu-dra-driver` |
| MODIFY | `kubernetes/apps/selfhosted/media/dispatcharr/values.yaml` | Replace `amd.com/gpu` with DRA resourceClaims |
| DELETE | `kubernetes/apps/infrastructure/privileged/amd-gpu/` | Remove old ROCm device plugin app |

---

### Task 1: Update Talos Config for CDI/DRA

**Files:**
- Modify: `talos/minipc.config.yaml`

- [ ] **Step 1: Add containerd CDI config and kubelet DRA feature gates**

Edit `talos/minipc.config.yaml`. The existing file ends with the `Layer2VIPConfig` resource. Add the `machine.files` and `machine.kubelet.extraConfig.featureGates` sections.

Add under the existing `machine:` section (after line 61, before the `---` separator on line 62):

```yaml
  files:
    - op: create
      path: /etc/cri/conf.d/20-customization.part
      content: |-
        [plugins."io.containerd.cri.v1.runtime"]
          cdi_spec_dirs = ["/var/run/cdi"]
```

Modify the existing `kubelet` block (lines 49-53):

```yaml
  kubelet:
    extraConfig:
      featureGates:
        DynamicResourceAllocation: true
        ResourceHealthStatus: true
    nodeIP:
      validSubnets:
        - 192.168.1.0/24
        - fd7f:eaef:3150:10::/60
```

- [ ] **Step 2: Verify the config is valid YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('talos/minipc.config.yaml'))"`
Expected: no output (YAML parses cleanly)

- [ ] **Step 3: Commit**

```bash
git add talos/minipc.config.yaml
git commit -m "feat(talos): enable CDI and DRA feature gates for AMD GPU"
```

---

### Task 2: Create AMD GPU DRA Driver ArgoCD App

**Files:**
- Create: `kubernetes/apps/infrastructure/privileged/amd-gpu-dra-driver/argocd-app-config.yaml`
- Create: `kubernetes/apps/infrastructure/privileged/amd-gpu-dra-driver/kustomization.yaml`
- Create: `kubernetes/apps/infrastructure/privileged/amd-gpu-dra-driver/resourceclaimtemplate.yaml`

- [ ] **Step 1: Create the `argocd-app-config.yaml`**

```yaml
helm:
  chart: k8s-gpu-dra-driver
  releaseName: amd-gpu-dra-driver
  version: 1.0.0
  repo: https://rocm.github.io/k8s-gpu-dra-driver
```

- [ ] **Step 2: Create the `kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./resourceclaimtemplate.yaml
```

- [ ] **Step 3: Create the shared `resourceclaimtemplate.yaml`**

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

- [ ] **Step 4: Verify directory structure**

Run: `ls -la kubernetes/apps/infrastructure/privileged/amd-gpu-dra-driver/`
Expected: 3 files listed

- [ ] **Step 5: Commit**

```bash
git add kubernetes/apps/infrastructure/privileged/amd-gpu-dra-driver/
git commit -m "feat(gpu): add AMD GPU DRA driver ArgoCD app with shared ResourceClaimTemplate"
```

---

### Task 3: Update Jellyfin to Use DRA Claims

**Files:**
- Modify: `kubernetes/apps/selfhosted/media/jellyfin/values.yaml`
- Modify: `kubernetes/apps/selfhosted/media/jellyfin/argocd-app-config.yaml`

- [ ] **Step 1: Update `values.yaml`** — replace `amd.com/gpu` with DRA resourceClaims

In `values.yaml`, replace the `controllers.jellyfin.containers.app.resources` block (lines 35-40):

Old:
```yaml
        resources:
          requests:
            cpu: 100m
          limits:
            memory: 4Gi
            amd.com/gpu: "1"
```

New:
```yaml
        resources:
          requests:
            cpu: 100m
          limits:
            memory: 4Gi
```

And add `pod.resourceClaims` under the `controllers.jellyfin` section (after line 5):

```yaml
  jellyfin:
    pod:
      resourceClaims:
        - name: gpu
          resourceClaimTemplateName: amd-gpu
```

And add `resources.claims` under the container:

```yaml
        resources:
          claims:
            - name: gpu
          requests:
            cpu: 100m
          limits:
            memory: 4Gi
```

- [ ] **Step 2: Update `argocd-app-config.yaml`** — add `dependsOn`

Replace or append the file to include:

```yaml
helm:
  chart: ...
dependsOn:
  - name: amd-gpu-dra-driver
    namespace: default
```

(Check the exact structure of the existing file first.)

- [ ] **Step 3: Verify both files parse correctly**

Run: `python3 -c "import yaml; yaml.safe_load(open('kubernetes/apps/selfhosted/media/jellyfin/values.yaml')); yaml.safe_load(open('kubernetes/apps/selfhosted/media/jellyfin/argocd-app-config.yaml'))"`
Expected: no output

- [ ] **Step 4: Commit**

```bash
git add kubernetes/apps/selfhosted/media/jellyfin/
git commit -m "feat(jellyfin): migrate to DRA GPU claims"
```

---

### Task 4: Update Dispatcharr to Use DRA Claims

**Files:**
- Modify: `kubernetes/apps/selfhosted/media/dispatcharr/values.yaml`
- Modify: `kubernetes/apps/selfhosted/media/dispatcharr/argocd-app-config.yaml`

- [ ] **Step 1: Update `values.yaml`** — same pattern as Jellyfin

Replace the `controllers.dispatcharr.containers.app.resources` block (lines 38-44):

Old:
```yaml
        resources:
          requests:
            cpu: 100m
            memory: 500Mi
          limits:
            memory: 3Gi
            amd.com/gpu: "1"
```

New:
```yaml
        resources:
          claims:
            - name: gpu
          requests:
            cpu: 100m
            memory: 500Mi
          limits:
            memory: 3Gi
```

And add `pod.resourceClaims` under `controllers.dispatcharr`:

```yaml
  dispatcharr:
    pod:
      resourceClaims:
        - name: gpu
          resourceClaimTemplateName: amd-gpu
```

- [ ] **Step 2: Update `argocd-app-config.yaml`** — add `dependsOn`

Same pattern as Jellyfin: add `dependsOn: [{name: amd-gpu-dra-driver, namespace: default}]`

- [ ] **Step 3: Verify both files parse correctly**

Same check as Task 3.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/apps/selfhosted/media/dispatcharr/
git commit -m "feat(dispatcharr): migrate to DRA GPU claims"
```

---

### Task 5: Remove Old AMD GPU Device Plugin App

**Files:**
- Delete: `kubernetes/apps/infrastructure/privileged/amd-gpu/`

- [ ] **Step 1: Delete the directory**

```bash
git rm -r kubernetes/apps/infrastructure/privileged/amd-gpu/
```

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(gpu): remove old ROCm k8s-device-plugin app"
```

---

### Task 6: Final Verification and Cluster Apply

**Files:** None (operational)

- [ ] **Step 1: Push all commits**

```bash
git push
```

- [ ] **Step 2: Apply Talos config update** (requires node reboot)

```bash
talosctl apply-config -f talos/minipc.config.yaml -n 192.168.1.22
talosctl reboot -n 192.168.1.22
```

- [ ] **Step 3: Verify DRA driver is running**

```bash
kubectl get pods -n kube-amd-gpu -l app.kubernetes.io/name=k8s-gpu-dra-driver
```
Expected: pod in Running state

- [ ] **Step 4: Verify DeviceClass exists**

```bash
kubectl get deviceclass gpu.amd.com
```
Expected: DeviceClass exists

- [ ] **Step 5: Verify ResourceSlices**

```bash
kubectl get resourceslices
```
Expected: at least one ResourceSlice from driver `gpu.amd.com`

- [ ] **Step 6: Verify ResourceClaimTemplate exists**

```bash
kubectl get resourceclaimtemplate amd-gpu
```
Expected: RCT exists

- [ ] **Step 7: Verify GPU workloads are running with GPU access**

```bash
kubectl get pods -n media -l app.kubernetes.io/name=jellyfin
kubectl get pods -n media -l app.kubernetes.io/name=dispatcharr
```
Expected: pods Running, no GPU errors in logs
