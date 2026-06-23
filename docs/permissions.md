# Permissions

MouseBridge 使用两项系统权限。

## 输入监控

用于识别鼠标滚轮、侧键和键盘快捷键录制事件。应用不保存键入文本。

## 辅助功能

用于过滤滚轮事件、发送用户配置的快捷键，并在需要时合成滚动事件。

## 开机自启

使用 SMAppService（Service Management App Service，系统登录项服务）。默认关闭，只有用户打开“登录时启动 MouseBridge”后才注册登录项。
