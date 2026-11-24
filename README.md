# EventDesk campus events API

EventDesk must serve campus events through Kubernetes. Repair its release without changing application code. Prerequisites: macOS, Linux or WSL2; running Docker Desktop/Engine 28+ (API 1.48+), Bash, Git, curl, Python 3 and internet access. Allocate Docker at least 2 CPUs and 4 GiB RAM; have 8 GiB free disk. A GitHub account is needed for your fork only. Complete [self-service preparation](SETUP.md), including fork/clone, bootstrap and `source .lab/env.sh`, before repairs. Work only in this isolated lab. Source `.lab/env.sh` in each shell.

Submit one PDF file under 2,000,000 bytes, with exactly three screenshots total: one labelled Task 1, one Task 2, one Task 3. Include your name/learner ID, actual fork URL and starter commit, concise diagnosis/fix/results, and brief YAML excerpts or captions as needed. No extra uploads. Keep token values and Secret data out of screenshots. Never use real credentials. Use only the required evidence below; full command transcripts are not needed.

## Task 1 — Restore readiness

Diagnose API Pod `0/1` using Pod status/events and probe settings. Edit only `readinessProbe.httpGet.path` in `k8s/deployment.yaml` to use the valid endpoint `/ready` on port 8000. Keep working liveness `/live`, probe timings, image, labels and app unchanged. Apply Deployment; verify rollout and API Pod `1/1 Ready`. Explain readiness versus liveness. Capture one labelled screenshot showing readiness failure diagnostic and repaired Ready status (brief captions may supply omitted diagnosis/config).

## Task 2 — Restore traffic

With API Ready, demonstrate failed Service DNS request using `bash scripts/service-request.sh`. Edit only `spec.ports[0].targetPort` in `k8s/service.yaml` to match API port 8000; keep Service port 80 and selector unchanged. Apply Service. Inspect but do not edit supplied correct `k8s/ingress.yaml`: class `traefik`, host `eventdesk.local`, Prefix `/api`, backend `eventdesk:80`. Verify HTTP 200 and events JSON through both Service DNS and actual host-based Ingress:
```bash
bash scripts/service-request.sh
curl -i --max-time 10 -H 'Host: eventdesk.local' "http://127.0.0.1:$LAB_PORT/api/events"
```
Capture one labelled screenshot showing failed Service request and successful Service DNS + Ingress requests; explain targetPort versus Service port and correct Ingress route. No ingress fault is planted.
 
## Task 3 — Complete campus release and recover capacity

Edit only `data.APP_ENV` and `data.BANNER` in supplied `k8s/configmap.yaml` to `campus` and `Campus Events`. Preserve Deployment `envFrom.configMapRef`; add `env` entry `DEMO_TOKEN` using `valueFrom.secretKeyRef` to Secret `eventdesk-secret`, key `DEMO_TOKEN` (commented skeleton supplied). Create that Secret using fake value `practice-only` via documented SETUP command; do not hardcode token in Deployment, ConfigMap or image. Apply changed files and restart rollout if needed for updated environment.

Set Deployment `spec.replicas: 3` manually in YAML and apply. Wait for three Ready API Pods; record names/UIDs, delete exactly one API Pod, then verify replacement has different UID and Deployment desired/ready counts both return to 3. Repeat both Task 2 HTTP checks after recovery: expect HTTP 200, events, `APP_ENV=campus`, `BANNER=Campus Events`, `DEMO_TOKEN_PRESENT=true` only (never token value). No claim of zero downtime required. Capture one labelled screenshot showing old/replacement identity, recovered three Ready API Pods/Deployment and final Service DNS + Ingress release responses. Concise captions and YAML excerpts may show config/Secret references without values. Do not modify controller, client, app, Dockerfile or other fields; no autoscaler or extra infrastructure needed.
