# 变更、恢复与清理

## 变更前

- 说明目标、缺失条件、拟改对象、影响、回滚方式和验收标准；
- 保存配置、对象 YAML、事件和最近日志；
- 检查工作区、Pod、进程和卷，识别正在使用的资源；
- 配置文件先复制到带时间戳的备份目录；
- 对外服务变更必须保留现有入口，使用测试端口验证后再切换。

## 网关和端口

- 固定平台入口与 Kubernetes NodePort 分离；推荐前者 `32001–32005`，后者 `32011–32100`；
- 修改 kube-apiserver NodePort 范围前，先列出现有 Service 的全部 NodePort，证明新范围覆盖它们；
- nginx 配置先写临时文件，检查非空，再 `nginx -t`，最后 reload；
- reload 后分别验证本地后端、私网入口、公网入口和 Coder Agent 回连；
- 证书只检查 subject、subjectAltName、期限和权限，永远不输出私钥。

## 工作区生命周期

| 动作 | 计算资源 | 持久化数据 | 风险 |
|---|---|---|---|
| stop | 应释放 | 正常保留 | Terraform state 分叉时可能留孤儿资源 |
| start/rebuild | 重新创建 | 取决于实际挂载 | 旧 hostPath 与 PVC 行为不同 |
| update | 可能重启 | 正常保留 | 新模板可能改变挂载和资源规格 |
| delete | 删除 | PVC 模板可能一并删除 | 不可逆，必须再次确认 |

任何动作都以实际 Deployment/Pod volume 和 Terraform plan 为准。

## 清理顺序

1. 停止上层应用请求；
2. 停止 Ray Job 或工作区；
3. 核对 Pod 和 NPU 进程消失；
4. 核对持久化数据保留；
5. 只删除明确属于本次操作的临时文件或对象；
6. 运行 `npc-reconcile` 和 `npu -v`；
7. 报告释放的卡、保留的数据及其位置。

禁止 `docker system prune`、宽泛 label selector 删除、模糊进程匹配或递归删除工作根目录。

## 回滚

- nginx：恢复单个站点备份，`nginx -t` 后 reload；
- Kubernetes 静态 Pod：恢复 manifest，等待 `/readyz`，再检查节点与工作负载；
- Coder 模板：推送上一版本并对单个 0 卡工作区验证，不直接批量 update；
- Longhorn：停止写入，先确认副本和备份，按官方恢复流程操作；
- Ray：应用配置错误优先停止单个 Ray Job；RayCluster 配置错误才重建 workspace。

回滚后仍需重跑端到端路径，不能只验证进程重新出现。
