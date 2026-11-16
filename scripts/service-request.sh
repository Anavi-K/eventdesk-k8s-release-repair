#!/usr/bin/env bash
set -euo pipefail
# Run after sourcing .lab/env.sh from this clone.
kubectl -n eventdesk exec client -- python -c 'import urllib.request; r=urllib.request.urlopen("http://eventdesk.eventdesk.svc.cluster.local/api/events", timeout=5); print("ServiceDNS HTTP",r.status); print(r.read().decode())'
