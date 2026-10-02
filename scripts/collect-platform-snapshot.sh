#!/usr/bin/env bash
# 只读采集 NPU 私有云现场。输出可能包含内部地址和工作区名称，不要提交到 Git。
set -uo pipefail

OUT=${1:-"npc-snapshot-$(date +%Y%m%d-%H%M%S)"}
mkdir -p "$OUT"

capture() {
  local name=$1
  shift
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
    "$@"
  } >"$OUT/$name.txt" 2>&1 || printf '%s\n' "$?" >"$OUT/$name.exit-code"
}

capture_shell() {
  local name=$1 command=$2
  {
    printf '$ %s\n\n' "$command"
    bash -o pipefail -c "$command"
  } >"$OUT/$name.txt" 2>&1 || printf '%s\n' "$?" >"$OUT/$name.exit-code"
}

{
  printf 'collected_at=%s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
  printf 'host=%s\n' "$(hostname)"
  printf 'kernel=%s\n' "$(uname -srmo)"
  printf 'warning=contains internal addresses and workspace names; do not commit\n'
} >"$OUT/metadata.txt"

capture services systemctl --no-pager --full status coder nginx kubelet containerd
capture listeners ss -ltnp
capture disk df -hT
capture memory free -h
capture kubernetes-version kubectl version
capture kubernetes-ready kubectl get --raw '/readyz?verbose'
capture nodes kubectl get nodes -o wide
capture pods kubectl get pods -A -o wide
capture services-kubernetes kubectl get svc -A -o wide
capture events kubectl get events -A --sort-by=.metadata.creationTimestamp
capture workloads kubectl get deploy,statefulset,daemonset -A -o wide
capture coder-storage kubectl get pvc,pv -A -o wide
capture longhorn kubectl get volumes.longhorn.io,replicas.longhorn.io -n longhorn-system -o wide
capture volcano kubectl get queue,podgroup -A -o wide
capture ray kubectl get rayclusters -A -o wide
capture npu-hardware npu-smi info

if command -v npu >/dev/null 2>&1; then capture npu-ledger npu -v; fi
if command -v npc-reconcile >/dev/null 2>&1; then capture reconcile npc-reconcile; fi

capture_shell recent-core-logs \
  "journalctl --no-pager --since '-2 hours' -u coder -u nginx -u kubelet -u containerd | tail -n 2000"
capture_shell failing-pods \
  "kubectl get pods -A --no-headers | awk '\$4 != \"Running\" && \$4 != \"Completed\" {print}'"
capture_shell coder-agent-logs \
  "kubectl get pods -A -o json | python3 -c 'import json,sys; data=json.load(sys.stdin); [print(p[\"metadata\"][\"namespace\"], p[\"metadata\"][\"name\"]) for p in data.get(\"items\",[]) if any(c.get(\"name\")==\"coder-agent\" for c in p.get(\"spec\",{}).get(\"containers\",[]))]' | while read -r ns pod; do kubectl logs -n \"\$ns\" \"\$pod\" -c coder-agent --tail=200 2>/dev/null | sed \"s#^#[\$ns/\$pod] #\"; done"

printf 'snapshot=%s\n' "$OUT"
printf 'files=%s\n' "$(find "$OUT" -type f | wc -l | tr -d ' ')"
printf '%s\n' 'This snapshot can contain internal addresses and workspace names. Do not commit it.'
