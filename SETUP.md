# Local preparation

Complete preparation before starting repair work. Downloads, Docker startup and cluster creation are separate from the repair exercise. No staff action required.

Prerequisites: macOS or Linux (including WSL2), Bash, Git, curl, Python 3, internet access to GitHub, dl.k8s.io, Docker Hub; Docker Desktop/Engine 28+ installed and running (API 1.48+, needed for architecture-specific image export), at least 2 CPUs and 4 GiB RAM allocated to Docker, 8 GiB free disk. These are preflight minima, not a guarantee for every machine; leave extra disk headroom for images and the cluster. Native Windows shells are unsupported: use WSL2 with Docker integration. The script checks Docker version, CPU/RAM and free host disk before downloading tools; if a check fails, resolve it before retrying. Docker's own disk-image storage must also have room. Allow image downloads to finish. No cloud account, paid service or registry login needed. GitHub account needed only for your fork. The script downloads checksum-verified kind v0.27.0 and compatible kubectl v1.32.2 locally; no global install required. Docker daemon CPU determines image platform, including ARM Macs.

1. On GitHub, fork https://github.com/kalviumcommunity/eventdesk-k8s-release-repair into your account. Replace YOUR_GITHUB_USER below with your actual username (do not type angle brackets):
   ```bash
   git clone https://github.com/YOUR_GITHUB_USER/eventdesk-k8s-release-repair.git
   cd eventdesk-k8s-release-repair
   bash scripts/prepare-lab.sh
   source .lab/env.sh
   kubectl config current-context
   kubectl -n eventdesk get pods
   ```
2. If 8088 is busy, run `LAB_PORT=8089 bash scripts/prepare-lab.sh` instead; choose another free unprivileged port if needed. Always `source .lab/env.sh` after successful preparation, and in every new shell from this clone. Commands use this clone's isolated kubeconfig, not your usual cluster. Never switch context to another cluster.
3. Success: script prints `Preparation complete`, controller HTTP 404 for unmatched host, client `1/1 Running`, API `0/1 Running` with readiness failure. This is intentional; do not fix during preparation. Check `kubectl -n eventdesk describe pod -l app=eventdesk` for readiness HTTP 404. Liveness `/live` and valid readiness `/ready` return 200 regardless of preview config or missing demo token. Only readiness path and Service targetPort are planted faults. Preview config works; requested campus settings are deliberate release work.
4. If downloads fail, check internet/proxy and retry. If cluster already exists, script refuses to reapply anything, preserving repairs. On a partial setup, inspect error and intentionally reset only this lab when ready to discard its work:
   ```bash
   source .lab/env.sh
   kind delete cluster --name "$LAB_CLUSTER"
   bash scripts/prepare-lab.sh
   source .lab/env.sh
   ```
   Reset reapplies current local YAML, not necessarily original starter. Use a separate clean clone to reproduce untouched faults. Do not delete unrelated clusters. Keep `.lab/` untracked.

During repair use editor for allowed YAML, `kubectl apply -f <file>`, `kubectl -n eventdesk rollout status deployment/eventdesk --timeout=120s`, and `kubectl -n eventdesk rollout restart deployment/eventdesk` after environment-only ConfigMap changes. `bash scripts/service-request.sh` uses supplied Python client Pod to request actual cluster Service DNS; it is not a port-forward shortcut.

For Task 3, create fake Secret before adding its non-optional reference:
```bash
kubectl -n eventdesk create secret generic eventdesk-secret --from-literal=DEMO_TOKEN=practice-only
```
Use commented `env` skeleton in Deployment, name `eventdesk-secret`, key `DEMO_TOKEN`. Never put real credentials in this exercise. Do not capture creation command or Secret values in screenshots; use API presence boolean only. No Secret export is needed.

After updating config and references, persist `spec.replicas: 3`, apply changed YAML and wait for rollout. Record Pod names/UIDs with `kubectl -n eventdesk get pods -l app=eventdesk -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,READY:.status.containerStatuses[0].ready`. Delete exactly one recorded Pod with `kubectl -n eventdesk delete pod POD_NAME`, wait for rollout and repeat UID listing. Compare old and new UID, verify exactly three Ready API Pods and Deployment desired/ready count. Then repeat both HTTP checks from README. This checks recovery, not uninterrupted access during deletion.

Cleanup only your lab: source `.lab/env.sh`, then `kind delete cluster --name "$LAB_CLUSTER"`. No background port-forward is used.
