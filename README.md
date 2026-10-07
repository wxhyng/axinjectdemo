# AXInjectDemo —— 场景 2/场景 4 真机对抗演示（iOS，免越狱）

> 一个可以装到你 iPhone 上的演示 App：复刻 AX Pro 取证发现的防御结构（`__axseal` ECDSA 封签 / 授权令牌验签 / 镜像白名单 / 到期判定），内置"注入"按钮，让你亲眼看到**场景 2（破解成功）**与**场景 4（加固生效）**。
> 本工程已在 Linux 上生成完整源码 + Xcode 工程，需在你的 Mac 上用 Xcode 构建（本环境无 Apple SDK/签名，无法直接产出可安装 .tipa）。

---

## 一、红队情报更新（全能签 + 未越狱 = 实锤）

你提供的信息把破解画像升级为**实锤**：

- **全能签 = 企业证书签名分发**：Apple Developer Enterprise 证书重签任意 App，设备"设置→通用→VPN与设备管理→信任"即可运行，**完全不需要越狱**。
- 因此破解者几乎必然是 **"自包含注入破解包"**：把 hook dylib 内嵌进 .tipa/.ipa（改主程序 Mach-O 增加 `LC_LOAD_DYLIB`，或用 `insert_dylib` 类工具；启动时由 dyld 加载），再用企业证书整体重签 → AMFI 校验通过（证书有效），**内嵌 dylib 的构造器先于你的校验逻辑运行**，先把你的反注入/反调试/封签验签钩掉，再钩授权判定。
- 与取证证据完全吻合：你的包体干净（无注入 dylib）→ 破解发生在"别人分发的重签名包"里，而不是你手上的原版。

**对防御的推论（都体现在本演示与加固方案里）：**
1. **封签必须拦"改包"**：加 `LC_LOAD_DYLIB` 就是改动了主程序 → `__axseal` 哈希/验签应立刻失败。破解者必须先钩掉它（H1 单点）→ 所以**验签入口必须拆单点**。
2. **启动期镜像检查是第一道防线**：dylib 加载即暴露 → 镜像白名单 + load-command 扫描（你已有，保留并加固）。
3. **运营反制**：企业证书可被吊销；服务端版本黑名单 + 短期签名令牌让破解包长期失效。

---

## 二、这个 App 演示什么

| 状态 | 行为 | 对应 |
|---|---|---|
| 未加固 + 点"注入" | 封签、令牌、镜像、到期四项**全绿** → 红横幅"破解成功（场景 2）" | 破解者内嵌 dylib 启动时三连钩（H1 一钩双废 + H2 拨表 + 拆盾） |
| 加固模式 + 点"注入" | 同样的钩子**全部失效**：完整性熔断 + 服务器时间戳拒绝 → 蓝横幅"加固生效（场景 4）" | 报告 L1/L3/L4 落地效果 |

注入器用**函数指针替换**实现（HookTable 模拟 GOT/导入符号表），这正是 fishhook 重绑定 / MSHookFunction 在真机破解包中的等价机制。封签与授权令牌用**真实 EC P-256 公钥 + ECDSA DER 签名**（`SecKeyVerifySignature`，与 AX Pro 取证到的算法一致）。

---

## 三、免越狱安装（三条路线，按你的条件选一条）

**先决条件**：这台 Linux 环境无法编译 iOS 包，需要先把工程变成可安装的 `.tipa/.ipa`（有 Mac 用路线 A，没 Mac 用路线 D），再装到手机。

### 路线 A：有 Mac + Xcode（最快，免费 Apple ID 即可）
1. 解压 `AXInjectDemo.zip`，双击 `AXInjectDemo.xcodeproj`（Xcode 14+，建议 15/16）。
2. 连上 iPhone → 工程 Signing & Capabilities 里选你的 Apple ID（免费开发者）→ Team 选自己 → ⌘R 真机运行。
   - 注意：免费 Apple ID 签名 7 天失效，到期重跑一次 ⌘R 即可续。

### 路线 B：TrollStore（免越狱、签名永不过期；仅限支持的 iOS 版本）
1. 终端执行 `chmod +x make_tipa.sh && ./make_tipa.sh` 产出 `AXInjectDemo.tipa`。
2. 把 `.tipa` 发到手机（AirDrop / 网盘 / 微信文件），用 **TrollStore** 打开 → 安装。
- 兼容性：TrollStore 支持 iOS 14.0–16.6.1 及 17.0 的部分版本；**iOS 17.0.1 及以上、iOS 18 不支持**，请走路线 A 或 C。

### 路线 C：全能签 / 企业证书签名（无 Mac 也能分发，与破解者分发 AX Pro 同款渠道）
1. 先得到 `.tipa/.ipa`（路线 A 或 D 产物）。
2. 上传到全能签类服务（企业证书重签）→ 下载安装包 → 手机打开安装。
3. 首次打开若提示未受信任：设置 → 通用 → VPN与设备管理 → 信任该企业证书。

### 路线 D：没有 Mac？两种云/Windows 办法
1. **GitHub Actions 云编译（推荐）**：把整个工程文件夹 push 到 GitHub → Actions → `Build AXInjectDemo .tipa` → Run workflow → 下载产物 `AXInjectDemo.tipa`（macOS 云自动编译，无需本地 Mac）。拿到 .tipa 后走路线 B 或 C。
2. **Windows + Sideloadly/爱思助手**：把 `.tipa` 改名为 `.ipa`（内容同为 Payload/ 结构），用 Sideloadly（或爱思助手）+ 免费 Apple ID 签名安装，7 天有效需重签。

---

## 四、界面操作

1. 默认**未加固**模式：四项校验 → 封签✅ 令牌✅ 镜像✅ 到期❌（功能受限）。
2. 点 **注入 hook（模拟破解载荷）** → 看日志三连钩 + 四项全绿 → **场景 2 破解成功**。
3. 打开 **加固模式** 开关 → 再点 **注入** → 封签/镜像"熔断"、到期"拒绝" → **场景 4 加固生效**。
4. 点 **复位** 回到初始。

---

## 五、与真实 AX Pro 加固方案的对应（演示即验收清单）

| 演示项 | 真实工程落地（见加固报告 L1/L3/L4） |
|---|---|
| 完整性熔断（指针被替换即拒） | 关键校验函数自哈希 / 多路互验（A 验 B、B 验 A） |
| 独立双钥验签（封签与授权分离） | 封签弃用单一 `SecKeyVerifySignature` 入口，独立验签器 + 密钥分离 |
| 服务器时间戳拒绝拨表 | 到期判定用服务端签名时间戳，不用本地时钟 |
| 镜像白名单 | `_dyld_image_count`/`_dyld_get_image_name` 遍历 + 构建期白名单比对 + load-command 冗余自检 |

---

## 六、文件

```
AXInjectDemo/
  AXChecks.swift        校验逻辑 + 注入器（真实 ECDSA、HookTable、加固路径）
  AXInjectDemoApp.swift SwiftUI 界面（场景 2/4 对抗演示）
  Info.plist
AXInjectDemo.xcodeproj/ project.pbxproj（最小单 Target 工程）
.github/workflows/      GitHub Actions 云编译 .tipa（无 Mac 方案）
make_tipa.sh            构建 + 打包 .tipa（Mac 上执行）
README.md               本说明
key_constants.txt       构建时生成的密钥/签名常量（复现用）
```

> 仅供自有软件防御性验证；不构成对第三方软件破解的指引。
