# AX Inject Demo 2.0 — 破解态成品

复刻 AX Pro v1.4.3 取证发现的防御结构，**打开即为破解态成品**（封签 / 令牌 / 镜像 / 到期四项全绿，功能解锁），不含任何加固模式。

## 四个页面

| 页面 | 内容 |
|---|---|
| 对抗台 | 启动自动注入 → 四项全绿 + 破解成功横幅；可"复位（看原始态）"再"注入 hook"逐步拆解 |
| 功能台 | 高级自动化任务（打开网页 / 剪贴板 / 通知 / 触感反馈，受许可门禁）+ 免费功能 + 快捷指令 |
| 日志台 | 全功能审计日志（校验 / 任务 / 门禁 / 计数） |
| 关于 | App / 设备信息、封签与令牌公钥指纹、取证对应说明 |

## 取证对应

- `__axseal`（AXSLV001 + ECDSA P-256 封签）→ `ecdsaVerify(SEAL 公钥, "AXSLV001-seal")`
- ECDSA 授权令牌（与封签共用验签入口 = 单点）→ `ecdsaVerify(TOK 公钥, "AX-LICENSE-TOKEN")`
- load-command 扫描 / `_dyld` 镜像监控 → `imageScan()`
- `_expirationTime` 到期判定 → `currentTime() < TRIAL_END`

破解机制：`HookTable` 等价于 GOT 重绑定（fishhook / MSHookFunction）——H1 单点验签钩一钩双废、H2 拨表回试用期、拆盾使镜像白名单失明。破解者走全能签（企业证书）分发自包含注入包，免越狱可安装。

## 构建

GitHub Actions macOS 云编译（`.github/workflows/build_tipa.yml`）产出 `AXInjectDemo.tipa`，全能签导入签名后安装。

> 仅供自有软件防御性验证使用。
