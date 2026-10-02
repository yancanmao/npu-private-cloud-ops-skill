# 平台拓扑与信息源

## 请求路径

```text
浏览器
  -> 公网高位端口
  -> nginx TLS 网关
  -> Coder / Grafana / Volcano / Longhorn / Prometheus / zot
  -> Kubernetes API
  -> Volcano 调度
  -> Pod + Longhorn 卷 + Ascend 设备
```

Ray 工作区多一层：

```text
Coder Terraform build
  -> RayCluster 自定义资源
  -> KubeRay Operator
  -> Ray head Pod + Ray worker Pods
  -> Coder Agent（运行在 head Pod）
  -> coder_app 反向代理
  -> Ray Dashboard 127.0.0.1:8265
```

## 组件、位置和权威配置

| 组件 | 运行位置 | 权威配置或检查入口 |
|---|---|---|
| Coder | 宿主机 systemd 服务，默认回环地址 3080 | 平台仓库 `scripts/07_coder.sh`、`systemctl status coder`、`/healthz` |
| Coder 模板 | Coder 数据目录中的渲染目录 | 平台仓库 `templates/`、`scripts/07_coder.sh render/push` |
| nginx 网关 | 宿主机 systemd 服务 | `scripts/09_gateway.sh`、`manifests/gateway/`、`nginx -T` |
| Kubernetes | 宿主机控制面与 kubelet | `scripts/02_kubernetes.sh`、`kubectl get --raw /readyz?verbose` |
| Volcano | `volcano-system` | `scripts/04_volcano.sh`、PodGroup、Queue 和 Pod events |
| Ascend Device Plugin / ClusterD / Exporter | `mindx-dl` | `scripts/03_ascend.sh`、节点 allocatable、Pod devices、`npu-smi` |
| Longhorn | `longhorn-system` | `scripts/05_longhorn.sh`、PVC、Longhorn Volume/Replica |
| KubeRay | Operator 通常在 `default`，RayCluster 在工作区命名空间 | RayCluster、Operator 日志、Ray Pod |
| Prometheus / Grafana | `monitoring` | `scripts/08_monitoring.sh`、Prometheus targets 和查询 |
| zot registry | 宿主机 systemd/container | `scripts/11_registry.sh`、`manifests/registry/` |
| 自动对账 | 宿主机 systemd timer | `npc-reconcile`、`/var/lib/npc/reconcile.state` |

具体版本见平台仓库 `docs/stack.md`；入口和认证边界见 `docs/services.md`；占位符见
`docs/placeholders.md`。仓库文档与现场不一致时，先把差异作为故障证据，不要静默照现场覆盖仓库。

## 两个集群的入口关系

现有架构允许两个独立 Kubernetes 集群共用一个域名。集群二的公网入口可经过集群一 nginx
转发，因此：

- 集群二本身健康但集群一网关故障时，集群二公网也会不可达；
- 必须分别检查浏览器到集群一、集群一到集群二、集群二本地后端；
- 超过少量集群时应改成独立子域名和通配符证书，避免单点依赖。

固定平台入口和 Kubernetes NodePort 必须分段。推荐平台入口 `32001–32005`，NodePort
`32011–32100`，避免 Coder SSH Service 抢占平台入口。

## 数据持久性

- Coder stop：目标是停止计算资源，正常情况下保留工作区和持久化卷。
- Coder delete：可能连同 PersistentVolumeClaim 和数据一起删除。
- 旧模板可能使用 hostPath，新模板使用 PersistentVolumeClaim；执行动作前必须读实际 Pod
  volume 和 Terraform state，不能只凭模板版本推断。
- RayCluster 被销毁不等于用户目录被删除；用户目录是否保留由实际挂载决定。
