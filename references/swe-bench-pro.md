# SWE-bench Pro：从新 CPU 工作区部署

用于用户要给其他人复用、安装或恢复 SWE-bench Pro 的情况。先明确：模型服务只提供模型 API；CPU 执行工作区负责官方 Agent 与 Docker 任务容器。Ray 模型工作区有地址，不等于任务执行环境已具备。

## 两个仓库各负责什么

- `vLLM-HUST/vllm-hust-benchmark` 的 `docs/SWE_BENCH_PRO.zh-CN.md` 是使用入口。`scripts/bootstrap_swe_bench_pro.py` 自动安装固定运行源码、独立客户端、V1 数据、crane 与 ARM 任务镜像，随后调用原来的 `check/prepare/verify-inputs/run`。不重新实现 Agent，不安装到模型环境，不部署模型。
- `yancanmao/npu-private-cloud` 的 `scripts/create_swe_bench_workspace.py` 复用标准 devbox 模板生成独立 `swe-bench-pro-cpu` 模板。新工作区使用自己的 PVC 和 Docker daemon，不复制旧工作区，不挂宿主机 Docker socket，保留平台的运行时隔离和存储准入。
- `config/workspaces/docker-executors.json` 解决的是已登记旧执行工作区的恢复，不能代替新使用者的创建流程，也不能据此声称新人已可部署。

## 管理员准备一次，使用者无需反复排查

1. 先核实目标集群 UID、登录身份、存储额度与现有运行任务，保存只读现场。只申请 CPU，不为验证客户端增加 NPU 或重启模型。
2. 确认 Docker runtime 镜像和固定 ARM 任务镜像在目标集群的 registry 中可拉取。使用 benchmark 的 `mirror_swe_bench_pro_image.py` 从固定上游摘要发布，不从旧工作区的镜像缓存或 Docker 数据目录提取。慢外网先下载成 OCI 制品再上传，避免把慢下载与 registry 上传连接绑在一起。
3. 上游源码、PyPI、数据文件和工具发布资产逐项实测。发布页超时不代表官方资产 API 不可达；镜像站的目录 API 被拒绝也不代表固定文件不可下载。使用明确配置与 SHA256，不随机切换未核对的镜像。
4. 为新模板配置数据源、镜像前缀和明确的 HTTP/HTTPS 策略。`SWE_BENCH_PRO_DATASET_BASE`、`SWE_BENCH_PRO_IMAGE_MIRROR`、`SWE_BENCH_PRO_IMAGE_REGISTRY_INSECURE` 由管理员提供，使用者只填模型 API、模型名和自己的运行目录。
5. 通过平台私有 profile 的 `swe_bench_pro` 声明纳入 `sync_platform.py`，按仓库文档重放。同一功能按两平台实际状态对账，不能把一边的镜像缓存当另一边已交付。

zot 默认不接收 Docker Schema 2 清单。固定摘要镜像返回 415 时，先核对媒体类型与运行版本，按官方 `http.compat: ["docker2s2"]` 配置处理，不能擅自转换清单又声称摘要相同。使用平台仓库的 `configure_registry_compat.py`：验证集群、备份配置、用实际运行二进制验证、只改兼容字段，再检查匿名读取与拒绝匿名推送。慢链路超过 registry 请求时限时在 registry 节点本机上传已校验 OCI 制品，避免反复重传大层。

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
