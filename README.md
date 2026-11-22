# 清读

帮助老人看清、读懂并照做纸质医疗须知的 iPhone / iPad App。CrossPointX 2026 · Apple Human Care 赛道。

## 目录

| 路径 | 内容 |
|---|---|
| `PLAN.md` | **实施计划**：功能清单、架构、里程碑、分工、演示脚本。先读这个。 |
| `demo/` | 网页版演示原型，双击 `demo/index.html` 用浏览器打开（说明见 `demo/README.txt`） |
| `ios/Qingdu.swiftpm` | SwiftUI App 工程：Mac 上用 Xcode、iPad 上用 Swift Playgrounds 打开 |
| `ios/iPad运行说明.md` | 给组员看的 iPad 运行步骤（也打包在 `qingdu-ipad.zip` 里） |
| `qingdu-demo-iphone.mp4` | 56 秒的 iPhone 演示录屏（模拟器），可发给组员，也可作答辩备份 |
| `qingdu-ipad.zip` | 发给 iPad 组员的压缩包：工程 + 运行说明 |
| `ios/Qingdu.swiftpm/Resources/reader.html` | App 内的阅读器和打标规则（`RULES`）；可以直接用浏览器打开调试 |
| `黑客松赛题介绍.docx`、`CrossPointX_2026_Judging_Rubrics.docx` | 赛题与评分标准 |
| `功能实现技术方案.pdf` | 组员最初的功能方案（已整理进 PLAN.md） |

### App 里的文件

| 文件 | 做什么 |
|---|---|
| `QingduApp.swift` | App 入口和页面导航 |
| `StartView.swift` | 开始页：扫描、从相册选、看示例 |
| `DocumentScanner.swift` | 系统文档扫描器（VisionKit） |
| `TextRecognizer.swift` | 中文文字识别（Vision） |
| `ParagraphBuilder.swift` | 把识别出的一行行文字拼回段落 |
| `ReaderWebView.swift` | 网页阅读器和 Swift 之间的桥 |
| `ReaderScreen.swift` | 阅读页：识别进度、边缘光晕、底部滑块、原文 / 办事清单切换 |
| `Todo.swift` | 待办事项：示例须知的预设要点，以及从识别结果里按规则抽取、换算提醒时刻 |
| `ChecklistView.swift` | 办事清单：检查时间、勾选进度、设置提醒、演示模式 |
| `Reminders.swift` | 本地通知 |
| `Speaker.swift` | 普通话朗读（静音键开着也能出声） |
| `AboutView.swift` | 关于页：真实运行 / 模拟 / 还没做 / 隐私，答辩时可以直接给评委看 |
| `Resources/reader.html` | 阅读器：打标规则、分层排版、动画 |

## 怎么运行

### 在 Mac 上（Xcode）

1. 打开 Xcode → File → Open，选择 `ios/Qingdu.swiftpm`。
2. **用模拟器**：第一次要在 Xcode → Settings → Components 里下载 iOS 模拟器，然后在顶部选一台 iPhone 或 iPad 模拟器，按 ⌘R。模拟器没有相机，请用"从相册选择"或"看一份示例"。
3. **装到 iPhone / iPad**：
   - 用数据线连接设备；设备上打开 设置 → 隐私与安全性 → 开发者模式（会重启）。
   - Xcode 里点左侧的 Qingdu → Signing & Capabilities → Team，选你的 Apple ID（免费账号即可）。
   - 顶部选中这台设备，按 ⌘R。第一次装完要在设备上打开 设置 → 通用 → VPN 与设备管理，信任开发者。
   - 免费账号装的 App **7 天后失效**，到期前重新按一次 ⌘R 即可。

### 在 iPad 上（Swift Playgrounds）

把 `qingdu-ipad.zip` 发给 iPad 组员，按 `ios/iPad运行说明.md` 操作即可。工程有更新时，重新打包再发一次（打包时去掉 `.swiftpm` 隐藏文件夹，并把 `Package.swift` 里的 `teamIdentifier` 清空）。

### 只改阅读器和规则（Windows 也可以）

用浏览器打开 `ios/Qingdu.swiftpm/Resources/reader.html`，会显示示例须知。底部调试栏可以拖滑块，也可以点"测试一段文字"粘贴任意须知，看规则标得对不对。规则在文件里的 `RULES`，改完刷新即可。

## 当前进度

- [x] 网页版演示原型
- [x] M0 环境准备：工程已创建，Xcode 编译通过（模拟器版、真机版）。**待验证**：在组员 iPad 的 Swift Playgrounds 里能否运行
- [x] M1 阅读器嵌入
- [x] M2 扫描与识别：规则打标和段落拼接已在 Mac 上用 Vision 测过。**待验证**：真机扫描纸质须知
- [x] M3 清单与提醒：提醒时刻换算已在 Mac 上测过。**待验证**：设备上收到通知
- [x] M4 分享与朗读：**待验证**：设备上朗读、分享到微信
- [ ] M5 打磨与演示：已完成 iPad 左右并排、关于页、默认检查时间；待做：演示彩排、备份录屏

### 这一版请在设备上试

1. **看一份示例**：屏幕边缘出现彩色光晕，文字上扫过一道彩光，顶部提示"找到 6 项禁止事项"，6 个禁止词依次亮红。
2. **拖底部滑块**：依次是放大、换黑体、一句一行（次要句变小变淡，关键句变大）、标出重点（关键句变成浅红卡片）。每跨一层手机会轻震一下。两侧的小 A、大 A 可以一层一层跳。
3. **扫描纸质须知**（只能在真机上）：找一张真实的须知扫一下，看段落和禁止词识别得对不对。
4. **从相册选择**：选一张须知照片。
5. **iPad**：字号会比手机上大一些。
6. **办事清单**：在阅读页顶部切到「办事清单」，改检查时间，看每条下面的提醒时刻是否跟着变；勾选几条，看进度。点每行右边的放大镜，会跳回原文并闪一下对应的句子。
7. **提醒**：打开「演示模式」，点按钮，允许通知后等 10 秒，应该依次弹出 3 条禁止事项（停留在 App 里或锁屏都可以）。关掉演示模式再点一次，会按真实时间设置。
8. **朗读**：点右上角的喇叭。原文页会逐句朗读并高亮正在读的句子（跳过问候、免责等次要句）；清单页按顺序读每一条。再点一次停止。试一下手机开着静音键时也能出声。
9. **发给家人**：清单页底部点「发给家人」，选微信，看生成的那段话是否通顺。
10. **iPad**：原文在左、清单在右，不用切换；点清单里的放大镜，左边原文会滚到对应句子。
11. **关于页**：开始页右上角的 ⓘ。

有问题请截图，并记下是哪台设备、哪一步。
