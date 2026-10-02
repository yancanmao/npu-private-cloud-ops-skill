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
