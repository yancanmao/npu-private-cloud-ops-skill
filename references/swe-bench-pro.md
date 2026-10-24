# SWE-bench Pro：从新 CPU 工作区部署

用于用户要给其他人复用、安装或恢复 SWE-bench Pro 的情况。先明确：模型服务只提供模型 API；CPU 执行工作区负责官方 Agent 与 Docker 任务容器。Ray 模型工作区有地址，不等于任务执行环境已具备。

## 两个仓库各负责什么

- `vLLM-HUST/vllm-hust-benchmark` 的 `docs/SWE_BENCH_PRO.zh-CN.md` 是使用入口。`scripts/bootstrap_swe_bench_pro.py` 自动安装固定运行源码、独立客户端、V1 数据、crane 与 ARM 任务镜像，随后调用原来的 `check/prepare/verify-inputs/run`。不重新实现 Agent，不安装到模型环境，不部署模型。
- `yancanmao/npu-private-cloud` 的 `scripts/create_swe_bench_workspace.py` 复用标准 devbox 模板生成独立 `swe-bench-pro-cpu` 模板。新工作区使用自己的 PVC 和 Docker daemon，不复制旧工作区，不挂宿主机 Docker socket，保留平台的运行时隔离和存储准入。
- `config/workspaces/docker-executors.json` 解决的是已登记旧执行工作区的恢复，不能代替新使用者的创建流程，也不能据此声称新人已可部署。

## 管理员准备一次，使用者无需反复排查

1. 先核实目标集群 UID、登录身份、存储额度与现有运行任务，保存只读现场。客户端验证只申请 CPU；用户明确要求把完整模型服务同步到另一平台时，按下节单独部署自有模型工作区，不再让用户寻找临时模型 API，也不重启来源模型。
2. 确认 Docker runtime 镜像和固定 ARM 任务镜像在目标集群的 registry 中可拉取。使用 benchmark 的 `mirror_swe_bench_pro_image.py` 从固定上游摘要发布，不从旧工作区的镜像缓存或 Docker 数据目录提取。慢外网先下载成 OCI 制品再上传，避免把慢下载与 registry 上传连接绑在一起。
3. 上游源码、PyPI、数据文件和工具发布资产逐项实测。发布页超时不代表官方资产 API 不可达；镜像站的目录 API 被拒绝也不代表固定文件不可下载。使用明确配置与 SHA256，不随机切换未核对的镜像。
4. 为新模板配置数据源、镜像前缀和明确的 HTTP/HTTPS 策略。`SWE_BENCH_PRO_DATASET_BASE`、`SWE_BENCH_PRO_IMAGE_MIRROR`、`SWE_BENCH_PRO_IMAGE_REGISTRY_INSECURE` 由管理员提供，使用者只填模型 API、模型名和自己的运行目录。
5. 通过平台私有 profile 的 `swe_bench_pro` 声明纳入 `sync_platform.py`，按仓库文档重放。同一功能按两平台实际状态对账，不能把一边的镜像缓存当另一边已交付。

zot 默认不接收 Docker Schema 2 清单。固定摘要镜像返回 415 时，先核对媒体类型与运行版本，按官方 `http.compat: ["docker2s2"]` 配置处理，不能擅自转换清单又声称摘要相同。使用平台仓库的 `configure_registry_compat.py`：验证集群、备份配置、用实际运行二进制验证、只改兼容字段，再检查匿名读取与拒绝匿名推送。慢链路超过 registry 请求时限时在 registry 节点本机上传已校验 OCI 制品，避免反复重传大层。

## 用户明确要求完整模型服务跨平台同步时

先把 SOP 和实现 push 到 `npu-private-cloud`，目标控制节点 pull 同一提交后执行。目标 API 未就绪不能作为等待用户提供地址的理由；按已授权范围完成模型服务部署，资源确实不足则留下具体准入失败证据。

- 按来源实际运行进程核实镜像 digest、SDK/源码、插件与有效参数。基础镜像标签不足以复现持久卷里额外安装的运行环境，不能换小模型、短上下文或另一版引擎冒充匹配。
- 平台仓库 `swe_model_runtime.py` 导出选定运行库与启动文件，逐文件校验后到目标全新目录安装；不复制整个旧家目录、任务输入、密钥、结果或编译缓存。权重逐分片比对，目标有相同权重时只读复用。
- 大镜像先在来源本机落为完整 OCI，再通过既有授权 SSH 传到目标。`publish_model_oci.py` 校验全部 blob，在目标本机推送并读回原始索引摘要；不能把 layout 包裹索引当原镜像摘要，也不能把慢公网下载和目标上传绑在一个长请求内。
- `create_swe_model_workspace.py` 从标准 Ray 模板派生独立模型模板：CPU head、一个两卡 worker、20 GiB 新卷，保留生产隔离。只操作本次自有对象，来源服务和学生工作区不变；目标独立生成 UID、卷与地址。
- 事故增长冻结拦截新卷时，先用 `admit_storage_budget.py plan` 计算已有完整额度、全部 Pending 卷、快照/文件系统已用与逐盘余量，再应用明确的小额预算；保留冻结对象、100% 分配比例和至少 30% 物理余量，不能删冻结或缩旧卷。
- `SUBMITTED_NOT_READY` 不是模型就绪。继续验证两卡实际运行、实际包/配置、`/v1/models` 与真实模型返回，再用普通用户全新 CPU 工作区按 benchmark README 完成 Agent 与补丁提交。来源的成功结果不能顶替目标证据。

精确命令和回滚条件维护在实现仓库既有 `docs/swe-bench-pro.md`，skill 只保留决策边界；真实集群参数与结果留私有目录。不要把某次两卡空闲、路径或旧 Pod 身份写成永久资源保证。

## 验收必须从全新工作区开始

- 新 Coder workspace UUID、新 PVC UID、初始 Docker image 数量、CPU/零 NPU 请求均留证。空客户端环境通过安装入口建立；不能指向以前手工搭好的工作区、客户端或已准备输入。
- 使用公开 GitHub 安装入口获取固定 Git commit 的小型源码，记录每个下载文件 hash。不是靠操作员临时拷贝一份未入 Git 的运行器来结束验收。
- 实际安装依赖、校验 V1 parquet、固定 ARM manifest/config digest、启动独立任务容器。模型 `/v1/models` 必须包含给定服务模型；禁止拿历史地址代替当前归属和可达性验证。
- 跑一个真实官方 Agent，保留模型调用、工具执行、修改与提交结果。Docker 容器检查、`check` 的配置格式验证、`READY` 都不能冒充这个验收。
- `RUN_RECORDED` 要求这个 Agent 提交；修题正确性仍由独立官方评分判断。未提交、超时或准备失败如实保留，不能用脚本 exit=0 宣称任务通过。
- 同一运行目录不自动重提 Agent。`--resume` 只复用本入口的准备状态，失败输入另存；不得删掉失败记录、换题或扩大批次来制造成功。
- 检查新模板表单只有 CPU 选项、使用指南按钮、网页终端、实际 SSH，以及自有工作区 stop/start 后原卷和 Docker 可用。按完整前端验收检查两平台其余入口；不批量更新学生工作区。
- 交付代码、脚本、README、skill 和可复核的精简验收状态到正确仓库；真实地址、凭据、原题、补丁、轨迹和运行日志留私有目录。

用户要求“别人能部署”时，交付的是上述整条链路；恢复某个现有执行工作区只是其中一个已有能力，不能当成最终结果。
