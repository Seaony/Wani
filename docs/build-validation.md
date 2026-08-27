# Wani 后台构建与测试记录

## 2026-08-27：iOS 小组件

- iOS Simulator 上的 `WaniTests` 6 项测试全部通过；新增覆盖 Widget 快照的 Today、当日完成数、连续 Upcoming 日期，以及完成与推迟深链接格式。
- Debug 构建成功，Wani 主应用与内嵌的 `WaniWidgets.appex` 均编译并通过嵌入二进制校验。
- iOS Simulator 静态分析成功，没有产生源码诊断。
- iOS Simulator Release 构建成功并通过产品校验。
- 快照由主应用一次映射后原子写入 App Group；Upcoming 在一次任务分组后生成 6 个连续日期，周统计也只遍历一次任务快照，没有按日期重复扫描全部任务。

## 2026-08-27：iOS App

- iOS Simulator 上的 `WaniTests` 4 项规则与存储隔离测试全部通过，覆盖智能列表计数、Today 与 Anytime 重叠语义、连续 Upcoming 日期、项目汇总以及 XCTest 内存存储选择。
- iOS Simulator 无签名静态分析成功，没有产生源码诊断。
- iOS Simulator 无签名 Release 构建成功并通过产品校验。
- Debug 验收数据只在显式传入 `--seed-preview-data` 时写入；普通 Debug 与 Release 启动不会生成示例任务。

## 2026-08-27：macOS 桌面小组件

- `WaniTests` 的 52 项单元测试全部通过；新增覆盖小组件的 Today、Upcoming、项目进度、月历标记与深链接分类。
- 无签名静态分析成功，没有产生诊断。
- 无签名 Release 构建成功，Wani 主应用与内嵌的 `WaniWidgets.appex` 均编译并通过嵌入二进制校验。
- 使用临时 Debug entitlement 移除 iCloud、保留 App Sandbox 与 App Group 后，Apple Development 签名构建成功；系统小组件图库与实际桌面加载已通过 Computer Use 验收，未运行 UI 自动化。
- 正式工程的 iCloud 签名仍受当前 Personal Team 限制，详见 [iCloud 验收记录](icloud-validation.md)。

## 2026-08-26

本节仅记录后台构建、静态分析和单元测试；没有运行 UI 自动化，前台手动检查另见界面验收记录。

- `WaniTests` 的 50 项单元测试全部通过；其中磁盘重开测试覆盖完整任务字段、层级关系及完成、记录、删除状态，任务复制测试覆盖独立标识、内容、清单、层级、日期、状态和重复规则，所选任务下方新建测试覆盖列表、项目、标题、日期分组和紧邻排序的继承，重复规则测试覆盖多星期生成、周间隔、月末与多日期规则、闰日年份、指定结束日、发生次数上限和下一组日期预览，批量日期元数据测试覆盖提醒时间和截止日期的统一设置与清除，日期微调测试覆盖无日期基线、过去日期钳制、日周偏移及提醒时刻保持，键盘选择测试覆盖单选移动、越过多选区、边界收拢和连续扩展。
- `build-for-testing` 成功，Wani、WaniTests 和 WaniUITests 均编译通过；当前 9 项 UI 测试包含 Items 菜单、Repeat 面板及 `Esc` 取消、任务复制、直接排期快捷键以及批量时间、提醒、截止日期和标签流程，但没有执行，不能视为运行通过。
- 无签名静态分析成功，没有产生诊断。
- 无签名 Release 构建成功。

签名版本和 CloudKit 双实例同步仍需在支持 iCloud capability 的开发团队下验收，当前限制见 [iCloud 验收记录](icloud-validation.md)。需要占用前台窗口的交互与视觉检查仍以 [界面验收记录](ui-validation.md) 为准。
