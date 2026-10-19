# 部署与升级

平台实现仓库是 [`yancanmao/npu-private-cloud`](https://github.com/yancanmao/npu-private-cloud)。
本 Skill 只规定操作方法，不复制安装脚本。部署前先读该仓库的 `CONVENTIONS.md`、
`docs/setup.md`、`docs/stack.md` 和 `scripts/README.md`。

## 从零部署顺序

按平台仓库编号执行，不跳步：

| 步骤 | 脚本 | 产物 |
|---|---|---|
| 0 | `00_preflight.sh` | 硬件、内核、磁盘、网络前置条件 |
| 1 | `01_containerd.sh` | containerd 和数据根 |
| 2 | `02_kubernetes.sh` | Kubernetes 控制面、节点、CNI |
| 3 | `03_ascend.sh` | Ascend Device Plugin、ClusterD、Exporter |
| 4 | `04_volcano.sh` | Volcano 调度器、Queue、PodGroup |
| 5 | `05_longhorn.sh` | Longhorn、StorageClass、空间守卫 |
| 6 | `06_tune_requests.sh` | 后台组件资源请求校准 |
| 7 | `07_coder.sh` | Coder、模板和工作区命名空间 |
| 8 | `08_monitoring.sh` | Prometheus、Grafana 和面板 |
| 9 | `09_gateway.sh` | TLS 网关和只读面板 |
| 10 | `10_tools.sh` | `npu`、`reflavor`、`npc-reconcile` |
| 11 | `11_registry.sh` | zot 镜像仓库 |
| 12 | `12_resource_recovery.sh` | 定时闲置停止、凭据、持久化审计 |
| 13 | `13_rdma.sh` | 经核实节点上的 RDMA device plugin |

每步先执行 install，再执行脚本提供的 verify。不要把 `scripts/install.sh` 当成“跑完就一定正确”；
最终以测试和用户路径为准。

## 部署前必须确定

- 节点硬件、NPU 型号、驱动和架构；
- Kubernetes 节点名与稳定的 `alias` 标签；
- containerd 数据根和 Longhorn 数据路径的实际剩余空间；
- 内网地址、公网 NAT、开放 TCP/UDP 端口和域名；
- 固定平台入口端口、Kubernetes NodePort 范围，两者不得重叠；
- 镜像来源、共享模型目录和证书签发方式；
- Coder 运行用户、数据目录和备份位置。

公共仓库中全部使用占位符。真实清单放在私有密码库或受控运维文档中，不提交 Git。

## 端口分区

推荐把平台固定入口保留在 `32001–32005`，把 Kubernetes NodePort 限制在
`32011–32100`。修改 kube-apiserver 前先列出现有 Service 的所有 NodePort，证明没有端口
落在新范围之外；修改后等待 `/readyz` 恢复，并确认节点、工作区和 Agent 回连。

## 验收层级

1. 每个编号脚本自身的 verify；
2. `./tests/run.sh` 只读验收；
3. `./tests/run.sh --full` 临时资源验收，仅在得到授权后执行；
4. 真实创建一个 0 卡工作区，验证 Coder Agent、终端、持久化目录和 stop/start；
5. 有空闲 NPU 时再验证 1 卡工作区；
6. 需要 KubeRay 时创建最小 RayCluster，验证 head/worker、Dashboard 和 stop 后资源释放。

## 升级

- 先在单个 0 卡工作区验证新模板；
- Coder 模板新版本不会自动更新旧工作区，批量 update 前列出受影响工作区；
- Kubernetes、Longhorn、MindCluster 和 KubeRay 分别查官方兼容矩阵，不跨多个大版本同时升级；
- 保留上一版 manifest、镜像 tag、模板版本和数据库/数据目录备份；
- 一次只变更一个层，完成相关测试后再进入下一层。

## 多集群与资源回收验收

- “同步两个集群”包括正式模板、参数说明、Coder app 分组/按钮、模板 README、Grafana、网关、后台任务和工具，不能只补某个后台或临时入口。以同一 Git revision 配合每集群私有 profile 重放；优先完善仓库发布入口，避免把临时远程脚本当长期部署方式。
- 已有集群的统一入口为仓库 `scripts/sync_platform.py plan|apply|verify`，配置示例为 `config/clusters/sync.example.json`。先读仓库的当前验收边界：模板暂存不等于激活、激活不等于已有 workspace build 已重建；状态与剩余差异必须分别记录。
- 按仓库 `docs/platform-updates.md`、`config/platform/resource-policy.json` 和每集群私有 overlay 发布；逐集群记录源码版本、对象、凭据可用性、任务运行结果和回滚位置。不要把文档、渲染清单或单集群成功当成全量部署成功。
- 复用 `12_resource_recovery.sh`。先以 `APPLY=false` 跑真实扫描并检查审计，再在用户已授权启用停止时设为 true；核对 CronJob 的 schedule、suspend、concurrencyPolicy，以及至少一次自动定时执行成功。
- admin 豁免以 `EXEMPT_OWNERS` 和准确的 Coder owner 为准；同时查 Coder 原生 workspace TTL 和模板默认值，豁免回收任务不等于取消原生自动停止。CPU-only 是否排除、证据窗口和缺失数据处理均以当前版本策略为准。
- 审计页应有持久化卷，不能挂 Coder 凭据；检查登录后可读、未登录被拒绝、非只读请求被拒绝。不要只检查 Service 或 Deployment 存在。
- 另行检查用户实际导航：后台任务和直达 URL 正常，不代表当前工作区已有 Coder app 按钮。读取该工作区当前 build 的 apps；旧构建不能靠模板源码里有按钮来验收。优先补现有资源面板的可见入口并读回 Grafana 链接，不为增加按钮批量重建用户工作区。
- 将回收任务验收与全平台健康检查分开：记录其他 Pod、卷和工作区的异常，不靠停止用户任务或删除历史对象让测试通过。扫描没有符合条件的工作区时，明确报告“没有实际执行停止”，不制造停止样本。

## 工作区 vLLM 与 Grafana 验收

- `08_monitoring.sh vllm-discovery` 发现的是容器进程拥有的 HTTP 指标端点，并非所有 vLLM 进程。标准 `vllm serve` 的 `/metrics` 和直接调用 Python `LLM(...)` 是不同的接入路径；后者需应用自行导出。不在正在运行的他人实验里注入导出逻辑。
- 核对自动发现 timer/service、Pod UID 归属的内部 Service、Prometheus 活跃配置和 targets，再经 Grafana datasource proxy 使用真实 workspace_id 查询业务指标。区分未发现端点、已登记但 DOWN、有端点但无业务样本、查询或变量错误；只加载 dashboard 不算有数据。
- 遇到 loopback-only、HTTPS/鉴权或 `/proc` 权限不足，保留明确的未覆盖状态，不跨用户登记端口、不扩大容器权限；历史指标不能补采。实例选择和 workspace_id 筛选不构成权限隔离。
- Prometheus 支持 SIGHUP 热加载；先备份、promtool 校验并确认 ConfigMap 已同步到挂载文件，再向经确认的 Prometheus 进程发信号，并读回活跃配置。`/-/reload` 要求启用 lifecycle。不要因该接口未开启就认定必须重建 Pod。
- Grafana CPU/内存应区分 allocatable、requests、实际使用及逐节点余量；未包含 init 容器、Pod overhead 或队列预留的统计不得声称是调度器精确可用容量。

官方依据：[vLLM 在线接口](https://docs.vllm.ai/en/latest/serving/online_serving/)、[Python LLM](https://docs.vllm.ai/en/latest/serving/offline_inference/)、[Prometheus 配置热加载](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)。
