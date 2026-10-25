# 故障定位手册

诊断和交付按 [问题定位报告规范](diagnostic-report.md) 输出；原因未确认时保留假设，
不能把第一处报错直接称为根因。

## 先保存现场

运行：

```bash
bash scripts/collect-platform-snapshot.sh
```

这里的相对路径以本 Skill 目录为根，不是平台实现仓库。

证据包包含系统、Kubernetes、Coder、调度、存储、NPU、Ray 和最近事件。它可能含工作区
名称和内部地址，只能私下传给维护者，不得提交到 Git。

## 页面打不开

按三跳检查：

1. 后端本地地址是否应答；
2. nginx 本机 TLS 入口是否应答且证书主机名正确；
3. 公网入口是否应答。

如果后置集群打不开，先确认前置集群的远程代理和后置集群固定入口都在监听。公网失败可能
来自前置代理、证书、NAT 或后端，不能只测试浏览器入口。

## Coder 页面正常，工作区一直 Connecting

检查顺序：

1. Pod 是否 Running/Ready；
2. Coder Agent 容器或 init 日志；
3. Pod 内 `CODER_AGENT_URL` 和域名解析；
4. Pod 内访问 Coder `/healthz`；
5. nginx 是否在 Pod 解析到的私网地址和回连端口监听；
6. TLS 证书是否包含 `CODER_AGENT_URL` 的主机名。

若 Pod 尚未分配节点，先诊断调度，不要把 Connecting 当成 Agent 网络故障。
Coder 显示 Running 可能仅表示构建成功；回收审计中的 KEEP 也不证明 Pod 已运行或实际占卡。

典型根因：公网入口位于前置网关，但 Pod 把同一域名解析到本机私网地址，而本机没有监听
公网端口。表现为 Coder Agent 周期性下载失败，工作区业务容器和 Ray 本身却正常。

## Coder 显示 Stopped/Failed，但卡仍被占用

这是账本与实际对象分叉。运行：

```bash
npc-reconcile
npu -v
kubectl get deploy,pod,pvc -n coder-workspaces -o wide
```

先检查容器内进程和卷，再按精确对象处理。Coder stop 只会删除 Terraform state 认识的对象；
不在 state 中的孤儿 Deployment 可能继续运行。不得以 Coder 页面状态代替现场检查。

## 工作区 Pending

先读 Pod events，按事件分类：

- Insufficient `huawei.com/Ascend910`：卡数或节点选择不满足；同时检查宿主机绕过 Kubernetes
  的 NPU 进程。
- PodGroup / queue：Volcano 配额、gang 或队列问题。
- unbound PersistentVolumeClaim：Longhorn、StorageClass、节点空间或副本问题。
- ImagePullBackOff：镜像地址、containerd 命名空间、registry 认证或网络问题。
- node affinity：模板机器选项与节点 `alias` 标签不一致。

CPU-only 也要检查实际 PodGroup queue；若仍进入 NPU 队列，队列的已分配资源与排队预留可能
挡住不申请卡的新任务。先核对该版本调度器算法和当前账本，不能只按空闲卡数解释。
临时调整某个 PodGroup 不等于修好模板；保留 Pod/PodGroup UID 门禁，并单独记录重建后复发风险。

## Grafana 显示空闲卡为负数或与现场不符

负数说明“资源容量、调度器账本、实际使用”至少两项不一致，不是正常空闲值。依次核对：

1. 节点 `status.capacity/allocatable`；
2. 所有 Pod 的 NPU requests/limits；
3. `npu-smi` 进程及其 cgroup/容器；
4. Prometheus 原始时间序列和标签；
5. Grafana 查询表达式。

常见原因包括孤儿 Deployment、宿主机直接启动的 NPU 进程、重复计数、过期时间序列或
错误节点标签。先证明是哪一项，再修查询或资源。

## RayCluster 或 Ray Dashboard 异常

读 [coder-and-ray.md](coder-and-ray.md)。Ray Dashboard 不出现不等于 Ray 没启动；
Dashboard 页面正常也不等于所有 Ray 节点健康。

## 存储异常

不要先重启 Longhorn 或删除卷。依次检查 PVC phase、Volume robustness、Replica 分布、
节点磁盘可调度空间、使用该卷的 Pod、挂载事件和 instance-manager。Longhorn 单卷性能边界
见平台仓库 `docs/storage.md`，慢不一定是故障。

## 修复后验收

重走用户原始路径，并运行平台仓库中相关 `tests/t*.sh`。网络或网关修复必须同时验证正常
访问、WebSocket/Agent 回连以及只读面板的非 GET 请求返回 403。
