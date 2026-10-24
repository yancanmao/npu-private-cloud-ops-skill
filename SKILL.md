---
name: npu-private-cloud-ops
description: 部署、巡检和排查 yancanmao/npu-private-cloud 管理的 Ascend NPU 私有云，包括 Coder、Kubernetes、Volcano、Longhorn、KubeRay、Ray Dashboard、Prometheus、Grafana、zot 镜像仓库和 nginx 网关。适用于平台安装、工作区或 Ray 集群异常、资源占用不一致、端口网络故障、存储故障、升级和安全清理；不用于修改训练或推理应用本身。
---

# NPU 私有云运维

恢复服务并留下可复核证据。不要靠重启掩盖问题。所有结论必须来自命令输出、事件、日志或
[`npu-private-cloud`](https://github.com/yancanmao/npu-private-cloud) 的声明式配置。

## 选择操作模式

1. **只读巡检或故障定位**：可直接执行。先运行
   本 Skill 附带的 [`scripts/collect-platform-snapshot.sh`](scripts/collect-platform-snapshot.sh)，再缩小故障层；该脚本不在平台实现仓库的 `scripts/` 中。
2. **部署或升级**：先读 [references/deployment.md](references/deployment.md)，按平台仓库的
   编号脚本执行；每步运行 verify，再运行只读验收。
3. **停止、重启、迁移或清理**：先列出精确对象、当前使用者、持久化数据、影响和回滚；
   得到明确授权后再操作。停止工作区与删除工作区不是一回事。
4. **紧急恢复**：先保存现场，优先回滚单个配置；不得先删 Pod、卷、工作区或重置集群。

需要平台拓扑和权威信息位置时读 [references/topology-and-sources.md](references/topology-and-sources.md)。
需要按症状定位时读 [references/incident-response.md](references/incident-response.md)。
涉及多集群同步、闲置回收或工作区指标接入时，读 [references/deployment.md](references/deployment.md) 的专项验收；一个集群通过不能代替其他集群发布。
涉及 Coder、RayCluster 或 Ray Dashboard 时读 [references/coder-and-ray.md](references/coder-and-ray.md)。
涉及 SWE-bench Pro 安装、其他人复用或新 CPU 执行工作区时，先读 [references/swe-bench-pro.md](references/swe-bench-pro.md)，区分模型服务、旧工作区恢复与新用户部署验收。
涉及变更、停止和清理时读 [references/change-and-recovery.md](references/change-and-recovery.md)。

## 固定诊断顺序

按用户请求经过的路径从外到内检查，发现第一个失败层后停止扩散操作：

1. 公网入口和 nginx TLS；
2. Coder 服务与 Coder 账本；
3. Kubernetes API、节点和命名空间对象；
4. Volcano 调度、资源请求和 Pending 事件；
5. Longhorn 卷、PersistentVolumeClaim 和挂载；
6. Ascend Device Plugin、调度器账本、`npu-smi` 进程三方对账；
7. KubeRay、Ray 节点、Ray Job 和应用端口。

页面、Coder 账本、Kubernetes 实际对象和硬件进程可能互相分叉。不要因为页面报错就直接
重启底层组件。

## 权威判据

- 工作区是否真正占资源：以 Kubernetes Deployment、Pod、PersistentVolumeClaim 和
  NPU 进程为准，不能只看 Coder 页面。
- 工作区是否应该占资源：以 Coder workspace 的 latest build 为准。两者用
  `npc-reconcile` 对账。
- NPU 是否空闲：同时核对 Kubernetes allocatable/request、Pod 分配和 `npu-smi` 进程；
  Device Plugin 看不见宿主机绕过 Kubernetes 启动的进程。
- Ray 是否健康：RayCluster 状态、Pod Ready、`ray status` 和 Dashboard API 四项一致。
- 网关是否健康：本机后端、私网入口和公网入口逐跳验证；HTTP 200 不能替代证书、
  WebSocket 和只读限制验证。
- 存储是否安全：先确认卷类型、使用 Pod、Longhorn 副本健康和备份，再讨论删除。

## 每次汇报必须包含

- 用户看到的症状和开始时间；
- 第一个失败层及其原始证据；
- 根因的完整因果链；
- 实际执行的变更、影响和回滚位置；
- 修复后的端到端验证；
- 尚未验证的边界；
- 停止或清理后的资源清单。

## 安全边界

- 公共仓库禁止出现真实地址、域名、主机名、人名和凭据；使用占位符。
- 不输出私钥、会话令牌、密码或 Kubernetes Secret 内容。只记录存放位置、权限和证书元数据。
- 不运行 `docker system prune`，不使用通配符删除 Kubernetes 对象，不凭进程名批量杀进程。
- 删除 PersistentVolumeClaim、Coder workspace、Longhorn volume、镜像 tag 或用户前，必须
  再次确认；这些动作可能不可恢复。
- 只读面板必须继续拒绝非 GET/HEAD 请求。网关修改后先 `nginx -t`，再 reload，最后验证
  Coder 和全部面板。
- 平台固定入口端口与 Kubernetes NodePort 必须分段，禁止重叠。

## 验收

**每次平台更新均检查两平台的全部前端与可视化路径**，包括 Coder、Longhorn、全部 Grafana、
模板表单、已有工作区和自有 CPU 工作区的终端/SSH/停启持久化。组件正常、HTTP 200、
模板激活均不能单独证明交付。读 [完整验收与存储边界](references/storage-and-acceptance.md)，
按实现仓库的必测清单与账本门禁执行；未通过项如实保留，不能省略入口换取通过。

普通修复至少运行平台仓库中的相关组件测试；跨层变更运行：

```bash
./tests/run.sh
bash ./scripts/10_tools.sh verify
```

只有明确授权且具备临时资源时才运行 `./tests/run.sh --full` 或其他会创建资源的测试组。
测试摘要显示零失败仍不够：检查输出中是否夹有 traceback、timeout、skip 或 warning。
