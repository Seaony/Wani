# Wani iCloud 验收记录

## 2026-08-27：iOS 接入共享数据层与同一 CloudKit 容器

此前 iOS 是一个独立 App：自带一套精简 SwiftData 模型（无 Heading、无 `WaniTodo.area`、无 `canceledAt`/`reminderDate`/全部 repeat 字段），store 名 `Wani-iOS`，且 `cloudKitDatabase: .none`，与 macOS 之间不共享任何数据。

本次改为：

- 新建仓库根目录 `Shared/`，收纳 `WaniModels.swift`、`WaniTaskRules.swift`、`WaniPersistence.swift`、`WaniWidgetSnapshot.swift`，两个工程通过各自的文件夹同步组共同引用同一份文件。iOS 侧的四份副本已删除。
- iOS `Wani.entitlements` 增加 `iCloud.com.seaony.wani.Wani` 容器、CloudKit 服务与 ubiquity KV store 标识。
- iOS `WaniApp` 与 macOS 采用同一套启动规则：Debug 默认本地存储，仅 `--cloud-sync` 时启用 CloudKit；Release 启用。
- 共享模型新增 `WaniTodo.isNew`（iOS 的新待办徽标使用，macOS 不展示但必须携带，否则两端 schema 不一致）。

已完成的后台验证：

- macOS 与 iOS 两个工程的 Debug、Release 构建，以及各自的 `WaniTests`（macOS 59 项、iOS 7 项）。
- `iOS/WaniTests` 新增 `sharedDataLayer()` 契约测试，断言 iOS 使用同一 CloudKit 容器标识，且 schema 含全部 5 个实体、Heading/area/取消/提醒/重复字段可正常读写。

**尚未验证，不得视为通过**：

- 真实签名下 macOS ↔ iOS 的跨端双向同步。阻塞原因与下方 2026-08-26 记录相同（Personal Team 不支持 iCloud capability）。
- 共享 schema 新增 `isNew` 字段对既有本地 store 的迁移：本机 macOS 既有数据未做迁移实测。CloudKit 侧因为从未真正建过 schema，暂无生产环境影响。

需要注意的数据影响：

- iOS 的 store 名由 `Wani-iOS` 变为与 macOS 一致的 `Wani`。旧 store 文件不会被读取，等于 iOS 端本地数据从空开始。iOS target 建立于 2026-08-27，此前只在模拟器上用内存存储和演示数据验收过，判断无真实数据风险；若某台真机上存有需要保留的 iOS 数据，需要改回沿用 `Wani-iOS` 并依赖 SwiftData 轻量迁移。
- iOS 的 Upcoming 计数改用共享规则后，会把「只有截止日期、没有开始日期」的任务也计入。这与 iOS Upcoming 列表实际渲染的内容一致（列表本来就用共享的 `upcomingDays`），修正了此前计数与列表对不上的问题，但 iOS 上的角标数字会变。

## 2026-08-26：签名能力阻塞

工程已经配置以下 CloudKit 基础：

- App Bundle ID：`com.seaony.wani.Wani`
- 私有 CloudKit 容器：`iCloud.com.seaony.wani.Wani`
- App Sandbox、网络客户端与 CloudKit entitlement
- SwiftData 私有 CloudKit 数据库配置

后台执行签名 Release 构建时，Xcode 无法为当前 Bundle ID 创建 Mac App Development provisioning profile。明确原因是当前选择的 Personal Team 不支持 iCloud capability。

因此以下验收尚未执行，不能视为通过：

- 签名版本连接用户私有 CloudKit 数据库
- 两个独立实例之间新增、编辑、完成、删除和恢复的双向同步
- 离线修改后恢复联网的自动合并与同步

桌面小组件本身已使用临时 Debug entitlement 单独完成系统验收：该配置移除 iCloud、保留 App Sandbox 与 App Group，签名构建成功；系统图库识别全部 9 种配置，Next Up 实际加入桌面后能够读取主应用导出的 App Group 快照。此结果只证明本地小组件与 App Group 路径，不代表正式 iCloud 签名或 CloudKit 同步通过。

继续验收需要先在 Xcode 中选择支持 iCloud capability 的开发团队，并确保该团队能够为上述 Bundle ID 和 CloudKit 容器签发 provisioning profile。完成后重新执行签名 Release 构建，再进行双实例实测。

同日最新一次使用 `-allowProvisioningUpdates` 执行签名 Release 构建时，先前的 Apple 账户登录错误已经消失；Xcode 仍明确报告当前 Personal Team「蜃 王」不支持 iCloud capability，并且缺少 `com.seaony.wani.Wani` 的 Mac App Development provisioning profile。继续验收前需要改选支持 iCloud capability 的开发团队。
