---
name: npu-private-cloud-ops
description: 面向平台维护者，部署、巡检和排查 yancanmao/npu-private-cloud 管理的 Ascend NPU 私有云，包括 Coder、Kubernetes、Volcano、Longhorn、KubeRay、监控、镜像仓库和网关。用于平台故障、安装、发布、存储恢复和策略维护；普通用户登录、SSH、工作区使用与面板教学优先使用 coder-platform-user，不用于修改训练或推理应用本身。
---

# NPU 私有云运维

恢复服务并留下可复核证据。不要靠重启掩盖问题。所有结论必须来自命令输出、事件、日志或
[`npu-private-cloud`](https://github.com/yancanmao/npu-private-cloud) 的声明式配置。

## 先区分用户操作与平台运维

解释组件、登录、本人工作区启停、SSH、只读面板和已发布应用部署，优先使用平台仓库中的
[coder-platform-user](https://github.com/yancanmao/npu-private-cloud/tree/main/skills/coder-platform-user)。
该 skill 不需要管理员凭据。不要因 ops 工具可用就把普通用户请求升级成集群操作。
涉及集群故障、模板发布、共享存储、网关、策略或跨平台一致性时才进入下列运维流程；
先读 [用户支持与管理员接手](references/user-support-and-handoff.md)，保留用户的原始目标和当前权限边界。

## 选择操作模式

1. **只读巡检或故障定位**：可直接执行。先读已有报告，核对平台、当前身份、对象和时间，
   从相关失败路径取证；跨层或原因不明时使用
   [`scripts/collect-platform-snapshot.sh`](scripts/collect-platform-snapshot.sh) 保存现场。
   它属于本 Skill，不在平台实现仓库 `scripts/`；不能为收集现场向普通用户索要管理员凭据。
2. **部署或升级**：先读 [references/deployment.md](references/deployment.md)，按平台仓库的
   编号脚本执行；每步运行 verify，再运行只读验收。
3. **停止、重启、迁移或清理**：先列出精确对象、当前使用者、持久化数据、影响和回滚；
   得到明确授权后再操作。停止工作区与删除工作区不是一回事。
4. **紧急恢复**：先保存现场，优先回滚单个配置；不得先删 Pod、卷、工作区或重置集群。

需要平台拓扑和权威信息位置时读 [references/topology-and-sources.md](references/topology-and-sources.md)。
需要按症状定位时读 [references/incident-response.md](references/incident-response.md)。
历史事故先从 [共享案例与索引](references/knowledge-base.md) 检索，用户与 ops 共用平台仓库
的同一知识包。比较适用条件再查当前现场；历史已确认原因不等于当前根因，恢复与验收状态独立记录。
涉及多集群同步、闲置回收或工作区指标接入时，读 [references/deployment.md](references/deployment.md) 的专项验收；一个集群通过不能代替其他集群发布。
涉及 Coder、RayCluster 或 Ray Dashboard 时读 [references/coder-and-ray.md](references/coder-and-ray.md)。
涉及 SWE-bench Pro 安装、其他人复用或新 CPU 执行工作区时，先读 [references/swe-bench-pro.md](references/swe-bench-pro.md)。按其中“代用户完成”的流程发现已有能力、补齐配置和验收；平台前置条件由 ops 处理，不让使用者排查 Docker、镜像或 socket。区分模型服务、旧工作区恢复与新用户部署验收。
涉及变更、停止和清理时读 [references/change-and-recovery.md](references/change-and-recovery.md)。

## 按实际失败路径诊断

先分清构建、调度、容器、Agent、应用、指标和浏览器状态，不把所有问题强行从公网开始查。
以下是故障层索引，不是每次都必须执行的全栈清单；只读关联取证可跨层，变更限于已证实的范围：

1. 公网入口和 nginx TLS；
2. Coder 服务与 Coder 账本；
3. Kubernetes API、节点和命名空间对象；
4. Volcano 调度、资源请求和 Pending 事件；
5. Longhorn 卷、PersistentVolumeClaim 和挂载；
6. Ascend Device Plugin、调度器账本、`npu-smi` 进程三方对账；
7. KubeRay、Ray 节点、Ray Job 和应用端口。

页面、Coder 账本、Kubernetes 实际对象和硬件进程可能互相分叉。不要因为页面报错就直接
重启底层组件。第一处报错不是自动确认的根因；按报告规范保留竞争解释。

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

## 问题定位报告

每次故障定位、根因解释、修复交付和复盘，必须读
[references/diagnostic-report.md](references/diagnostic-report.md)，按其中固定结构输出报告。
先正面回答用户的问题，再给问题背景、核心结论、关键证据、因果分析、处理方案与实际操作、
验证结果与未完成项。简单问题用短版；持续排查的进展只报新增证据、结论变化和下一步，
最终报告必须独立可读。默认报告直接放在聊天；未经请求不另建文档或上传原始日志。

报告状态取决于用户目标的实际验收；根因不明就写“未确认”，不能为填满模板编造原因。
证据时间、对象身份、代码版本和结论适用范围必须可查。报告规范不扩大操作授权。

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

## 维护本 skill

修改 skill、共享知识包或安装入口时，读 [标准交付流程](references/skill-delivery.md)。
统一运行离线门禁，并独立记录真实 Agent 行为、可视化与发布状态；不能停在单元测试通过。
