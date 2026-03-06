# Solitary 开发指南

本文档旨在为后续开发者提供 Solitary 项目的详细开发指南，涵盖项目概述、技术架构、环境搭建、代码设计详解及待办事项。

## 1. 项目概述

**Solitary** 是一款专注于户外徒步安全的互助应用。它允许用户在徒步过程中查看实时位置、记录轨迹，并与周围的其他徒步者建立临时联系（如求救、路况反馈、提问）。

### 核心功能
*   **徒步地图**: 实时显示用户位置、轨迹及周围用户（模拟）。
*   **状态管理**: 开始、休息/暂停、结束徒步，记录时长和距离。
*   **SOS 求救**: 一键发送求救信号，通知周围用户。
*   **信息交互**: 包含顶部状态栏、底部操作栏和右侧工具栏的沉浸式 UI。

## 2. 技术架构

*   **框架**: Flutter (Dart)
*   **SDK 版本**: Flutter 3.10+ / Dart 3.0+
*   **关键依赖**:
    *   `amap_flutter_map`: 高德地图显示 (本地修改版)
    *   `amap_flutter_location`: 高德定位 (本地修改版)
    *   `amap_flutter_base`: 高德基础库 (本地修改版)
    *   `permission_handler`: 权限管理
    *   `provider`: 状态管理 (目前主要使用 StatefulWidget，未来可迁移)

## 3. 关键修复与环境配置 (重要)

由于 Dart 3 废弃了 `hashValues`，且高德地图官方插件尚未更新适配，本项目采取了**本地化插件修复**方案。同时，针对 iOS 模拟器在 M1/M2 芯片上的架构问题也进行了特殊配置。

### 3.1 高德插件本地化修复
我们将 `amap_flutter_map`, `amap_flutter_location`, `amap_flutter_base` 下载到了项目根目录的 `packages/` 文件夹下，并进行了以下修改：
1.  **替换 `hashValues`**: 将所有 Dart 文件中的 `hashValues(...)` 替换为 Dart 3 标准的 `Object.hash(...)`。
2.  **依赖路径指向**: 在根目录 `pubspec.yaml` 和各插件的 `pubspec.yaml` 中，将依赖路径指向本地：
    ```yaml
    dependencies:
      amap_flutter_map:
        path: ./packages/amap_flutter_map
      amap_flutter_location: ^3.0.0
      amap_flutter_base:
        path: ./packages/amap_flutter_base
    ```

### 3.2 iOS 模拟器架构配置 (M1/M2 Mac)
高德地图 SDK (`AMapFoundationKit` 等) 的二进制文件包含 `arm64` 架构但仅适用于真机，导致在 M1/M2 Mac 的 iOS 模拟器（也是 `arm64`）上运行时会产生冲突。

**解决方案**: 强制 iOS 模拟器使用 `x86_64` 架构（Rosetta 转译）。

1.  **Podfile 配置**:
    在 `ios/Podfile` 的 `post_install` 块中添加了 `EXCLUDED_ARCHS` 设置：
    ```ruby
    post_install do |installer|
      installer.pods_project.targets.each do |target|
        flutter_additional_ios_build_settings(target)
        target.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
          # 排除模拟器的 arm64 架构，强制使用 x86_64
          config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
        end
      end
    end
    ```

2.  **Xcconfig 配置**:
    在 `ios/Flutter/Debug.xcconfig` 和 `ios/Flutter/Release.xcconfig` 中添加：
    ```
    EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64
    ```

### 3.3 API Key 配置
高德地图 API Key 配置在 `lib/pages/hiking/hiking_map_page.dart` 文件中：
```dart
static const AMapApiKey amapApiKeys = AMapApiKey(
  androidKey: 'YOUR_ANDROID_KEY',
  iosKey: 'YOUR_IOS_KEY', // 已配置可用 Key
);
```

## 4. 目录结构说明

```
lib/
├── main.dart                # 应用入口，主题配置
├── main_screen.dart         # 主屏幕框架 (BottomNavigationBar)
├── models/                  # 数据模型 (User, Message 等)
├── pages/
│   ├── auth/                # 认证相关页面 (Login)
│   ├── hiking/              # 徒步核心功能模块
│   │   ├── hiking_map_page.dart    # [核心] 徒步地图页
│   │   ├── sos_button.dart         # SOS 按钮组件
│   │   ├── sos_detail_page.dart    # 求救详情页
│   │   ├── route_feedback_page.dart # 路况反馈页
│   │   ├── ask_question_page.dart   # 提问页
│   │   └── hiking_history_page.dart # 历史记录页
│   ├── messages/            # 消息模块
│   └── settings/            # 设置模块
├── providers/               # 状态管理 (AuthProvider)
├── services/                # API 服务 (ApiService)
└── widgets/                 # 通用 UI 组件
packages/                    # 本地化修复的插件包
```

## 5. 核心代码设计详解

### 5.1 徒步地图页 (`HikingMapPage`)
这是应用的核心页面，负责地图展示、定位追踪和状态流转。

*   **状态管理**:
    *   `_hikingState`: `IDLE` (未开始), `RUNNING` (进行中), `PAUSED` (休息/暂停)。
    *   `_currentLocation`: 当前经纬度。
    *   `_pathPoints`: 记录徒步轨迹点的列表。
    *   `_markers`: 地图上的标记点集合（我的位置、周围用户）。
*   **定位逻辑**:
    *   使用 `AMapFlutterLocation` 插件。
    *   监听 `onLocationChanged` 流，实时更新 `_currentLocation`。
    *   若处于 `RUNNING` 状态，将新坐标加入 `_pathPoints` 并更新 Polyline。
*   **地图交互**:
    *   使用 `AMapWidget`。
    *   `onMapCreated`: 获取 `AMapController` 用于控制镜头移动。
    *   `polylines`: 动态绘制绿色轨迹线。

### 5.2 交互 UI 组件
*   **TopInfoBar**: 顶部悬浮栏，显示 GPS 状态和徒步时长（仅在徒步中显示）。
*   **RightToolbar**: 右侧垂直工具栏，包含图层切换、定位复位、周围用户列表入口。
*   **BottomActionBar**: 底部操作区。
    *   **未开始**: 显示“开始徒步”大按钮。
    *   **进行中**: 显示“休息”、“结束”和核心的 **SOS 按钮**。

### 5.3 SOS 功能
*   **SOSButton**: 自定义组件，支持长按触发（防误触）。
*   **触发流程**:
    1.  用户点击 SOS 按钮。
    2.  `_isSOSActive` 状态置为 `true`。
    3.  显示全屏红色覆盖层 (`_buildSOSOverlay`)，模拟发送信号。
    4.  未来需接入后端接口，真实推送给周围用户。

## 6. 开发与调试

### 运行项目
1.  **启动模拟器**: 确保已启动 iOS 模拟器。
2.  **清理构建**: `flutter clean`
3.  **安装依赖**: `flutter pub get`
4.  **安装 Pods (iOS)**:
    ```bash
    cd ios
    rm -rf Pods Podfile.lock
    pod install --repo-update
    cd ..
    ```
5.  **运行**: `flutter run`

### 常见问题
*   **构建报错 `Framework not found`**: 通常是 Pod 安装问题或架构不匹配。请检查 `Podfile` 中的 `EXCLUDED_ARCHS` 设置是否生效，并尝试清理 Pods 缓存重装。
*   **安装到模拟器失败**: 命令行 `flutter run` 可能会因为架构检查严格而失败。解决方案是：
    1.  执行 `flutter build ios --simulator --debug`。
    2.  找到 `build/ios/iphonesimulator/Runner.app`。
    3.  **手动拖拽**该 app 文件到模拟器窗口中安装。
    4.  在模拟器上手动点击图标运行。

## 7. 待办事项 (TODO)

### 功能开发
- [ ] **后端接入**: 替换 Mock 数据，接入真实 API (登录、位置上传、消息推送)。
- [ ] **轨迹持久化**: 将 `_pathPoints` 保存到本地数据库 (SQLite/Isar)，防止意外退出丢失。
- [ ] **周围用户**: 实现从后端获取周围用户坐标，并在地图上渲染 Marker。
- [ ] **消息模块**: 完成消息列表和聊天页面的开发。
- [ ] **离线地图**: 集成高德离线地图功能。

### 优化
- [ ] **状态管理升级**: 随着逻辑变复杂，建议将 `HikingMapPage` 的状态抽离到 `Bloc` 或 `Provider` 中。
- [ ] **权限处理**: 完善定位权限被拒绝后的引导流程。
- [ ] **UI 适配**: 优化在不同尺寸屏幕上的布局表现。
