# 共享案例与排查索引

**在 GitHub 上阅读：直接打开 [案例库 index.md](https://github.com/yancanmao/npu-private-cloud/blob/main/docs/knowledge-base/index.md) 或 [案例库目录](https://github.com/yancanmao/npu-private-cloud/tree/main/docs/knowledge-base)。**

当前这个 `references/knowledge-base.md` 是说明文件，不是文件夹。
案例正文已提交在平台仓库的 `docs/knowledge-base/`，不在 ops skill 仓库中。

**本地安装后使用：**安装器才会创建 `references/knowledge-base/` 目录链接；
其中的 `index.md` 和 `tools/search.py` 来自同一个共享知识包。只克隆 ops skill 不会生成这个目录，
GitHub 也不会显示本地生成的链接。安装步骤见 [README](../README.md#安装共享案例库排查功能必需)。

故障诊断先检索症状/错误/组件，再检查候选案例的证据等级、原因状态与恢复状态。
用户 skill 与 ops 读取同一份正文。

```bash
python3 "<SKILL_DIR>/references/knowledge-base/tools/search.py" 'Connecting' --component Longhorn --audience ops
python3 "<SKILL_DIR>/references/knowledge-base/tools/search.py" --show storage-image-preparation --audience ops
```

替换实际 skill 目录后再执行。检索是本地只读，不会执行案例里的诊断命令或任何平台变更。
匹配案例不确认当前根因；历史记录、用户转述和代码契约的证据强度不同。没有取得当前事件，
不能把旧恢复参数套到线上，特别是历史双副本/薄置备不能覆盖现在的单份数据目标。

链接缺失时可在平台 checkout 直接读 `docs/knowledge-base/index.md`，或读
[权威索引](https://github.com/yancanmao/npu-private-cloud/blob/main/docs/knowledge-base/index.md)。
用平台仓库 `scripts/install_knowledge_base.py --skill-dir <实际用户skill目录> --skill-dir <实际ops目录>`
预览，再加 `--apply` 安装。它校验内容摘要并将已有 skill 指向同一包，不修改线上或获取凭据。
来源不可访问就明确说明，不能用记忆伪称完成检索。报告仍遵循 diagnostic-report，交付遵循原验收。
