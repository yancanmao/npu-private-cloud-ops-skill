# Skill 发布与行为验收

维护本 ops skill、普通用户 skill、共享知识包或安装工具时，使用平台仓库的
[标准交付流程](https://github.com/yancanmao/npu-private-cloud/blob/main/docs/skill-delivery.md)。
该规范与工具只有一份，ops 仓库不复制整套发布脚本或测试集。

在平台 checkout 使用已有 Python 3.11+ 环境：

```bash
python3 scripts/verify_skill_delivery.py --ops-skill-dir "<OPS_CHECKOUT>" \
  --output "<REPO_OUTSIDE_NEW_EVIDENCE_DIRECTORY>"
```

门禁检查两个 skill 的图/目录/引用、元数据必要字段、Python/shell 语法、平台全量单元测试、
两份真实源码的全新共享安装和 Connecting / No data 检索。失败、异常、源码变化不通过；
skip 单列且离线验收不完整。不登录集群，不创建工作区，不执行案例中的诊断命令。

自动结果仅为 OFFLINE_PASS / OFFLINE_INCOMPLETE / OFFLINE_FAIL。
四份真实 Agent 回答与工具轨迹、README/架构图/客户端调用、固定 revision 的 CI 和安装目标
分别验收，未执行必须写 NOT_RUN。不得把本地测试或维护者历史演示当作独立 Agent 行为通过。

这套 skill 发布规范不替代平台变更的两平台完整前端和用户路径验收。
