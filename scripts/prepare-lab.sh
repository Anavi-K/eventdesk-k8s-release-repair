#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
for c in docker curl python3 git; do command -v "$c" >/dev/null || { echo "Install prerequisite: $c"; exit 1; }; done
docker info >/dev/null || { echo 'Start Docker Desktop/Engine first.'; exit 1; }
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in darwin|linux) ;; *) echo 'Use macOS or Linux (WSL2 Linux supported).'; exit 1;; esac
case "$(uname -m)" in arm64|aarch64) ARCH=arm64;; x86_64|amd64) ARCH=amd64;; *) echo 'Unsupported CPU'; exit 1;; esac
DA=$(docker info --format '{{.Architecture}}')
case "$DA" in aarch64|arm64) PLATFORM=linux/arm64;; x86_64|amd64) PLATFORM=linux/amd64;; *) echo 'Unsupported Docker CPU'; exit 1;; esac
python3 - "$(docker info --format '{{.NCPU}} {{.MemTotal}}')" <<'PY'
import sys, shutil
cpu,mem=map(int,sys.argv[1].split())
assert cpu>=2 and mem>=4*1024**3, 'Allocate Docker >=2 CPUs and >=4 GiB RAM'
assert shutil.disk_usage('.').free>=8*1024**3, 'Need >=8 GiB free disk'
PY
mkdir -p .lab/bin
fetch() { curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 20 --max-time 300 "$1" -o "$2"; }
verify() {
 python3 - "$1" "$2" <<'PY'
import hashlib,sys
p,check=sys.argv[1:]
expected=open(check).read().split()[0]
assert len(expected)==64 and hashlib.sha256(open(p,'rb').read()).hexdigest()==expected, 'Download checksum mismatch: '+p
PY
}
fetch "https://github.com/kubernetes-sigs/kind/releases/download/v0.27.0/kind-$OS-$ARCH" .lab/bin/kind
fetch "https://github.com/kubernetes-sigs/kind/releases/download/v0.27.0/kind-$OS-$ARCH.sha256sum" .lab/bin/kind.sha256
verify .lab/bin/kind .lab/bin/kind.sha256
fetch "https://dl.k8s.io/release/v1.32.2/bin/$OS/$ARCH/kubectl" .lab/bin/kubectl
fetch "https://dl.k8s.io/release/v1.32.2/bin/$OS/$ARCH/kubectl.sha256" .lab/bin/kubectl.sha256
verify .lab/bin/kubectl .lab/bin/kubectl.sha256
chmod +x .lab/bin/kind .lab/bin/kubectl
export PATH="$ROOT/.lab/bin:$PATH"
if [ -f .lab/cluster-name ]; then NAME=$(<.lab/cluster-name); else
 NAME="eventdesk-$(python3 -c 'import uuid; print(uuid.uuid4().hex[:8])')"
 echo "$NAME" > .lab/cluster-name
fi
if kind get clusters 2>/dev/null | grep -qx "$NAME"; then
 echo "Cluster $NAME already exists. No resources reapplied; repaired work preserved."
 echo 'Source .lab/env.sh. For intentional reset follow SETUP.md.'
 exit 1
fi
PORT=${LAB_PORT:-8088}
python3 - "$PORT" <<'PY'
import socket,sys
p=int(sys.argv[1]); assert 1024<=p<=65535
s=socket.socket(); s.bind(('127.0.0.1',p)); s.close()
PY
export KUBECONFIG="$ROOT/.lab/kubeconfig"
python3 - "$ROOT" "$PORT" "$NAME" <<'PY'
import shlex,sys
r,p,n=sys.argv[1:]
with open('.lab/env.sh','w') as f:
 f.write('export KUBECONFIG='+shlex.quote(r+'/.lab/kubeconfig')+'\n')
 f.write('export PATH='+shlex.quote(r+'/.lab/bin')+':"$PATH"\n')
 f.write('export LAB_PORT='+p+'\nexport LAB_CLUSTER='+n+'\n')
PY
cat > .lab/kind.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: $PORT
        listenAddress: "127.0.0.1"
        protocol: TCP
EOF
retry() { local n=0; until "$@"; do n=$((n+1)); [ "$n" -lt 4 ] || return 1; sleep 3; done; }
retry docker pull --platform "$PLATFORM" kindest/node:v1.32.2
kind create cluster --name "$NAME" --image kindest/node:v1.32.2 --config .lab/kind.yaml --kubeconfig "$KUBECONFIG" --wait 180s
retry docker pull --platform "$PLATFORM" python:3.12.9-alpine3.21
retry docker pull --platform "$PLATFORM" traefik:v3.3.4
docker build --platform "$PLATFORM" -t eventdesk:lab .
kind load docker-image --name "$NAME" eventdesk:lab traefik:v3.3.4
kubectl apply -f scripts/controller.yaml
kubectl -n eventdesk-edge rollout status deployment/traefik --timeout=180s
kubectl create namespace eventdesk
kubectl apply -f k8s/
kubectl -n eventdesk run client --image=eventdesk:lab --image-pull-policy=Never --command -- python -c 'import time; time.sleep(604800)'
kubectl -n eventdesk wait --for=condition=Ready pod/client --timeout=120s
# Wait for app process, NOT readiness: starter readiness is deliberately broken.
for i in $(seq 1 60); do
 if kubectl -n eventdesk exec deploy/eventdesk -- python -c 'import urllib.request; assert urllib.request.urlopen("http://localhost:8000/live").status==200' 2>/dev/null; then break; fi
 [ "$i" -lt 60 ] || exit 1
 sleep 2
done
# Routing to unhealthy starter can give 503 or 404 while controller syncs;
# a separate unmatched host must reliably give Traefik's 404.
CODE=$(curl -sS -o .lab/controller-response.txt -w '%{http_code}' --max-time 10 -H 'Host: controller-check.invalid' "http://127.0.0.1:$PORT/")
[ "$CODE" = 404 ] || { echo "Controller verification failed: $CODE"; exit 1; }
printf 'Preparation complete. Source .lab/env.sh. Controller reachable on 127.0.0.1:%s (HTTP %s).\n' "$PORT" "$CODE"
kubectl -n eventdesk get pods
