# Solitary - 户外徒步互助平台

这是一个基于 Flutter (前端) 和 FastAPI (后端) 开发的全栈移动应用，旨在为户外徒步爱好者提供安全保障和互助功能。

## 🌟 项目简介

Solitary 是一款专注于户外徒步安全的社交应用。核心功能包括：
- **实时徒步地图**：记录轨迹，查看周围徒步者。
- **一键求救 (SOS)**：紧急情况下向周围用户发送求救信号。
- **路况反馈**：发布和查看路线上的危险或重要信息。
- **互动问答**：向同路线的徒步者提问。
- **即时通讯**：支持好友聊天和临时会话。

## 🛠️ 技术架构

### 前端 (Flutter)
- **语言**: Dart
- **框架**: Flutter 3.x
- **状态管理**: Provider
- **网络请求**: Dio
- **地图**: flutter_map (OpenStreetMap)
- **UI风格**: Material Design 3 (以绿色为主色调)

### 后端 (Python)
- **语言**: Python 3.11+
- **框架**: FastAPI
- **数据库**: SQLite (轻量级，易于部署)
- **ORM**: SQLAlchemy
- **认证**: JWT (JSON Web Token)

## 📂 项目结构说明

```
solitary/
├── lib/                      # Flutter 前端代码
│   ├── main.dart             # 应用入口
│   ├── main_screen.dart      # 主屏幕 (底部导航栏)
│   ├── models/               # 数据模型 (User, Message 等)
│   ├── pages/                # 页面 UI
│   │   ├── auth/             # 认证相关 (登录/注册)
│   │   ├── hiking/           # 徒步核心功能 (地图/求救/历史)
│   │   ├── messages/         # 消息相关 (聊天列表/会话)
│   │   └── settings/         # 设置与个人中心
│   ├── providers/            # 状态管理 (AuthProvider 等)
│   └── services/             # 服务层 (ApiService)
├── backend/                  # Python 后端代码
│   ├── app/
│   │   ├── main.py           # 后端入口
│   │   ├── database.py       # 数据库配置
│   │   ├── models/           # 数据库模型
│   │   └── routers/          # API 路由
│   ├── requirements.txt      # Python 依赖
│   └── sql_app.db            # SQLite 数据库文件 (自动生成)
├── ios/                      # iOS 原生工程配置
├── android/                  # Android 原生工程配置
└── pubspec.yaml              # Flutter 依赖配置
```

## 🚀 快速开始

### 1. 准备环境
- **Flutter SDK**: 确保已安装并配置好环境变量 (`flutter doctor` 检查)。
- **Python**: 建议使用 Python 3.10+。
- **CocoaPods**: iOS 开发必需 (`sudo gem install cocoapods`)。

### 2. 启动后端服务
后端服务是 App 运行的基础，必须先启动。

```bash
# 进入后端目录
cd backend

# 创建并激活虚拟环境 (推荐)
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# venv\Scripts\activate   # Windows

# 安装依赖
pip install -r requirements.txt
# 或手动安装核心包: pip install fastapi uvicorn sqlalchemy python-jose[cryptography] passlib[bcrypt] python-multipart

# 启动服务
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
*注：后端默认运行在 `http://localhost:8000`，API 文档地址 `http://localhost:8000/docs`*

### 3. 启动 App

#### Web 端 (推荐测试)
```bash
# 在项目根目录
flutter run -d chrome --web-renderer html
```

#### iOS 模拟器
```bash
# 1. 启动模拟器 (如果没有打开)
open -a Simulator

# 2. 运行 App
flutter run -d <Device-UUID>
# 或直接运行 (会自动选择可用模拟器)
flutter run
```

#### Android 模拟器
```bash
# 1. 查看可用模拟器
flutter emulators

# 2. 启动模拟器
flutter emulators --launch <Emulator-ID>

# 3. 运行 App
flutter run


# 1. 启动Android模拟器（带图形界面）
/opt/homebrew/share/android-commandlinetools/emulator/emulator -avd android_emulator

# 2. 运行Flutter应用
cd 
flutter run -d emulator-5554

```

```bash
# 清除flutter run
$ pkill -f "flutter run" 2>/dev/null; sleep 2
```



## 🧪 测试账号

为了方便测试，你可以使用以下预设账号登录（如果没有，请在登录页点击注册）：

- **用户名**: `user`
- **密码**: `12345678`

## 📝 开发指南

- **添加新页面**: 在 `lib/pages/` 下创建新目录，编写 Widget，并在 `lib/main.dart` 或 `lib/main_screen.dart` 中注册路由或添加入口。
- **修改后端**: 在 `backend/app/routers/` 添加新的 API 路由，并在 `backend/app/main.py` 中 `include_router`。
- **样式修改**: 全局主题颜色在 `lib/main.dart` 的 `ThemeData` 中配置。

## ⚠️ 常见问题

1.  **CocoaPods 报错**: 尝试 `cd ios && rm -rf Podfile.lock && pod install --repo-update`。
2.  **网络连接失败**: 
    - 确保后端服务已启动。
    - Android 模拟器访问本机 localhost 需使用 `10.0.2.2` (代码中已适配)。
    - iOS 模拟器和 Web 可直接使用 `localhost`。
    - 真机调试需确保手机和电脑在同一局域网，并将 `lib/services/api_service.dart` 中的 `baseUrl` 改为电脑的局域网 IP。
