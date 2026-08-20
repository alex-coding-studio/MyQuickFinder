<p align="center">
  <img src="assets/icon/readme-hero-zh.png" width="720" alt="MyQuickFinder">
</p>

# MyQuickFinder

[English](README.md) · [中文](README.zh-Hans.md)

常驻 macOS 菜单栏的快速目录跳转工具。全局快捷键唤起面板，从收藏入口或 `~`
定位到目标目录，一键在访达打开、在终端打开或复制路径。

键盘优先，一次交互两三秒结束。macOS 14+，不开沙盒，中英双语。

## 安装

到 [Releases](https://github.com/alex-coding-studio/MyQuickFinder/releases)
下载已公证的 `.zip`，解压后把 `MyQuickFinder.app` 拖进 `/Applications`。

应用不开沙盒，但受保护目录仍由 macOS 的 TCC 把关：第一次进这类目录时系统会
弹窗询问。被拒绝的目录，面板会明说是没权限，而不是装作它是空的。

## 从源码构建

需要 Xcode 16+（Swift 6）与
[XcodeGen](https://github.com/yonaskolb/XcodeGen)。Xcode 工程由 `project.yml`
生成、不入库，所以先生成：

```bash
xcodegen generate
```

```bash
./scripts/lint.sh
```

```bash
swift test --package-path MyQuickFinderKit
```

```bash
xcodebuild -project MyQuickFinder.xcodeproj -scheme MyQuickFinder \
  -destination 'platform=macOS' build
```

`./scripts/lint.sh` 需要 `PATH` 上有 `swiftformat` 和 `swiftlint`
（`brew install swiftformat swiftlint`）。除此之外工具链所需的一切——格式化与
静态检查配置、Git hooks、`scripts/` 下的各项检查——都在本仓库里，不指向仓库外。

### 签名

`project.yml` 不再写死签名身份，所以直接构建就是 ad-hoc 签名
（`CODE_SIGN_IDENTITY = -`），不需要 Apple 开发者账号。构建和跑测试用这个默认
值正合适，但有一点要知道：ad-hoc 签名是二进制的哈希，每次编译都变，系统会把
每次构建当成另一个程序——已授予的文件访问权限会被清掉，已注册的登录项也会失效。

要让这些跨构建保留，就用自己的身份：

```bash
xcodebuild -project MyQuickFinder.xcodeproj -scheme MyQuickFinder \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)" \
  DEVELOPMENT_TEAM=YOURTEAMID \
  build
```

想显式强制 ad-hoc（CI 就是这么跑的），传
`CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM=""`。

## 发布

`./scripts/release.sh`（English）与 `./scripts/release-cn.sh`（中文）是同一个
交互式向导的两份：引导装 Developer ID 证书与公证凭据（每步当场验证），然后完成
签名 → 公证 → 钉票据 → 打包 → 建 release。证书与凭据只需配一次，之后重跑会自动
跳过那几步。

`./scripts/release-auto.sh` 跑完同一套流水线，全程不提问：

```
预检（main、干净树、tag 空闲、测试/lint）
  → Developer ID 签名构建（Release，build 号取 commit 数）
  → 公证（notarytool submit --wait，交给 Apple 扫描）
  → 钉票 + 验证（stapler、spctl -t install）
  → 重新打包（zip 含票据）
  → 打 tag + 推送 + gh release create
```

任一环节失败当场退出并说明原因。产物在
`.release-artifacts/MyQuickFinder-<版本>.zip`，完整日志在
`.release-build/release-auto.log`。

**一次性配置**：

1. Developer ID Application 证书装进钥匙串（Xcode → Settings → Accounts →
   Manage Certificates → `+` → Developer ID Application）。
2. 公证凭据存成 keychain profile。用 App Store Connect API 密钥：
   ```bash
   xcrun notarytool store-credentials "MyQuickFinder" \
     --key ~/.appstoreconnect/AuthKey_<KEY_ID>.p8 \
     --key-id <KEY_ID> --issuer <ISSUER_UUID> \
     --keychain ~/Library/Keychains/login.keychain-db
   ```
   `ISSUER_UUID` 在 App Store Connect → Users and Access → Integrations →
   API Keys 里。注意：**API 密钥凭据不要带 `--team-id`**，notarytool 会误判为
   混用凭据类型而报错。

   用 Apple ID + app-specific password 也可以：
   ```bash
   xcrun notarytool store-credentials "MyQuickFinder" \
     --apple-id <你的AppleID> --team-id <你的TeamID>
   ```

**发新版本**：

```bash
# 1. 升 project.yml 的 MARKETING_VERSION（tag 已存在会拒绝发布）
# 2. 全自动发布（profile 名与 team id 都可覆盖）
NOTARY_PROFILE=MyQuickFinder ./scripts/release-auto.sh
```

`TEAM_ID` 不导出时从 Developer ID 证书名里取。

## 持续集成

`.github/workflows/ci.yml` 在每次 push 与 pull request 上跑 lint、包测试与
scheme 测试。`.github/workflows/release.yml` 在推 `v*` tag 时构建、签名、公证
并建 GitHub release，证书与公证凭据走仓库 Secrets。

## License

[MIT](LICENSE) © 2026 Cunqi Xiao
