# 存储隔离与完整交付验收

适用于存储修复及每次私有云平台更新。实现与 SOP 以平台仓库的
`docs/storage.md`、`docs/platform-updates.md`、`config/platform/frontend-surfaces.json` 为准，
本 skill 不复制部署实现。真实集群身份、用户保护清单与原始证据放私有目录。

## 存储判断顺序

1. 对容器 `/root`、普通目录、`/data` 模型/上传及临时目录逐路径追踪：容器挂载 →
   宿主机路径 → 实际文件系统 → 物理设备。不能把家目录 PVC 上限当作普通目录上限。
2. 分别记文件系统可用、完整卷额度、未绑定申请、物理数据总份数、模型/上传/运行时/
   快照/日志/元数据和预留。单份是只存一次，不是备份；不能由 `df` 推导准入额度。
3. 用户拒绝重划磁盘时，先验证现有文件系统的 project quota 路线，不以空闲 LVM extent
   为原地 quota 的前提。ext4/XFS 特性和挂载要求逐节点实查，不直接卸载繁忙生产 `/data`。
4. 自有测试文件上的原地 quota 启用与容器试验，只证明机制；生产特性启用、运行时自动
   创建/回收 project ID、已有工作区迁移与容量准入分别验收。loopback 不作生产存储池。
5. A 写满时 B 要持续写入；测试跨目录累计、inode、删除仍打开文件、安装软件以及 root
   更改 project ID/继承属性。曾实测不防该绕过时，32 MiB 限额可写入 40 MiB。
   最小 ioctl 测试规则不能替代生产 RuntimeDefault；须合并既有规则并测 Ascend/RDMA。
6. 可写共享上传保留可写，在实际服务端设置边界；共享 root 身份不能凭目录名实现安全的
   每用户隔离。未知归属、保护对象、活动任务不动；用稳定 UID 识别，避免同名跨集群误操作。

## 每次更新的交付步骤

- 同一个完整 Git revision 发布到两平台，profile 只包含真实差异；先检查工作树和身份。
- 执行组件 verify 和只读健康测试，保留失败输出；历史故障与此次变更分开，不能删除对象消错。
- 运行 `audit_frontend_surfaces.py` 读取全部工作区当前 build/apps、模板、实际 dashboards、
  Prometheus 查询与 Longhorn 对象。采集退出 2 表示还缺浏览器/操作验证，不是安装失败。
- 对照 `frontend-surfaces.json` 逐平台浏览器检查：Coder 列表/表单/已有工作区/自有终端；
  Longhorn 总览/卷/节点/只读；所有 Grafana；回收审计、Volcano、Prometheus、仓库、Ray。
  新增面板 UID 或 app 时同步清单。实际显示的数据与 API 核对，不能截加载中的零值算通过。
- 浏览器留截图、观察时间；API 留当前查询与对象身份；自有 CPU canary 实测终端、SSH、
  安装软件、停启和原 PVC/PV 数据保留，结束停止并保留卷。不占他人卡或写保护对象。
- 区分 vLLM 无服务、target DOWN、无业务样本、变量/查询错误。空图不补零，不擅启模型。
- 填逐平台/逐入口/逐层的账本，每项提供 revision、事实断言、证据相对路径与 SHA256。
  运行 `verify_release_acceptance.py`；缺项、旧证据、阻断、失败、缺截图均 NOT_ACCEPTED。
  全部必测通过且现有工作区差异已列明，才能交付；模板激活不等于旧工作区已更新。

## 已知错误的预防

不要先假设工具参数通用：核对当前版本帮助，保留失败日志。镜像导出、挂载、配额与
清理须验证自有对象身份；只清理由本次创建且有记录的对象。命令成功、组件健康、页面
可打开、真实数据、用户操作分别取证；任何一层不通过，不以另一层的成功替代。

官方依据：[ext4](https://docs.kernel.org/admin-guide/ext4.html)、
[XFS](https://docs.kernel.org/admin-guide/xfs.html)、
[tune2fs](https://man7.org/linux/man-pages/man8/tune2fs.8.html)。
