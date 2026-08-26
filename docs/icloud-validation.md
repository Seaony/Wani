# Wani iCloud 验收记录

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

继续验收需要先在 Xcode 中选择支持 iCloud capability 的开发团队，并确保该团队能够为上述 Bundle ID 和 CloudKit 容器签发 provisioning profile。完成后重新执行签名 Release 构建，再进行双实例实测。

同日最新一次使用 `-allowProvisioningUpdates` 执行签名 Release 构建时，先前的 Apple 账户登录错误已经消失；Xcode 仍明确报告当前 Personal Team「蜃 王」不支持 iCloud capability，并且缺少 `com.seaony.wani.Wani` 的 Mac App Development provisioning profile。继续验收前需要改选支持 iCloud capability 的开发团队。
