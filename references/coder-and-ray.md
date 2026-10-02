# Coder、KubeRay 与 Ray 运维

## 对象关系

Coder workspace 的 Terraform build 创建 RayCluster；KubeRay Operator 再创建 head 和 worker
Pod。Coder Agent 运行在 head Pod 中，`coder_app` 把 Coder 页面上的 Ray Dashboard 链接代理到
head Pod 内的 `127.0.0.1:8265`。

因此必须区分四个状态：

1. Coder workspace build 状态；
2. RayCluster 自定义资源状态；
3. Ray Pod 和 Ray 节点状态；
4. Coder Agent 与 `coder_app` 健康状态。

## 标准只读检查

```bash
coder list --all
kubectl get rayclusters -A
kubectl get pods -A -l ray.io/cluster -o wide
kubectl describe raycluster -n <namespace> <name>
kubectl logs -n <namespace> <head-pod> -c coder-agent --tail=200
kubectl exec -n <namespace> <head-pod> -c ray-head -- ray status
kubectl exec -n <namespace> <head-pod> -c ray-head -- \
  curl -fsS http://127.0.0.1:8265/api/version
```

Coder CLI 必须使用持有会话的系统用户。用 root 直接运行可能返回空列表而不是权限错误；按照
平台仓库 `tests/t06_coder.sh` 的 `CODER_RUN_AS`、`CODER_HOME` 和 `CODER_URL` 固定身份。

## Ray Dashboard 链接缺失

依次判断：

1. 模板是否声明 `coder_app`，URL 是否为 `http://127.0.0.1:8265`；
2. Dashboard API 在 head Pod 内是否返回 200；
3. Coder Agent 日志是否出现 `workspace app healthy`；
4. 如果没有，检查 Agent 是否成功下载并连接 Coder；
5. 检查 `CODER_AGENT_URL`、Pod DNS 解析、私网监听和 TLS 主机名。

只有 Coder Agent 连上后，Coder 页面才会展示应用链接。Ray Dashboard API 正常但链接缺失时，
不要重启 Ray；先修 Agent 回连路径。

## Ray 作业日志

实验、引擎和控制器应使用 Ray Job，并使用可读的 submission id。取证至少保存：

```bash
ray job list --address=http://127.0.0.1:8265
ray job logs --address=http://127.0.0.1:8265 <submission-id>
find /tmp/ray/session_latest/logs -maxdepth 1 -name 'job-driver-*.log'
```

停止 Devbox 前先把应用结果目录和 Ray job-driver 日志拉走并生成校验清单。正在写入的日志不能
当作最终归档；先停止实验作业，确认日志静止，再归档，最后停止 workspace。

## 停止 Ray Devbox

1. 列出 Ray Jobs，确认没有需要继续运行的实验；
2. 保存结果、Ray 日志和作业状态；
3. 通过 Coder stop 停止 workspace；
4. 等待页面显示 Stopped；
5. 确认 RayCluster 和所有 Ray Pod 消失；
6. 确认 `npu-smi` 中不再有该工作区进程；
7. 确认持久化目录或 PersistentVolumeClaim 仍存在。

不要把“页面显示 Stopped”当作完成。Coder state 已停止、Deployment 仍运行的孤儿必须由
`npc-reconcile` 和现场资源清单发现。
